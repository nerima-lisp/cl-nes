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

  (it "stops on JAM opcodes at the CPU execution boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#x02)))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (expect (cpu-step! cpu bus) :to-be 2)
      (expect (cpu-stopped-p cpu) :to-be t)
      (expect (cpu-step! cpu bus) :to-be 0))))
