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
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)))

  (it "tracks master-clock phase independently from CPU cycle parity"
    (let ((nes (make-nes)))
      (expect (cl-nes::nes-master-clock nes) :to-be 0)
      (expect (cl-nes::nes-ppu-phase-offset nes) :to-be 1)
      (expect (mod (- (cl-nes::nes-master-clock nes)
                      (cl-nes::nes-ppu-phase-offset nes))
                   4)
              :to-be 3))
    (dolist (phase '(0 1 2 3))
      (let* ((nes (make-nes))
             (bus (cl-nes::nes-bus nes))
             (ppu (cl-nes::nes-ppu nes))
             (phase-offset (mod (- phase) 4)))
        (setf (cl-nes::nes-ppu-phase-offset nes) phase-offset
              (cl-nes::bus-cpu-cycle-phase bus) 0)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase)
        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::nes-master-clock nes) :to-be 12)
        (expect (cl-nes::ppu-dot ppu) :to-be 3)
        (expect (cl-nes::bus-cpu-cycle-phase bus) :to-be 1)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase)
        (cl-nes::%nes-tick! nes 2)
        (expect (cl-nes::nes-master-clock nes) :to-be 36)
        (expect (cl-nes::ppu-dot ppu) :to-be 9)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase)
        (nes-reset! nes)
        (expect (cl-nes::nes-master-clock nes) :to-be 120)
        (expect (cl-nes::nes-ppu-phase-offset nes) :to-be phase-offset)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase))))

  (it "preserves dot wrap and odd-frame skip through CPU cycles in every phase"
    (dolist (phase '(0 1 2 3))
      (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
             (bus (cl-nes::nes-bus nes))
             (ppu (cl-nes::nes-ppu nes))
             (clock-start (cl-nes::nes-master-clock nes))
             (phase-offset (mod (- clock-start phase) 4)))
        (setf (cl-nes::nes-ppu-phase-offset nes) phase-offset
              (cl-nes::ppu-scanline ppu) 12
              (cl-nes::ppu-dot ppu) 338)
        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::nes-master-clock nes) :to-be (+ clock-start 12))
        (expect (cl-nes::ppu-scanline ppu) :to-be 13)
        (expect (cl-nes::ppu-dot ppu) :to-be 0)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase)
        (setf (cl-nes::ppu-scanline ppu) 261
              (cl-nes::ppu-dot ppu) 338
              (cl-nes::ppu-odd-frame-p ppu) t
              (ppu-mask ppu) #x08)
        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::nes-master-clock nes) :to-be (+ clock-start 24))
        (expect (cl-nes::ppu-scanline ppu) :to-be 0)
        (expect (cl-nes::ppu-dot ppu) :to-be 1)
        (expect (cl-nes::ppu-odd-frame-p ppu) :to-be nil)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase))))

  (it "clocks the MMC3 A12 IRQ edge across a scanline boundary in every phase"
    (dolist (phase '(0 1 2 3))
      (let* ((cartridge (make-patterned-cartridge
                         :mapper 4 :prg-banks 8 :chr-banks 8))
             (nes (make-nes :cartridge cartridge))
             (bus (cl-nes::nes-bus nes))
             (ppu (cl-nes::nes-ppu nes))
             (clock-start (cl-nes::nes-master-clock nes))
             (phase-offset (mod (- clock-start phase) 4)))
        (setf (cl-nes::nes-ppu-phase-offset nes) phase-offset
              (cl-nes::ppu-scanline ppu) 12
              (cl-nes::ppu-dot ppu) 338
              (cl-nes::ppu-mask ppu) 0
              (cl-nes::ppu-control ppu) 0
              (cl-nes::ppu-address-bus ppu) 0
              (cl-nes::cartridge-mapper4-a12-low-m2-cycles cartridge) 0
              (cl-nes::cartridge-mapper4-ppu-a12-high-p cartridge) nil)
        (cartridge-write-prg! cartridge #xC000 0)
        (cartridge-write-prg! cartridge #xC001 0)
        (cartridge-write-prg! cartridge #xE001 0)
        (loop repeat 3 do (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil))
        (expect (cl-nes::nes-master-clock nes) :to-be (+ clock-start 36))
        (expect (cl-nes::ppu-scanline ppu) :to-be 13)
        (expect (cl-nes::ppu-dot ppu) :to-be 6)
        (expect (cl-nes::cartridge-mapper4-a12-low-m2-cycles cartridge)
                :to-be 3)
        (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
        (setf (cl-nes::ppu-control ppu) #x10
              (cl-nes::ppu-mask ppu) #x08
              (cl-nes::ppu-rendering-mask ppu) #x08
              (cl-nes::ppu-rendering-mask-pending ppu) #x08
              (cl-nes::ppu-rendering-mask-delay ppu) 0
              (cl-nes::ppu-rendering-mask-valid-p ppu) t)
        (loop repeat 3 do (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil))
        (expect (cl-nes::nes-master-clock nes) :to-be (+ clock-start 72))
        (expect (cl-nes::cartridge-mapper4-ppu-a12-high-p cartridge)
                :to-be t)
        (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be t)
        (expect (mod (- (cl-nes::nes-master-clock nes) phase-offset) 4)
                :to-be phase)))))
