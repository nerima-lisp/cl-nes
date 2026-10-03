(in-package #:cl-nes/test)

#+sbcl
(defun %elapsed-seconds (start)
  (/ (- (get-internal-real-time) start)
     internal-time-units-per-second))

#+sbcl
(defun %frame-bytes-consed (frame-count mask)
  (let ((nes (make-nes :cartridge
                       (make-fixture-cartridge
                        :program '(#x78 #x4C #x00 #x80)))))
    (ppu-write-register! (nes-ppu nes) 1 mask)
    (dotimes (i 2)
      (nes-run-frame/k nes #'identity))
    (sb-ext:gc :full t)
    (let ((before (sb-ext:get-bytes-consed)))
      (nes-run-frames/k nes frame-count
                         (lambda (framebuffer)
                           (declare (ignore framebuffer))))
      (- (sb-ext:get-bytes-consed) before))))

#+sbcl
(defun %minimum-bytes-consed (frame-count mask &key (samples 10))
  (loop repeat samples
        minimize (%frame-bytes-consed frame-count mask)))

#+sbcl
(defun %assert-rendered-frame-allocation-scaling-within-p
    (frame-count &key (samples 10) (maximum-ratio 3.0))
  "Return the median 2N/N allocation ratio and assert its upper bound.

The measurement and decision live in this helper so the test contract remains
explicit."
  (labels ((median (values)
             (let ((sorted (sort (copy-seq values) #'<)))
               (elt sorted (floor (length sorted) 2))))
           (sample (count)
             (loop repeat samples
                   collect (%frame-bytes-consed count #x18))))
    (let* ((start (get-internal-real-time))
           (n-values (sample frame-count))
           (two-n-values (sample (* 2 frame-count)))
           (n-median (median n-values))
           (two-n-median (median two-n-values))
           (ratio (/ (float two-n-median) (max 1 n-median))))
      (format t "allocation scaling frame generation: ~,3F s~%"
              (%elapsed-seconds start))
      (expect (<= ratio maximum-ratio) :to-be t)
      ratio)))

#+sbcl
(defun %assert-rendered-frame-allocation-gate-p
    (&key (frame-count 60) (ppu-scratch-exception 0))
  (let* ((baseline-start (get-internal-real-time))
         (baseline (%minimum-bytes-consed frame-count 0))
         (baseline-seconds (%elapsed-seconds baseline-start))
         (rendered-start (get-internal-real-time))
         (rendered (%minimum-bytes-consed frame-count #x18))
         (rendered-seconds (%elapsed-seconds rendered-start)))
    (format t "allocation gate: baseline ~D rendered ~D allowance ~D~%"
            baseline rendered ppu-scratch-exception)
    (format t "allocation frame generation: baseline ~,3F s rendered ~,3F s~%"
            baseline-seconds rendered-seconds)
    ;; The baseline follows docs/src/benchmarks.md.  The dot renderer keeps
    ;; its state in the PPU pipeline and allocates no legacy frame scratch.
    (expect (<= rendered
                (+ baseline (* frame-count ppu-scratch-exception)))
            :to-be t)
    (values baseline rendered)))

#+sbcl
(defun %audio-frame-bytes-consed (&key (samples 10))
  (let* ((nes (make-nes :cartridge
                        (make-fixture-cartridge
                         :program '(#x78 #x4C #x00 #x80))))
         (buffer (make-nes-audio-buffer :size 1024)))
    (ppu-write-register! (nes-ppu nes) 1 #x18)
    (nes-run-frames/k nes 2 #'identity
                       :audio-buffer buffer
                       :audio-continuation #'identity)
    (sb-ext:gc :full t)
    (loop repeat samples
          minimize
          (progn
            (let ((before (sb-ext:get-bytes-consed)))
              (nes-run-frames/k nes 2 #'identity
                                 :audio-buffer buffer
                                 :audio-continuation #'identity)
              (- (sb-ext:get-bytes-consed) before))))))

#+sbcl
(defun %assert-frame-time-scaling-within-p
    (frame-count &key (samples 10) (maximum-ratio 4.0))
  (multiple-value-bind (within-p ratio)
      (cl-weave:benchmark-scaling-within-p
       (lambda (count)
         (let ((nes (make-nes :cartridge
                              (make-fixture-cartridge
                               :program '(#x78 #x4C #x00 #x80)))))
           (ppu-write-register! (nes-ppu nes) 1 #x18)
           (dotimes (i 2)
             (nes-run-frame/k nes #'identity))
           (dotimes (i count)
             (nes-run-frame/k nes #'identity))))
       frame-count
       2
       maximum-ratio
       :samples samples)
    (format t "frame time scaling gate: ratio ~,3F maximum ~,3F~%"
            ratio maximum-ratio)
    (expect within-p :to-be t)
    ratio))

#+sbcl
(describe "System allocation complexity"
  (it "keeps rendered frame allocation close to linear"
      (:tags '("heavy"))
    (%assert-rendered-frame-allocation-gate-p)
    (%assert-rendered-frame-allocation-scaling-within-p 2))
  (it "keeps rendered frame time within the linear bound"
    (%assert-frame-time-scaling-within-p 2))
  (it "keeps steady-state audio frame allocation at zero"
    (expect (%audio-frame-bytes-consed) :to-be 0)))
