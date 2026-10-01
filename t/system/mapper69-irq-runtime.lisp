(in-package #:cl-nes/test)

(describe "Mapper 69 IRQ runtime"
  (it "raises the cartridge IRQ line from NES CPU clocks"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 69
                      :prg-banks 4
                      :chr-banks 8)))
      (setf (aref (cartridge-prg-rom cartridge) 0) #xEA
            (aref (cartridge-prg-rom cartridge) #x1000) #xEA
            (aref (cartridge-prg-rom cartridge) #x7FFC) 0
            (aref (cartridge-prg-rom cartridge) #x7FFD) #x90
            (aref (cartridge-prg-rom cartridge) (- (length (cartridge-prg-rom cartridge)) 2)) 0
            (aref (cartridge-prg-rom cartridge) (1- (length (cartridge-prg-rom cartridge)))) #x90)
      (let* ((nes (make-nes :cartridge cartridge))
             (cpu (nes-cpu nes)))
        (setf (cpu-p cpu)
              (logand (cpu-p cpu)
                      (lognot cl-nes::+flag-interrupt-disable+)))
        (mapper69-write-command! cartridge 13 #x81)
        (mapper69-write-command! cartridge 14 0)
        (mapper69-write-command! cartridge 15 0)
        (expect (cl-nes::cartridge-mapper69-irq-counter-enabled-p cartridge)
                :to-be t)
        (expect (cl-nes::cartridge-mapper69-irq-enabled-p cartridge)
                :to-be t)
        (expect (nes-step/k nes #'identity) :to-be 9)
        (expect (cpu-pc cpu) :to-be #x9000)
        (expect (cl-nes::cartridge-mapper69-irq-pending-p cartridge)
                :to-be t)))))
