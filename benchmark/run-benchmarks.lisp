(in-package #:cl-user)

;;;; PERFORMANCE_STANDARD.md's measurement rule: warmup >= 2, samples >= 10,
;;;; median/min/max reported together, (sb-ext:gc :full t) outside every
;;;; measured region. nes-run-frame/k is the dominant-input entry point
;;;; (frame count decides wall time), so it is what this file measures.

(defparameter *benchmark-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(defparameter *project-root*
  (merge-pathnames "../" *benchmark-root*))

(defparameter *warmup-frame-batches* 2)
(defparameter *sample-count* 10)
(defparameter *frames-per-sample* 60)

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes")

(defun %make-benchmark-cartridge ()
  "A synthetic 32 KiB PRG-ROM cartridge whose reset vector runs a tight
JMP-to-self loop, so CPU/PPU/APU cycle accounting runs without depending on
any real ROM image."
  (let ((prg (make-array #x8000
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    ;; JMP $8000, at $8000: 4C 00 80.
    (setf (aref prg 0) #x4C
          (aref prg 1) #x00
          (aref prg 2) #x80)
    (flet ((set-vector (address target)
             (setf (aref prg (- address #x8000)) (ldb (byte 8 0) target)
                   (aref prg (1+ (- address #x8000))) (ldb (byte 8 8) target))))
      (set-vector #xFFFC #x8000)
      (set-vector #xFFFA #x8000)
      (set-vector #xFFFE #x8000))
    (cl-nes:make-cartridge :prg-rom prg :chr-writable-p t)))

(defun %run-frame-batch (nes frame-count)
  (dotimes (i frame-count)
    (cl-nes:nes-run-frame/k nes #'identity)))

(defun %sample-frame-batch (nes frame-count)
  "Run FRAME-COUNT frames and return (values elapsed-internal-time bytes-consed)."
  (sb-ext:gc :full t)
  (let ((bytes-before (sb-ext:get-bytes-consed))
        (time-before (get-internal-real-time)))
    (%run-frame-batch nes frame-count)
    (values (- (get-internal-real-time) time-before)
            (- (sb-ext:get-bytes-consed) bytes-before))))

(defun %median (sorted-values)
  (let* ((n (length sorted-values))
         (mid (floor n 2)))
    (if (oddp n)
        (elt sorted-values mid)
        (/ (+ (elt sorted-values (1- mid)) (elt sorted-values mid)) 2))))

(defun %report-samples (label values unit)
  (let ((sorted (sort (copy-seq values) #'<)))
    (format t "~A: median ~,3F~A  min ~,3F~A  max ~,3F~A  (n=~D)~%"
            label
            (float (%median sorted) 1.0d0) unit
            (float (elt sorted 0) 1.0d0) unit
            (float (elt sorted (1- (length sorted))) 1.0d0) unit
            (length sorted))))

(defun run-benchmarks ()
  (format t "cl-nes benchmark: ~A, ~A~%"
          (lisp-implementation-type) (lisp-implementation-version))
  (format t "warmup batches ~D, samples ~D, frames per sample ~D~%~%"
          *warmup-frame-batches* *sample-count* *frames-per-sample*)
  (let ((nes (cl-nes:make-nes :cartridge (%make-benchmark-cartridge))))
    (dotimes (i *warmup-frame-batches*)
      (%run-frame-batch nes *frames-per-sample*))
    (let ((frame-times '())
          (frame-bytes '()))
      (dotimes (i *sample-count*)
        (multiple-value-bind (elapsed bytes-consed)
            (%sample-frame-batch nes *frames-per-sample*)
          (push (/ (* 1000.0d0 elapsed)
                   internal-time-units-per-second
                   *frames-per-sample*)
                frame-times)
          (push (/ bytes-consed *frames-per-sample*) frame-bytes)))
      (%report-samples "nes-run-frame/k time/frame" frame-times " ms")
      (%report-samples "nes-run-frame/k bytes consed/frame" frame-bytes " bytes"))))

(run-benchmarks)
