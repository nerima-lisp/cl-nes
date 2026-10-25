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

  (it "does not poll IRQ during DMA stall cycles"
    (let* ((nes (make-nes))
           (poll-count 0))
      (setf (cl-nes::nes-irq-line-sample-p nes) t)
      (expect (cl-nes::%nes-run-dma-stalls!
               nes 3 (lambda () (incf poll-count)))
              :to-be 3)
      (expect poll-count :to-be 3)
      (expect (cl-nes::%nes-run-dma-stalls! nes 0) :to-be 0)
      (expect (cl-nes::nes-irq-seen-p nes) :to-be nil)
      (expect (cl-nes::nes-irq-seen-before-last-p nes) :to-be nil)
      (expect (cl-nes::nes-irq-line-sample-p nes) :to-be nil)
      (expect (cl-nes::bus-cpu-cycle-phase
               (cl-nes::nes-bus nes))
              :to-be 1)))
  (it "completes active OAM DMA after remaining stall cycles reach zero"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (bus (cl-nes::nes-bus nes))
           (cycle-count 0))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (bus-write! bus #x4014 7)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes)))
      (let ((elapsed
              (cl-nes::%nes-run-dma-stalls!
               nes 0 (lambda () (incf cycle-count)))))
        (expect (plusp elapsed) :to-be t)
        (expect cycle-count :to-be elapsed))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256))))
