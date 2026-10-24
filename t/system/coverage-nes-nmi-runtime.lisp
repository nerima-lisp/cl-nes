(in-package #:cl-nes/test)

(describe "Coverage: NES NMI runtime paths"
  (it "hijacks BRK with a delayed NMI at the vector poll"
    (let* ((cartridge (make-fixture-cartridge :program '(#x00)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 3)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 7)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (logand (bus-read (nes-bus nes) #x01FB) #x10) :to-be #x10)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil))))

  (it "takes an external NMI after an instruction"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 9)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil))))

  (it "does not take an NMI while its propagation delay is active"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 100)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 2)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8001)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be t))))

  (it "polls NMI between the hardware return-address and status pushes"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (set-fixture-vector! cartridge #xFFFE #xA000)
      (setf (cpu-p cpu) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (let ((cycles
              (nes-step/k
               nes #'identity
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 6)
                   (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
                         (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 0))))))
        (expect cycles :to-be 9)
        (expect (cpu-pc cpu) :to-be #x9000)
        (expect (logand (bus-read (nes-bus nes) #x01FB) #x10) :to-be 0)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil))))

  (it "keeps the IRQ vector when NMI arrives after the status push"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (set-fixture-vector! cartridge #xFFFE #xA000)
      (setf (cpu-p cpu) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (let ((cycles
              (nes-step/k
               nes #'identity
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 7)
                   (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
                         (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 0))))))
        (expect cycles :to-be 9)
        (expect (cpu-pc cpu) :to-be #xA000)
        (expect (logand (bus-read (nes-bus nes) #x01FB) #x10) :to-be 0)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be t)))))
