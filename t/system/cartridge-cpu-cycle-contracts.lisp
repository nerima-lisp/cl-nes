(in-package #:cl-nes/test)

(describe "CPU cartridge write timing contracts"
  (it "passes the current CPU cycle to cartridge writes"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 1
                       :prg-banks 8
                       :chr-banks 8))
           (nes (make-nes :cartridge cartridge)))
      (cl-nes::with-nes-cpu-operation (nes)
        (bus-write! (nes-bus nes) #x8000 0))
      (expect (cl-nes::cartridge-mapper1-last-write-cycle cartridge)
              :to-be
              (cpu-cycles (nes-cpu nes))))))
