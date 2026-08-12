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
  (it "takes a pending APU IRQ after a taken branch"
    (let* ((nes (make-nes
                 :cartridge
                 (make-fixture-cartridge :program '(#xD0 #x00))))
           (cpu (nes-cpu nes))
           (apu (nes-apu nes)))
      (setf (cl-nes::apu-frame-irq-pending-p apu) t
            (cpu-p cpu)
            (logand (cpu-p cpu)
                    (lognot (logior cl-nes::+flag-interrupt-disable+
                                    cl-nes::+flag-zero+))))
      (expect (nes-step/k nes #'identity) :to-be 10)
      (expect (cpu-pc cpu) :to-be #x8000)
      (expect (cpu-sp cpu) :to-be #xFA)))
  (it "defers an APU IRQ asserted on a branch's final clock"
    (let* ((cartridge (make-fixture-cartridge :program '(#xD0 #x00 #xEA)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (apu (nes-apu nes)))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p cpu)
            (logand (cpu-p cpu)
                    (lognot (logior cl-nes::+flag-interrupt-disable+
                                    cl-nes::+flag-zero+)))
            (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-cycle apu) 29826
            (cl-nes::apu-frame-tail-step apu) 0
            (cl-nes::apu-frame-irq-inhibit-p apu) nil
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-irq-repeat-count apu) 0)
      (expect (nes-step/k nes #'identity) :to-be 3)
      (expect (cpu-pc cpu) :to-be #x8002)
      (expect (cpu-sp cpu) :to-be #xFD)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (nes-step/k nes #'identity) :to-be 9)
      (expect (cpu-pc cpu) :to-be #x9000)
      (expect (cpu-sp cpu) :to-be #xFA)))
  (it "delivers an MMC5 IRQ after the current instruction"
    (with-mmc5-cartridge (cartridge)
      (let ((rom (cartridge-prg-rom cartridge)))
        (setf (aref rom 0) #xEA
              (aref rom 1) #xEA
              (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFC)) 0
              (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFD)) #x80
              (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFE)) 0
              (aref rom (+ (* 15 cl-nes::+prg-bank-8k-size+) #x1FFF)) #x80))
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
