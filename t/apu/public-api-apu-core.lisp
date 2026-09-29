(in-package #:cl-nes/test)

(describe "Public API: APU core"
  (it "exposes reset status and silent output through public APIs"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (apu (nes-apu nes)))
      (expect (apu-read-register apu #x4015) :to-be 0)
      (expect (apu-irq-pending-p apu) :to-be nil)
      (expect (apu-sample apu) :to-be 0))))
