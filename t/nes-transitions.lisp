(in-package #:cl-nes/test)

(describe "NES interrupt transitions"
  (it "delays a pending APU IRQ for one instruction"
    (let* ((nes (make-nes
                 :cartridge
                 (make-fixture-cartridge :program '(#xEA #xEA))))
           (cpu (nes-cpu nes))
           (apu (nes-apu nes)))
      (setf (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::cpu-irq-delay cpu) 1)
      (expect (nes-step/k nes #'identity) :to-be 2)
      (expect (cpu-pc cpu) :to-be #x8001)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 0)
      (setf (cpu-p cpu)
            (logand (cpu-p cpu)
                    (lognot cl-nes::+flag-interrupt-disable+)))
      (expect (nes-step/k nes #'identity) :to-be 9)
      (expect (cpu-pc cpu) :to-be #x8000)
      (expect (cpu-sp cpu) :to-be #xFA)))
  (it "delivers an MMC5 IRQ after the current instruction"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (rom (cartridge-prg-rom cartridge)))
      (setf (aref rom 0) #xEA
            (aref rom 1) #xEA
            (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFC)) 0
            (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFD)) #x80
            (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFE)) 0
            (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFF)) #x80)
      (let* ((nes (make-nes :cartridge cartridge))
             (cpu (nes-cpu nes)))
        (setf (cpu-p cpu)
              (logand (cpu-p cpu)
                      (lognot cl-nes::+flag-interrupt-disable+)))
        (cl-nes::cartridge-write-expansion! cartridge #x5203 1)
        (cl-nes::cartridge-write-expansion! cartridge #x5204 #x80)
        (cl-nes::cartridge-clock-scanline! cartridge 1)
        (expect (nes-step/k nes #'identity) :to-be 9)
        (expect (cpu-pc cpu) :to-be #x8000)
        (expect (cpu-sp cpu) :to-be #xFA)))))
