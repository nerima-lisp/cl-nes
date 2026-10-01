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

  (it "keeps the buffered DMC byte and output bits when disabled"
    (with-fixture-apu (apu nil nil nil nil dmc)
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 3
            (cl-nes::apu-dmc-sample-buffer dmc) #xA5
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-shift-register dmc) #x5A
            (cl-nes::apu-dmc-bits-remaining dmc) 5
            (cl-nes::apu-dmc-silence-p dmc) nil)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-enabled-p dmc) :to-be nil)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #xA5)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
      (expect (cl-nes::apu-dmc-shift-register dmc) :to-be #x5A)
      (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 5)
      (expect (cl-nes::apu-dmc-silence-p dmc) :to-be nil)))

  (it "reports DMC active from bytes remaining only"
    (with-fixture-apu (apu nil nil nil nil dmc)
      (setf (cl-nes::apu-dmc-bits-remaining dmc) 7
            (cl-nes::apu-dmc-silence-p dmc) nil)
      (expect (logand (apu-read-register apu #x4015) #x10) :to-be 0)
      (setf (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (expect (logand (apu-read-register apu #x4015) #x10) :to-be #x10)))

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
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)))

  (it "restarts a looping DMC sample after its final fetch"
    (let* ((apu (make-apu :memory-reader (lambda (address)
                                           (declare (ignore address))
                                           #x3C)))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-sample-address dmc) #xC000
            (cl-nes::apu-dmc-current-address dmc) #xC123
            (cl-nes::apu-dmc-sample-length dmc) 1
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-loop-p dmc) t)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x3C)
      (expect (cl-nes::apu-dmc-current-address dmc) :to-be #xC000)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil))))
