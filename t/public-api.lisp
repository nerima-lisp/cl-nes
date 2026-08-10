(in-package #:cl-nes/test)

(describe "cartridge construction"
  (it "preserves mapper and CHR-RAM metadata"
    (let ((cartridge (make-fixture-cartridge)))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-chr-writable-p cartridge) :to-be t)
      (expect (length (cartridge-prg-rom cartridge)) :to-be #x8000))))

(describe "controller input"
  (it "serializes the pressed button bits"
    (let ((controller (make-controller)))
      (controller-set-buttons! controller
                                (logior +button-a+ +button-right+))
      (controller-write! controller 1)
      (controller-write! controller 0)
      (expect (controller-read controller) :to-be 1)
      (dotimes (index 6)
        (controller-read controller))
      (expect (controller-read controller) :to-be 1))))

(describe "cartridge-free console lifecycle"
  (it "resets a console before a cartridge is loaded"
    (let ((nes (make-nes)))
      (expect (nes-reset! nes) :to-be nes)
      (expect (cpu-pc (nes-cpu nes)) :to-be 0))))

(describe "NES continuations"
  (it "passes a step result to the continuation"
    (let* ((nes (make-nes :cartridge
                          (make-fixture-cartridge
                           :program '(#xEA #x4C #x00 #x80))))
           (observed nil)
           (result (nes-step/k nes
                               (lambda (cycles)
                                 (setf observed cycles)
                                 :continued))))
      (expect result :to-be :continued)
      (expect observed :to-be 2)))
  (it-each (((#xEA) 2)
            ((#xA9 #x01) 2)
            ((#xE8) 2))
      "passes CPU cycle count for ~S (~D cycles)"
      (program cycles)
    (let ((nes (make-nes :cartridge
                         (make-fixture-cartridge :program program))))
      (expect (nes-step/k nes #'identity) :to-be cycles)))
  (it "passes a complete framebuffer to the continuation"
    (let ((nes (make-nes :cartridge (make-fixture-cartridge)))
          (observed nil))
      (expect (nes-run-frame/k nes
                               (lambda (framebuffer)
                                 (setf observed framebuffer)
                                 :continued))
              :to-be :continued)
      (expect (length observed) :to-be (* 256 240))
      (expect (ppu-frame-ready-p (nes-ppu nes)) :to-be t))))

(describe "MMC3 mapper"
  (it-each ((0 2 3 6 7)
            (#x40 6 3 2 7))
      "maps PRG slots with bank-select bit ~X"
      (bank-select slot-0 slot-1 slot-2 slot-3)
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4
                      :prg-banks 8
                      :chr-banks 8)))
      (dolist (entry '((6 2) (7 3)))
        (cartridge-write-prg! cartridge #x8000 (first entry))
        (cartridge-write-prg! cartridge #x8001 (second entry)))
      (cartridge-write-prg! cartridge #x8000 bank-select)
      (loop for address from #x8000 by #x2000
            for expected in (list slot-0 slot-1 slot-2 slot-3)
            do (expect (cartridge-read-prg cartridge address)
                       :to-be
                       expected))))
  (it-each ((0 2 3 4 5 5 6 7 1)
            (#x80 5 6 7 1 2 3 4 5))
      "maps CHR slots with bank-select bit ~X"
      (bank-select slot-0 slot-1 slot-2 slot-3
                   slot-4 slot-5 slot-6 slot-7)
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4
                      :prg-banks 8
                      :chr-banks 8)))
      (dolist (entry '((0 2) (1 4) (2 5)
                       (3 6) (4 7) (5 1)))
        (cartridge-write-prg! cartridge #x8000 (first entry))
        (cartridge-write-prg! cartridge #x8001 (second entry)))
      (cartridge-write-prg! cartridge #x8000 bank-select)
      (loop for slot below 8
            for expected in (list slot-0 slot-1 slot-2 slot-3
                                  slot-4 slot-5 slot-6 slot-7)
            for address = (* slot cl-nes::+chr-bank-1k-size+)
            do (expect (cartridge-read-chr cartridge address)
                       :to-be
                       expected))))
  (it "controls mirroring, PRG-RAM, and A12 IRQ filtering"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4
                      :prg-banks 8
                      :chr-banks 8)))
      (cartridge-write-prg! cartridge #xA000 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (cartridge-write-prg! cartridge #xA000 1)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (cartridge-write-prg-ram! cartridge #x6000 #xA5)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)
      (cartridge-write-prg! cartridge #xA001 0)
      (cartridge-write-prg-ram! cartridge #x6000 #x5A)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be nil)
      (cartridge-write-prg! cartridge #xA001 #x80)
      (cartridge-write-prg-ram! cartridge #x6000 #x5A)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #x5A)
      (cartridge-write-prg! cartridge #xA001 #xC0)
      (cartridge-write-prg-ram! cartridge #x6000 #xA5)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #x5A)
      (let ((four-screen (make-patterned-cartridge
                          :mapper 4
                          :prg-banks 8
                          :chr-banks 8
                          :four-screen-p t)))
        (cartridge-write-prg! four-screen #xA000 0)
        (expect (cartridge-mirroring four-screen) :to-be :horizontal))
      (cartridge-write-prg! cartridge #xC000 1)
      (cartridge-write-prg! cartridge #xE001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 23)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 1)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cartridge-write-prg! cartridge #xE000 0)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cartridge-write-prg! cartridge #xE001 0)
      (cartridge-write-prg! cartridge #xC001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be t)))
  (it "distinguishes MMC6 zero-counter reload behavior"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4
                      :prg-banks 8
                      :chr-banks 8
                      :mapper4-variant :mmc6)))
      (cartridge-write-prg! cartridge #xC000 0)
      (cartridge-write-prg! cartridge #xE001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cartridge-write-prg! cartridge #xC001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be t))))

(describe "MMC5 mapper"
  (it-each ((0 4 5 6 7)
            (1 8 9 12 13)
            (2 2 3 10 14)
            (3 4 5 6 7))
      "maps PRG slots in mode ~D"
      (mode expected-0 expected-1 expected-2 expected-3)
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16)))
      (cl-nes::cartridge-write-expansion! cartridge #x5100 mode)
      (case mode
        (0 (cl-nes::cartridge-write-expansion! cartridge #x5117 #x84))
        (1 (cl-nes::cartridge-write-expansion! cartridge #x5115 #x88)
           (cl-nes::cartridge-write-expansion! cartridge #x5117 #x8C))
        (2 (cl-nes::cartridge-write-expansion! cartridge #x5115 #x82)
           (cl-nes::cartridge-write-expansion! cartridge #x5116 #x8A)
           (cl-nes::cartridge-write-expansion! cartridge #x5117 #x8E))
        (3 (dolist (entry '((#x5114 #x84) (#x5115 #x85)
                            (#x5116 #x86) (#x5117 #x87)))
            (cl-nes::cartridge-write-expansion!
             cartridge (first entry) (second entry)))))
      (loop for address from #x8000 by #x2000
            for expected in (list expected-0 expected-1
                                  expected-2 expected-3)
            do (expect (cartridge-read-prg cartridge address)
                       :to-be
                       expected))))
  (it "maps writable PRG-RAM through CPU address space"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16)))
      (cl-nes::cartridge-write-expansion! cartridge #x5100 3)
      (cl-nes::cartridge-write-expansion! cartridge #x5114 0)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
      (cartridge-write-prg! cartridge #x8000 #x5A)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be 0)
      (cl-nes::cartridge-write-expansion! cartridge #x5102 2)
      (cl-nes::cartridge-write-expansion! cartridge #x5103 1)
      (expect (cartridge-write-prg! cartridge #x8000 #xA5) :to-be #xA5)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)
      (expect (cartridge-read-prg cartridge #x8000) :to-be #xA5)
      (cl-nes::cartridge-write-expansion! cartridge #x5114 #x80)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
      (cartridge-write-prg! cartridge #x8000 #x5A)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)))
  (it "banks and protects PRG-RAM at $6000"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16
                      :prg-ram-size (* 2 cl-nes::+prg-ram-bank-size+))))
      (cl-nes::cartridge-write-expansion! cartridge #x5113 1)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be 0)
      (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
              :to-be #xA5)
      (expect (aref (cartridge-prg-ram cartridge)
                    cl-nes::+prg-ram-bank-size+)
              :to-be 0)
      (cl-nes::cartridge-write-expansion! cartridge #x5102 2)
      (cl-nes::cartridge-write-expansion! cartridge #x5103 1)
      (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
              :to-be #xA5)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)
      (expect (aref (cartridge-prg-ram cartridge)
                    cl-nes::+prg-ram-bank-size+)
              :to-be #xA5)
      (cl-nes::cartridge-write-expansion! cartridge #x5102 0)
      (cartridge-write-prg-ram! cartridge #x6000 #x5A)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)))
  (it "leaves an empty PRG-RAM window unavailable"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16
                      :prg-ram-size 0)))
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be nil)
      (cl-nes::cartridge-write-expansion! cartridge #x5114 0)
      (expect (cartridge-read-prg cartridge #x8000) :to-be nil)
      (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
              :to-be #xA5)))
  (it-each ((0 (8 9 10 11 12 13 14 15) (0 1 2 3 4 5 6 7))
            (1 (4 5 6 7 8 9 10 11) (0 1 2 3 0 1 2 3))
            (2 (0 1 2 3 4 5 6 7) (8 9 10 11 10 11 10 11))
            (3 (0 1 2 3 4 5 6 7) (8 9 10 11 8 9 10 11)))
      "maps sprite and background CHR slots in mode ~D"
      (mode sprite-banks background-banks)
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16)))
      (dotimes (index 12)
        (cl-nes::cartridge-write-expansion!
         cartridge (+ #x5120 index) index))
      (case mode
        (0
         (cl-nes::cartridge-write-expansion! cartridge #x5127 8)
         (cl-nes::cartridge-write-expansion! cartridge #x512B 0))
        (1
         (cl-nes::cartridge-write-expansion! cartridge #x5123 4)
         (cl-nes::cartridge-write-expansion! cartridge #x5127 8)
         (cl-nes::cartridge-write-expansion! cartridge #x512B 0))
        (2
         (cl-nes::cartridge-write-expansion! cartridge #x5122 0)
         (cl-nes::cartridge-write-expansion! cartridge #x5124 2)
         (cl-nes::cartridge-write-expansion! cartridge #x5126 4)
         (cl-nes::cartridge-write-expansion! cartridge #x5127 6)
         (cl-nes::cartridge-write-expansion! cartridge #x512A 8)
         (cl-nes::cartridge-write-expansion! cartridge #x512B 10)))
      (cl-nes::cartridge-write-expansion! cartridge #x5101 mode)
      (loop for slot below 8
            for expected-sprite in sprite-banks
            for expected-background in background-banks
            for address = (* slot cl-nes::+chr-bank-1k-size+)
            do (expect (cartridge-read-chr cartridge address t)
                       :to-be expected-sprite)
               (expect (cartridge-read-chr cartridge address nil)
                       :to-be expected-background))))
  (it "handles EXRAM, fill, multiplier, nametable sources, and scanline IRQ"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 5
                      :prg-banks 16
                      :chr-banks 16)))
      (cl-nes::cartridge-write-expansion! cartridge #x5105 #xE4)
      (multiple-value-bind (source within)
          (cl-nes::cartridge-mmc5-nametable-location cartridge #x2012)
        (expect source :to-be :ciram-0)
        (expect within :to-be #x12))
      (multiple-value-bind (source within)
          (cl-nes::cartridge-mmc5-nametable-location cartridge #x2412)
        (expect source :to-be :ciram-1)
        (expect within :to-be #x12))
      (multiple-value-bind (source within)
          (cl-nes::cartridge-mmc5-nametable-location cartridge #x2812)
        (expect source :to-be :exram)
        (expect within :to-be #x12))
      (multiple-value-bind (source within)
          (cl-nes::cartridge-mmc5-nametable-location cartridge #x2C12)
        (expect source :to-be :fill)
        (expect within :to-be #x12))
      (cl-nes::cartridge-write-expansion! cartridge #x5106 #xAA)
      (cl-nes::cartridge-write-expansion! cartridge #x5107 2)
      (expect (cl-nes::cartridge-mmc5-fill-value cartridge #x0012)
              :to-be #xAA)
      (expect (cl-nes::cartridge-mmc5-fill-value cartridge #x03C0)
              :to-be #xAA)
      (cl-nes::cartridge-write-expansion! cartridge #x5104 0)
      (expect (cl-nes::cartridge-write-expansion! cartridge #x5BFF #x55)
              :to-be #x55)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5BFF)
              :to-be nil)
      (cl-nes::cartridge-write-expansion! cartridge #x5C00 #x33)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5C00)
              :to-be #x33)
      (cl-nes::cartridge-write-expansion! cartridge #x5104 3)
      (cl-nes::cartridge-write-expansion! cartridge #x5C00 #x44)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5C00)
              :to-be nil)
      (cl-nes::cartridge-write-expansion! cartridge #x5200 #x80)
      (cl-nes::cartridge-write-expansion! cartridge #x5201 #x10)
      (cl-nes::cartridge-write-expansion! cartridge #x5202 #x02)
      (expect (cl-nes::cartridge-mapper5-split-control cartridge)
              :to-be #x80)
      (expect (cl-nes::cartridge-mapper5-split-scroll cartridge)
              :to-be #x10)
      (expect (cl-nes::cartridge-mapper5-split-bank cartridge)
              :to-be #x02)
      (cl-nes::cartridge-write-expansion! cartridge #x5205 3)
      (cl-nes::cartridge-write-expansion! cartridge #x5206 7)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5205)
              :to-be 21)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5206)
              :to-be 0)
      (cl-nes::cartridge-write-expansion! cartridge #x5203 42)
      (cl-nes::cartridge-write-expansion! cartridge #x5204 #x80)
      (cl-nes::cartridge-clock-scanline! cartridge 42)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be t)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5204)
              :to-be #xC0)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cl-nes::cartridge-clock-scanline! cartridge 1)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5204)
              :to-be #x40)
      (cl-nes::cartridge-write-expansion! cartridge #x5204 0)
      (cl-nes::cartridge-clock-scanline! cartridge 42)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)
      (cl-nes::cartridge-clock-scanline! cartridge 240)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5204)
              :to-be 0)))

  (it "ignores MMC5 expansion operations for other mappers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 0 :prg-banks 2 :chr-banks 8)))
      (expect (cl-nes::cartridge-write-expansion! cartridge #x5C00 #x42)
              :to-be #x42)
      (expect (cl-nes::cartridge-read-expansion cartridge #x5C00)
              :to-be nil)
      (multiple-value-bind (source within)
          (cl-nes::cartridge-mmc5-nametable-location cartridge #x2000)
        (expect source :to-be nil)
        (expect within :to-be nil)))))

(describe "APU defaults"
  (it "starts silent"
    (expect (apu-sample (make-apu)) :to-be 0)))

(describe "ROM validation"
  (it "signals invalid-rom for an incomplete image"
    (expect (handler-case
                (progn (load-cartridge #(0)) nil)
              (invalid-rom () t))
            :to-be t)))
