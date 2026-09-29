(in-package #:cl-nes/test)

(describe "Bus memory transitions"
  (it "mirrors internal RAM and retains the open-bus value"
    (let ((bus (make-bus :cartridge (make-fixture-cartridge))))
      (bus-write! bus #x0000 #xA5)
      (expect (bus-read bus #x0800) :to-be #xA5)
      (bus-write! bus #x4018 #x5A)
      (expect (bus-read bus #x4018) :to-be #x5A)))

  (it "transfers a page through OAM DMA and consumes its stall once"
    (let ((bus (make-bus :cartridge (make-fixture-cartridge))))
      (dotimes (offset 256)
        (bus-write! bus offset offset))
      (bus-write! bus #x2003 0)
      (bus-write! bus #x4014 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 0) :to-be 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #xFF) :to-be #xFF)
      (expect (ppu-oam-address (cl-nes::bus-ppu bus)) :to-be 0)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 513)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 0))))
