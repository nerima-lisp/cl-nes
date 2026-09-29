(in-package #:cl-nes/test)

(describe "PPU MMC5 memory transitions"
  (it "routes MMC5 nametables through CIRAM, EXRAM, and fill"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (ppu (make-ppu cartridge)))
      (cl-nes::cartridge-write-expansion! cartridge #x5105 #xE4)
      (cl-nes::cartridge-write-expansion! cartridge #x5106 #xAA)
      (cl-nes::cartridge-write-expansion! cartridge #x5107 2)
      (ppu-write-vram! ppu #x2000 #x11)
      (ppu-write-vram! ppu #x2400 #x22)
      (ppu-write-vram! ppu #x2800 #x33)
      (expect (ppu-read-vram ppu #x2000) :to-be #x11)
      (expect (ppu-read-vram ppu #x2400) :to-be #x22)
      (expect (ppu-read-vram ppu #x2800) :to-be #x33)
      (expect (ppu-read-vram ppu #x2C00) :to-be #xAA)
      (ppu-write-vram! ppu #x2C00 #x55)
      (expect (ppu-read-vram ppu #x2C00) :to-be #xAA)))

  (it "activates the MMC5 split window with split scroll"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (ppu (make-ppu cartridge)))
      (setf (cl-nes::ppu-scanline ppu) 10)
      (cl-nes::cartridge-write-expansion! cartridge #x5200 #x84)
      (cl-nes::cartridge-write-expansion! cartridge #x5201 3)
      (multiple-value-bind (active-p split-x split-y)
          (cl-nes::%ppu-mmc5-split-state ppu 17)
        (expect active-p :to-be t)
        (expect split-x :to-be 2)
        (expect split-y :to-be 13))
      (multiple-value-bind (active-p split-x split-y)
          (cl-nes::%ppu-mmc5-split-state ppu 41)
        (expect active-p :to-be nil)
        (expect split-x :to-be 0)
        (expect split-y :to-be 0)))))

  (it "renders split and normal pixels from fetched tiles and attributes"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (ppu (make-ppu cartridge))
           (chr (cl-nes::cartridge-chr-rom cartridge)))
      (setf (ppu-mask ppu) #x06
            (cl-nes::ppu-scanline ppu) 10)
      (cl-nes::cartridge-write-expansion! cartridge #x5104 0)
      (cl-nes::cartridge-write-expansion! cartridge #x5200 #x81)
      (cl-nes::cartridge-write-expansion! cartridge #x5201 9)
      (cl-nes::cartridge-write-expansion! cartridge #x5C20 2)
      (setf (aref chr 33) #x80
            (aref chr 41) 0)
      (setf (cl-nes::ppu-dot ppu) 1)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-next-tile ppu) 2)
      (setf (cl-nes::ppu-dot ppu) 3)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 5)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 7)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 8)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-background-shift-low ppu) #x8000)
      (ppu-write-vram! ppu #x3F01 #x21)
      (multiple-value-bind (color solid)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be #x21)
        (expect solid :to-be t))

      (cl-nes::cartridge-write-expansion! cartridge #x5200 0)
      (setf (cl-nes::ppu-vram-address ppu) #x7000
            (cl-nes::ppu-dot ppu) 1)
      (ppu-write-vram! ppu #x2000 3)
      (ppu-write-vram! ppu #x23C0 1)
      (setf (cl-nes::ppu-next-tile ppu) 3)
      (setf (aref chr 55) #x80
            (aref chr 63) 0)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 3)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 5)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 7)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 8)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-background-shift-low ppu) #x8000)
      (ppu-write-vram! ppu #x3F05 #x22)
      (multiple-value-bind (color solid)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be #x22)
        (expect solid :to-be t))))
