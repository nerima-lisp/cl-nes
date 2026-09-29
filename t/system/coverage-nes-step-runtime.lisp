(in-package #:cl-nes/test)

(describe "Coverage: NES step runtime paths"
  (it "runs DMA stalls as part of a NES step"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (bus-write! (nes-bus nes) #x4014 0)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect (plusp cycles) :to-be t)
        (expect (cl-nes::bus-dma-stall-cycles (nes-bus nes)) :to-be 0)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8001))))

  (it "signals illegal opcodes at the CPU execution boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#x02)))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (let ((condition
              (captured-condition (lambda () (cpu-step! cpu bus)))))
        (expect (typep condition 'illegal-opcode) :to-be t)
        (expect (illegal-opcode-value condition) :to-be #x02)))))
