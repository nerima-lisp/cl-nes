(in-package #:cl-nes/test)

(describe "Coverage: PPU NMI and mask runtime paths"
  (it "applies delayed masks and toggles pending NMI through control writes"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 3 2)
      (ppu-write-register! ppu 4 #xFF)
      (ppu-write-register! ppu 3 2)
      (expect (ppu-read-register ppu 4 t) :to-be #xE3)
      (ppu-write-register! ppu 3 3)
      (ppu-write-register! ppu 4 #xFF)
      (ppu-write-register! ppu 3 3)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (ppu-status ppu) #x80)
      (ppu-write-register! ppu 0 #x80)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be t)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)
      (ppu-write-register! ppu 1 #x08)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask-delay ppu) :to-be 1)
      (ppu-tick! ppu)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x08)))

  (it "cancels delayed NMI through control disable"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80)
      (ppu-write-register! ppu 0 #x80)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be t)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be nil)))

  (it "applies delayed rendering masks through the helper path"
    (let ((ppu (make-ppu)))
      (setf (ppu-mask ppu) #x04
            (cl-nes::ppu-rendering-mask ppu) #x02
            (cl-nes::ppu-rendering-mask-pending ppu) #x18
            (cl-nes::ppu-rendering-mask-delay ppu) 1
            (cl-nes::ppu-rendering-mask-valid-p ppu) t)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x02)
      (cl-nes::%ppu-advance-rendering-mask! ppu)
      (expect (cl-nes::ppu-rendering-mask-delay ppu) :to-be 0)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be #x18)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x18)))

  (it "clears delayed NMI on control disable after palette reads"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80)
      (ppu-write-register! ppu 0 #x80)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be t)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be t)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be nil))))
