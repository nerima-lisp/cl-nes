(in-package #:cl-nes/test)

(describe "APU register boundaries"
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
      (expect (apu-irq-pending-p apu) :to-be nil))))
