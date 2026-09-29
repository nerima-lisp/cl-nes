(in-package #:cl-nes/test)

#+sbcl
(defun %frame-bytes-consed (frame-count mask)
  (let ((nes (make-nes :cartridge
                       (make-fixture-cartridge
                        :program '(#x78 #x4C #x00 #x80)))))
    (ppu-write-register! (nes-ppu nes) 1 mask)
    (dotimes (i 60)
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

The measurement and decision live in this helper so it can later delegate to
CL-WEAVE's BENCHMARK-SCALING-WITHIN-P without changing the test contract."
  (labels ((median (values)
             (let ((sorted (sort (copy-seq values) #'<)))
               (elt sorted (floor (length sorted) 2))))
           (sample (count)
             (loop repeat samples
                   collect (%frame-bytes-consed count #x18))))
    (let* ((n-values (sample frame-count))
           (two-n-values (sample (* 2 frame-count)))
           (n-median (median n-values))
           (two-n-median (median two-n-values))
           (ratio (/ (float two-n-median) (max 1 n-median))))
      (expect (<= ratio maximum-ratio) :to-be t)
      ratio)))

#+sbcl
(defun %assert-rendered-frame-allocation-gate-p
    (&key (frame-count 60) (ppu-scratch-exception 32768))
  (let* ((baseline (%minimum-bytes-consed frame-count 0))
         (rendered (%minimum-bytes-consed frame-count #x18)))
    (format t "allocation gate: baseline ~D rendered ~D allowance ~D~%"
            baseline rendered ppu-scratch-exception)
    ;; The baseline follows PERFORMANCE_STANDARD.md.  Until the PPU stream
    ;; removes the legacy renderer's two 256x240 bit arrays, permit their
    ;; measured 15,360-byte payload plus array/runtime overhead.
    (expect (<= rendered
                (+ baseline (* frame-count ppu-scratch-exception)))
            :to-be t)
    (values baseline rendered)))

#+sbcl
(defun %assert-frame-time-scaling-within-p
    (frame-count &key (samples 10) (maximum-ratio 4.0))
  (labels ((median (values)
             (let ((sorted (sort (copy-seq values) #'<)))
               (elt sorted (floor (length sorted) 2))))
           (sample (count)
             (loop repeat samples
                   collect
                   (let ((nes (make-nes :cartridge
                                        (make-fixture-cartridge
                                         :program '(#x78 #x4C #x00 #x80)))))
                     (ppu-write-register! (nes-ppu nes) 1 #x18)
                     (dotimes (i 60)
                       (nes-run-frame/k nes #'identity))
                     (let ((start (get-internal-real-time)))
                       (dotimes (i count)
                         (nes-run-frame/k nes #'identity))
                       (- (get-internal-real-time) start))))))
    (let ((ratio (/ (float (median (sample (* 2 frame-count))))
                    (max 1 (median (sample frame-count))))))
      (expect (<= ratio maximum-ratio) :to-be t)
      ratio)))

#+sbcl
(describe "System allocation complexity"
  (it "keeps rendered frame allocation close to linear"
    (%assert-rendered-frame-allocation-gate-p)
    (%assert-rendered-frame-allocation-scaling-within-p 2))
  (it "keeps rendered frame time within the linear bound"
    (%assert-frame-time-scaling-within-p 2)))
