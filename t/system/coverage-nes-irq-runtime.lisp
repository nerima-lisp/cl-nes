(in-package #:cl-nes/test)

(describe "Coverage: NES IRQ runtime paths"
  (it "takes a pending IRQ after the instruction boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p (nes-cpu nes)) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 9)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) :to-be t))))

  (it "exercises NES interrupt eligibility and injected components"
    (let* ((cpu (make-cpu))
           (nes (make-nes))
           (ppu (make-ppu))
           (apu (make-apu))
           (controller-1 (make-controller))
           (controller-2 (make-controller))
           (injected (make-nes :ppu ppu
                               :apu apu
                               :controller-1 controller-1
                               :controller-2 controller-2)))
      (expect (cl-nes::%nes-irq-eligible-p cpu t) :to-be nil)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be nil)
      (setf (cpu-p cpu) 0)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be t)
      (setf (cpu-p cpu) cl-nes::+flag-interrupt-disable+
            (cl-nes::cpu-irq-delay cpu) 0)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be nil)
      (setf (cl-nes::cpu-irq-delay cpu) 1)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be t)
      (expect (cl-nes::%nes-cartridge-irq-pending-p nes) :to-be nil)
      (expect (cl-nes::%nes-irq-pending-p nes) :to-be nil)
      (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (expect (cl-nes::%nes-irq-pending-p nes) :to-be t)
      (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) nil)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be nil)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 3)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be nil)
      (ppu-tick! (nes-ppu nes) 3)
      (cl-nes::%nes-poll-nmi-during-operation! nes)
      (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be t)
      (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil)
      (expect (nes-ppu injected) :to-be ppu)
      (expect (cl-nes::bus-apu (nes-bus injected)) :to-be apu)
      (expect (cl-nes::bus-controller-1 (nes-bus injected)) :to-be controller-1)
      (expect (cl-nes::bus-controller-2 (nes-bus injected)) :to-be controller-2))))
