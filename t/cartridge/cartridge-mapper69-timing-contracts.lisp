(in-package #:cl-nes/test)

(describe "Mapper 69 CPU timing contracts"
  (it "decrements and underflows the IRQ counter under separate control bits"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 69
                       :prg-banks 8
                       :chr-banks 8))
           (nes (make-nes :cartridge cartridge)))
      (expect (cl-nes::cartridge-cpu-clock-required-p cartridge) :to-be t)
      (mapper69-write-command! cartridge 13 #x80)
      (mapper69-write-command! cartridge 14 2)
      (mapper69-write-command! cartridge 15 0)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be 1)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be nil)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be 0)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be nil)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be #xFFFF)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be nil)
      (mapper69-write-command! cartridge 13 #x81)
      (mapper69-write-command! cartridge 14 0)
      (mapper69-write-command! cartridge 15 0)
      (cl-nes::%nes-clock-cpu-cycle! nes (nes-bus nes) nil nil)
      (expect (cl-nes::cartridge-mapper69-irq-counter cartridge) :to-be #xFFFF)
      (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge) :to-be t))))
