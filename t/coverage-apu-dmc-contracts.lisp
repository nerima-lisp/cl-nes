(in-package #:cl-nes/test)

(describe "Coverage: APU DMC contracts"
  (it "preserves an active DMC sample when status is rewritten"
    (with-fixture-apu (apu nil nil nil nil dmc)
      (setf (cl-nes::apu-dmc-bytes-remaining dmc) 4)
      (apu-write-register! apu #x4015 #x10)
      (expect (cl-nes::apu-dmc-enabled-p dmc) :to-be t)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 4)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

  (it "fetches DMC bytes through its reader and raises terminal IRQs"
    (let ((read-address nil))
      (let* ((apu (make-apu
                   :memory-reader
                   (lambda (address)
                     (setf read-address address)
                     #x1FF)))
             (dmc (cl-nes::apu-dmc apu)))
        (setf (cl-nes::apu-dmc-enabled-p dmc) t
              (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
              (cl-nes::apu-dmc-bytes-remaining dmc) 1
              (cl-nes::apu-dmc-irq-enabled-p dmc) t
              (cl-nes::apu-dmc-current-address dmc) #xFFFF)
        (cl-nes::%apu-dmc-fetch! apu)
        (expect read-address :to-be #xFFFF)
        (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #xFF)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x8000)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
        (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be t)))
    (let* ((apu (make-apu :memory-reader (lambda (address)
                                           (declare (ignore address))
                                           #x7F)))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 2)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x7F)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil))
    (with-fixture-apu (apu nil nil nil nil dmc)
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be 0)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil))))
