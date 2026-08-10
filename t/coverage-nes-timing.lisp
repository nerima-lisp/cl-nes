(in-package #:cl-nes/test)

(describe "Coverage: NES timing helpers"
  (it "completes operations with unaccounted CPU cycles"
    (let* ((nes (make-nes))
           (bus (cl-nes::nes-bus nes))
           (cycle-count 0)
           (pre-cycle-count 0))
      (expect (cl-nes::%nes-complete-cpu-operation!
               nes bus 2 0
               (lambda () (incf cycle-count))
               (lambda () (incf pre-cycle-count)))
              :to-be 2)
      (expect cycle-count :to-be 2)
      (expect pre-cycle-count :to-be 2)
      (expect (cl-nes::bus-cpu-cycle-phase bus) :to-be 0)
      (expect (cl-nes::%nes-complete-cpu-operation!
               nes bus nil 0 nil nil)
              :to-be nil)))

  (it "polls IRQ before each DMA stall cycle"
    (let* ((nes (make-nes))
           (poll-count 0))
      (expect (cl-nes::%nes-run-dma-stalls!
               nes 3 (lambda () (incf poll-count)))
              :to-be 3)
      (expect poll-count :to-be 3)
      (expect (cl-nes::bus-cpu-cycle-phase
               (cl-nes::nes-bus nes))
              :to-be 1))))
