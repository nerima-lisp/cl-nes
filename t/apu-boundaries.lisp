(in-package #:cl-nes/test)

(describe "APU boundaries"
  (it "masks register addresses and values"
    (let ((apu (make-apu)))
      (expect (apu-write-register! apu #x14000 #x1FF) :to-be #xFF)
      (expect (apu-read-register apu #x14000) :to-be nil)))

  (it "reports active channel lengths and clears frame IRQ on status read"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4015 #x0F)
      (apu-write-register! apu #x4003 0)
      (apu-write-register! apu #x4007 0)
      (apu-write-register! apu #x400B 0)
      (apu-write-register! apu #x400F 0)
      (setf (cl-nes::apu-frame-irq-pending-p apu) t)
      (expect (logand (apu-read-register apu #x4015) #x4F) :to-be #x4F)
      (expect (apu-irq-pending-p apu) :to-be nil)))

  (it "fetches DMC bytes, wraps addresses, and loops samples"
    (let* ((addresses nil)
           (apu (make-apu
                 :memory-reader
                 (lambda (address)
                   (push address addresses)
                   #xFF)))
           (dmc (cl-nes::apu-dmc apu)))
      (apu-write-register! apu #x4010 #x80)
      (apu-write-register! apu #x4012 #xFF)
      (apu-write-register! apu #x4013 0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (length addresses) :to-be 1)
      (expect (first addresses) :to-be #xFFFF)
      (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x8000)
      (expect (apu-irq-pending-p apu) :to-be t)
      (expect (logbitp 7 (apu-read-register apu #x4015)) :to-be t)
      (apu-write-register! apu #x4010 #xC0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

  (it "delays frame mode changes and preserves console registers"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4017 #x80)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-five-step-p apu) :to-be t)
      (apu-write-register! apu #x4017 0)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 4)
      (apu-write-register! apu #x4000 #xFF)
      (apu-write-register! apu #x4002 #x34)
      (apu-write-register! apu #x4003 #x05)
      (cl-nes::apu-console-reset! apu)
      (expect (cl-nes::apu-frame-last-five-step-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (expect (cl-nes::apu-pulse-duty (cl-nes::apu-pulse-1 apu)) :to-be 3)
      (expect (cl-nes::apu-pulse-timer-period
               (cl-nes::apu-pulse-1 apu))
              :to-be #x534)
      (expect (cl-nes::apu-envelope-volume
               (cl-nes::apu-pulse-envelope (cl-nes::apu-pulse-1 apu)))
              :to-be 15))))

  (it "applies frame IRQ inhibit immediately on #x4017 writes"
    (let ((apu (make-apu)))
      (setf (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::apu-frame-irq-repeat-count apu) 2)
      (apu-write-register! apu #x4017 #x40)
      (expect (cl-nes::apu-frame-irq-inhibit-p apu) :to-be t)
      (expect (cl-nes::apu-frame-reset-irq-inhibit-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (apu-write-register! apu #x4017 0)
      (expect (cl-nes::apu-frame-irq-inhibit-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-reset-irq-inhibit-p apu) :to-be nil)))

  (it "loads triangle and noise lengths only while enabled"
    (let* ((apu (make-apu))
           (triangle (cl-nes::apu-triangle apu))
           (noise (cl-nes::apu-noise apu)))
      (apu-write-register! apu #x400B #xA0)
      (apu-write-register! apu #x400F #xA0)
      (expect (cl-nes::apu-triangle-length-counter triangle) :to-be 0)
      (expect (cl-nes::apu-noise-length-counter noise) :to-be 0)
      (apu-write-register! apu #x4015 #x0C)
      (apu-write-register! apu #x400B #xA0)
      (apu-write-register! apu #x400F #xA0)
      (expect (cl-nes::apu-triangle-length-counter triangle) :to-be 48)
      (expect (cl-nes::apu-noise-length-counter noise) :to-be 48)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be t)
      (expect (cl-nes::apu-envelope-start-p
               (cl-nes::apu-noise-envelope noise))
              :to-be t)))
