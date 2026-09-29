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
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 0)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
      (bus-write! bus #x4014 0)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 514)))

  (it "charges a DMC fetch as a CPU DMA stall"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 4)
      (setf (cl-nes::bus-last-cpu-access-kind bus) :write
            (cl-nes::bus-cpu-cycle-phase bus) 1)
      (funcall (cl-nes::apu-memory-reader apu) #x8000)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 3)))

  ;; DMC dummy reads must not re-enter the active CPU operation and recursively
  ;; clock the APU while the fetch is already in progress.
  (it "keeps DMC dummy reads outside an active CPU access"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::bus-cpu-access-active-p bus) t)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 4))))
