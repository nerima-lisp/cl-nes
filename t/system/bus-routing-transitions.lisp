(in-package #:cl-nes/test)

(describe "Bus routing transitions"
  (it "mirrors internal RAM and preserves the open bus value"
    (let ((bus (make-bus)))
      (bus-write! bus #x17FF #xA6)
      (expect (bus-read bus #x07FF) :to-be #xA6)
      (expect (bus-read bus #x17FF) :to-be #xA6)
      (bus-write! bus #x5000 #xD9)
      (expect (bus-read bus #x5001) :to-be #xD9)))

  (it "copies a direct OAM DMA page and reports its stall cost"
    (let ((bus (make-bus)))
      (dotimes (offset 256)
        (bus-write! bus (+ #x0200 offset) offset))
      (bus-write! bus #x4014 #x02)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 513)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 0) :to-be 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 127) :to-be 127)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 255) :to-be 255)))

  (it "routes CPU windows to PPU, APU, controllers, and cartridge memory"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (ppu (make-ppu cartridge))
           (apu (make-apu))
           (controller-1 (make-controller))
           (controller-2 (make-controller))
           (bus (make-bus :cartridge cartridge
                          :ppu ppu
                          :apu apu
                          :controller-1 controller-1
                          :controller-2 controller-2)))
      (setf (ppu-status ppu) #xE0)
      (expect (bus-read bus #x2002) :to-be #xE0)
      (bus-write! bus #x2001 #x18)
      (expect (ppu-mask ppu) :to-be #x18)
      (setf (cl-nes::apu-frame-irq-pending-p apu) t)
      (expect (bus-read bus #x4015) :to-be #x40)
      (controller-set-buttons! controller-1 cl-nes::+button-a+)
      (controller-set-buttons! controller-2 cl-nes::+button-a+)
      (bus-write! bus #x4016 1)
      (expect (bus-read bus #x4016) :to-be 1)
      (expect (bus-read bus #x4017) :to-be 1)
      (expect (bus-write! bus #x4000 #xFF) :to-be #xFF)
      (expect (bus-write! bus #x4015 0) :to-be 0)
      (expect (bus-write! bus #x5000 #x33) :to-be #x33)
      (expect (bus-read bus #x5000) :to-be #x33)
      (bus-write! bus #x6000 #xB6)
      (expect (bus-read bus #x6000) :to-be #xB6)
      (expect (bus-read bus #x8000) :to-be #xEA)))

  (it "routes mapper expansion and NROM-368 windows"
    (let* ((mapper5 (make-patterned-cartridge
                     :mapper 5
                     :prg-banks 16
                     :chr-banks 16))
           (expansion-bus (make-bus :cartridge mapper5)))
      (bus-write! expansion-bus #x5C00 #xA7)
      (expect (bus-read expansion-bus #x5C00) :to-be #xA7))
    (let* ((prg (make-array (* 48 1024)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0))
           (cartridge (make-cartridge :prg-rom prg))
           (bus (make-bus :cartridge cartridge)))
      (setf (aref (cartridge-prg-rom cartridge) #x0800) #xC3)
      (expect (bus-read bus #x4800) :to-be #xC3)
      (bus-write! bus #x6000 #xD4)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be 0))))
