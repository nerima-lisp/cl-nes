(in-package #:cl-nes/test)

(describe "Mapper 69 CPU timing contracts"
  (it "decrements the IRQ counter once per CPU cycle"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 69
                       :prg-banks 8
                       :chr-banks 8))
           (nes (make-nes :cartridge cartridge)))
      (setf (cl-nes::cartridge-mapper69-irq-counter cartridge) 2
            (cl-nes::cartridge-mapper69-irq-enabled-p cartridge) t)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be 1)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be nil)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be 0)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be nil)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be t))))
