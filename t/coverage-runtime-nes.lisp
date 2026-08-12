(in-package #:cl-nes/test)

(describe "Coverage: NES runtime paths"
  (it "loads and resets cartridges through the public NES lifecycle"
    (let ((nes (make-nes))
          (cartridge (make-fixture-cartridge)))
      (expect (nes-load-cartridge! nes cartridge) :to-be nes)
      (expect (nes-reset! nes) :to-be nes)
      (expect (nes-load-cartridge! nes nil) :to-be nes)
      (expect (cl-nes::bus-cartridge (nes-bus nes)) :to-be nil)
      (expect (nes-reset! nes) :to-be nes)))

  (it "runs DMA stalls as part of a NES step"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (bus-write! (nes-bus nes) #x4014 0)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect (plusp cycles) :to-be t)
        (expect (cl-nes::bus-dma-stall-cycles (nes-bus nes)) :to-be 0)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8001))))

  (it "hijacks BRK with a delayed NMI at the vector poll"
    (let* ((cartridge (make-fixture-cartridge :program '(#x00)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 7)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
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

  (it "keeps a delayed NMI invisible to the CPU boundary helper"
    (let ((nes (make-nes :cartridge (make-fixture-cartridge))))
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) t)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be nil)
      (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be t)
      (expect (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) :to-be t)))

  (it "signals illegal opcodes at the CPU execution boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#x02)))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (let ((condition
              (captured-condition (lambda () (cpu-step! cpu bus)))))
        (expect (typep condition 'illegal-opcode) :to-be t)
        (expect (illegal-opcode-value condition) :to-be #x02)))))
