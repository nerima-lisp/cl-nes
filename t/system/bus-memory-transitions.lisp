(in-package #:cl-nes/test)

(describe "Bus memory transitions"
  (it "charges the PPU status read at the end of an active CPU access"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (ppu (nes-ppu nes)))
      (setf (cl-nes::ppu-dot ppu) 10
            (ppu-status ppu) #x80
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (expect (bus-read bus #x2002) :to-be #x80)
      (expect (cl-nes::ppu-dot ppu) :to-be 13)
      (expect (cl-nes::bus-cpu-access-count bus) :to-be 1)))

  (it "replays an open-bus CPU read after a DMC fetch"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::bus-open-bus bus) #xA7
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x5000) :to-be #xA7)
      (expect (cl-nes::bus-dmc-read-replay-p bus) :to-be nil)
      (expect (cl-nes::bus-dma-stall-cycles bus) :to-be 4)))

  (it "uses open bus data when an OAM DMA source is unmapped"
    (let ((bus (make-bus)))
      (setf (cl-nes::bus-open-bus bus) #x5A
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x50
            (cl-nes::bus-oam-dma-index bus) 0
            (cl-nes::bus-oam-dma-stage bus) :get)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-open-bus bus) :to-be #x5A)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 0) :to-be #x5A)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 1)))

  (it "uses cycle phase when repeated controller strobe writes are high"
    (let ((bus (make-bus))
          (controller (make-controller)))
      (setf (cl-nes::bus-controller-1 bus) controller
            (cl-nes::bus-last-cpu-access-address bus) #x4016
            (cl-nes::bus-cpu-cycle-phase bus) 1)
      (expect (bus-write! bus #x4016 1) :to-be 1)
      (expect (cl-nes::controller-strobe controller) :to-be nil)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 0)
      (expect (bus-write! bus #x4016 1) :to-be 1)
      (expect (cl-nes::controller-strobe controller) :to-be t)))

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
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 4)))

  (it "replays a CPU PPU read after DMC dummy reads"
    (let* ((nes (make-nes))
           (bus (cl-nes::nes-bus nes))
           (ppu (cl-nes::nes-ppu nes))
           (apu (cl-nes::nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (aref (cl-nes::ppu-nametable ppu) 0) #x22
            (aref (cl-nes::ppu-nametable ppu) 1) #x33
            (aref (cl-nes::ppu-nametable ppu) 2) #x44
            (cl-nes::ppu-vram-address ppu) #x2000
            (cl-nes::ppu-read-buffer ppu) #x11
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x2007) :to-be #x33)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x44)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2003)
      (expect (cl-nes::bus-dmc-read-replay-p bus) :to-be nil)))

  (it "advances OAM DMA as get/put cycles"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (bus (cl-nes::nes-bus nes)))
      (dotimes (offset 256)
        (setf (aref (cl-nes::bus-ram bus) (+ #x700 offset)) offset))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (bus-write! bus #x4014 7)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil)
      (cl-nes::%nes-run-dma-stalls!
       nes (cl-nes::bus-take-dma-stall-cycles! bus))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #x00) :to-be 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #xFF) :to-be #xFF)))

  (it "lets DMC phases preempt OAM gets while OAM puts continue"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (bus (cl-nes::nes-bus nes))
           (dmc (cl-nes::apu-dmc (cl-nes::nes-apu nes)))
           (clock-count 0))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (bus-write! bus #x4014 7)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (cl-nes::%nes-run-dma-stalls!
       nes (cl-nes::bus-take-dma-stall-cycles! bus)
       (lambda () (incf clock-count)))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-dmc-dma-remaining bus) :to-be 0)
      (expect clock-count :to-be 516))))
