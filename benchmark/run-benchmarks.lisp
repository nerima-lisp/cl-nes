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

(defun %put-bytes! (vector offset bytes)
  (loop for byte in bytes
        for index from offset
        do (setf (aref vector index) byte))
  vector)

(defun %set-vector! (prg base address target &optional (window-base #x8000))
  (let ((offset (+ base (- address window-base))))
    (setf (aref prg offset) (ldb (byte 8 0) target)
          (aref prg (1+ offset)) (ldb (byte 8 8) target))))

(defun %patterned-chr-rom ()
  (let ((chr (make-array #x2000 :element-type '(unsigned-byte 8))))
    (loop for index below (length chr)
          do (setf (aref chr index)
                   (if (evenp (floor index 8)) #xFF #x00)))
    chr))

(defun %make-rendering-cartridge ()
  "Synthetic NROM ROM that enables both background and sprite rendering."
  (let ((prg (make-array #x8000
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    ;; SEI; $2000 selects the background pattern table; $2001 is exactly
    ;; PPUMASK=$18; the four writes seed one visible sprite at x=8.
    (%put-bytes! prg 0
                 '(#x78 #xA9 #x10 #x8D #x00 #x20
                   #xA9 #x18 #x8D #x01 #x20
                   #xA9 #x00 #x8D #x03 #x20
                   #xA9 #x00 #x8D #x04 #x20
                   #xA9 #x00 #x8D #x04 #x20
                   #xA9 #x00 #x8D #x04 #x20
                   #xA9 #x08 #x8D #x04 #x20
                   #x4C #x1A #x80))
    (%set-vector! prg 0 #xFFFC #x8000)
    (%set-vector! prg 0 #xFFFA #x8000)
    (%set-vector! prg 0 #xFFFE #x8000)
    (cl-nes:make-cartridge :prg-rom prg
                           :chr-rom (%patterned-chr-rom)
                           :mirroring :horizontal)))

(defun %make-mmc3-cartridge ()
  "Synthetic MMC3 ROM with fixed-bank 6502 code, bank writes, and IRQs."
  (let* ((bank-size #x2000)
         (prg (make-array (* 8 bank-size)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (fixed-base (* 7 bank-size)))
    ;; Fixed at $E000 so writes to $8000/$8001 cannot evict the loop. The
    ;; selected registers change on every pass and the IRQ source is armed
    ;; once; the handler acknowledges, reloads, and re-enables it.
    (%put-bytes! prg fixed-base
                 '(#x78                         ; SEI
                   #xA9 #x10 #x8D #x00 #x20      ; PPUCTRL: BG table 1
                   #xA9 #x18 #x8D #x01 #x20      ; PPUMASK: BG + sprites
                   #xA9 #x01 #x8D #x00 #xC0      ; IRQ latch
                   #xA9 #x00 #x8D #x01 #xC0      ; IRQ reload
                   #xA9 #x00 #x8D #x01 #xE0      ; IRQ enable
                   #xA9 #x00 #x8D #x00 #x80      ; select R0
                   #xA9 #x02 #x8D #x01 #x80      ; CHR bank switch
                   #xA9 #x06 #x8D #x00 #x80      ; select R6
                   #xA9 #x03 #x8D #x01 #x80      ; PRG bank switch
                   #x58                         ; CLI: accept scanline IRQs
                   #x4C #x2A #xE0))              ; repeat switches
    ;; IRQ handler at $E040: disable, reload, enable, return.
    (%put-bytes! prg (+ fixed-base #x40)
                 '(#x48                         ; PHA
                   #xA9 #x00 #x8D #x00 #xE0      ; IRQ disable/ack
                   #xA9 #x01 #x8D #x01 #xC0      ; reload counter
                   #xA9 #x00 #x8D #x01 #xE0      ; IRQ enable
                   #x68 #x40))                  ; PLA; RTI
    (%set-vector! prg fixed-base #xFFFC #xE000 #xE000)
    (%set-vector! prg fixed-base #xFFFA #xE000 #xE000)
    (%set-vector! prg fixed-base #xFFFE #xE040 #xE000)
    (cl-nes:make-cartridge :prg-rom prg :mapper 4
                           :chr-rom (%patterned-chr-rom)
                           :mirroring :horizontal)))

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

(defun %run-benchmark (label cartridge-maker)
  (format t "~&~A~%" label)
  (let ((nes (cl-nes:make-nes :cartridge (funcall cartridge-maker))))
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

(defun run-benchmarks ()
  (format t "cl-nes benchmark: ~A, ~A~%"
          (lisp-implementation-type) (lisp-implementation-version))
  (format t "warmup batches ~D, samples ~D, frames per sample ~D~%~%"
          *warmup-frame-batches* *sample-count* *frames-per-sample*)
  (%run-benchmark "rendering-enabled NROM (PPUMASK=$18)"
                  #'%make-rendering-cartridge)
  (%run-benchmark "MMC3 bank switching + scanline IRQ"
                  #'%make-mmc3-cartridge))

(run-benchmarks)
