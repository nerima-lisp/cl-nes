(in-package #:cl-nes/test)

(describe "Coverage: NES lifecycle surface"
  (it "loads and resets cartridges through the public NES lifecycle"
    (let ((nes (make-nes))
          (cartridge (make-fixture-cartridge)))
      (expect (nes-load-cartridge! nes cartridge) :to-be nes)
      (expect (nes-reset! nes) :to-be nes)
      (expect (nes-load-cartridge! nes nil) :to-be nes)
      (expect (cl-nes::bus-cartridge (nes-bus nes)) :to-be nil)
      (expect (nes-reset! nes) :to-be nes)))

  (it "constructs a NES with a cartridge and runs the reset clocks"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge)))
      (expect (cl-nes::bus-cartridge (nes-bus nes)) :to-be cartridge)
      (expect (cpu-pc (nes-cpu nes)) :to-be #x8000)
      (expect (cpu-cycles (nes-cpu nes)) :to-be 7)
      (expect (cl-nes::bus-cpu-cycle-phase (nes-bus nes)) :to-be 1))))
