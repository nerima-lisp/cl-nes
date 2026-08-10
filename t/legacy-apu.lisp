(in-package #:cl-nes/test-runner)

(defun test-apu-and-dma ()
  (let ((noise (cl-nes::%make-apu-noise :timer 0 :timer-period 4
                                         :shift-register #x3)))
    (cl-nes::%apu-clock-noise-timer! noise)
    (check-equal (cl-nes::apu-noise-shift-register noise) 1
                 "noise LFSR feeds back the XOR of bit 0 and its tap"))
  (let ((apu (make-apu)))
    (apu-write-register! apu #x4000 #xFF)
    (apu-write-register! apu #x4003 #x07)
    (apu-write-register! apu #x4008 #xFF)
    (apu-write-register! apu #x400B #x07)
    (apu-write-register! apu #x400C #xFF)
    (apu-write-register! apu #x400F #x07)
    (apu-write-register! apu #x4015 #x1F)
    (apu-write-register! apu #x4010 #xCF)
    (apu-write-register! apu #x4012 #x12)
    (apu-write-register! apu #x4013 #x34)
    (apu-reset! apu)
    (check-equal (cl-nes::apu-pulse-length-counter
                  (cl-nes::apu-pulse-1 apu)) 0
                 "APU reset clears pulse length state")
    (check-equal (cl-nes::apu-triangle-linear-counter
                  (cl-nes::apu-triangle apu)) 0
                 "APU reset clears triangle linear state")
    (check-equal (cl-nes::apu-noise-shift-register
                  (cl-nes::apu-noise apu)) 1
                 "APU reset restores the noise LFSR seed")
    (check-equal (cl-nes::apu-dmc-sample-address
                  (cl-nes::apu-dmc apu)) #xC000
                 "APU reset restores the DMC sample address"))
  (let ((apu (make-apu)))
    (apu-write-register! apu #x4015 1)
    (apu-write-register! apu #x4000 #x1F)
    (apu-write-register! apu #x4003 0)
    (check (logbitp 0 (apu-read-register apu #x4015))
           "APU status reports an enabled pulse length counter")
    (apu-tick! apu 29829)
    (check (logbitp 6 (apu-read-register apu #x4015))
           "four-step APU sequence raises the frame IRQ")
    (check (not (logbitp 6 (apu-read-register apu #x4015)))
           "reading APU status clears the frame IRQ")
    (apu-write-register! apu #x4017 #xC0)
    (apu-tick! apu 37281)
    (check (not (logbitp 6 (apu-read-register apu #x4015)))
           "five-step mode with IRQ inhibit does not raise a frame IRQ"))
  (let ((apu (make-apu))
        (reads '()))
    (apu-set-memory-reader! apu
                            (lambda (address)
                              (push address reads)
                              #xAA))
    (apu-write-register! apu #x4010 #x8F)
    (apu-write-register! apu #x4011 0)
    (apu-write-register! apu #x4012 0)
    (apu-write-register! apu #x4013 0)
    (apu-write-register! apu #x4015 #x10)
    (apu-tick! apu 500)
    (check (member #xC000 reads)
           "DMC reads its sample through the configured CPU address space")
    (check (logbitp 7 (apu-read-register apu #x4015))
           "DMC raises its IRQ after a one-byte sample")
    (check (plusp (apu-sample apu))
           "DMC sample bits reach the headless mixer"))
  (let* ((cartridge (make-test-cartridge
                     :program (list #x5A)
                     :start #xC000))
         (bus (make-bus :cartridge cartridge)))
    (bus-write! bus #x4010 #x8F)
    (bus-write! bus #x4011 0)
    (bus-write! bus #x4012 0)
    (bus-write! bus #x4013 0)
    (bus-write! bus #x4015 #x10)
    (apu-tick! (bus-apu bus) 500)
    (check (plusp (apu-sample (bus-apu bus)))
           "DMC receives sample data from the cartridge through the bus")
    (check (logbitp 7 (bus-read bus #x4015))
           "bus-connected DMC exposes its IRQ through APU status"))
  (let ((bus (make-bus)))
    (bus-write! bus #x4000 #x1F)
    (bus-write! bus #x4015 1)
    (bus-write! bus #x4003 0)
    (check (logbitp 0 (bus-read bus #x4015))
           "bus maps APU registers")
    (bus-write! bus #x4014 0)
    (check-equal (cl-nes::bus-take-dma-stall-cycles! bus) 513
                 "OAM DMA schedules its CPU stall"))
  (let* ((cartridge (make-test-cartridge
                     :program (list #xA9 #x02 #x8D #x14 #x40)))
         (nes (make-nes :cartridge cartridge)))
    (check-equal (nes-step/k nes #'identity) 2 "DMA test executes the setup instruction")
    (check-equal (nes-step/k nes #'identity) 517
                 "NES accounts for the OAM DMA CPU stall")))

(defun test-nes-integration ()
  (let* ((cartridge (make-test-cartridge :program (list #xEA #x4C #x00 #x80)))
         (nes (make-nes :cartridge cartridge)))
    (check-equal (cpu-pc (nes-cpu nes)) #x8000
                 "NES construction resets the CPU")
    (check-equal (nes-step/k nes #'identity) 2 "NES steps one CPU instruction")
    (check-equal (cpu-pc (nes-cpu nes)) #x8001
                 "NES advances the CPU program counter")
    (check-equal (cl-nes::ppu-dot (nes-ppu nes)) 6
                 "NES advances the PPU at three times the CPU rate")
    (let ((frame (nes-run-frame/k nes #'identity)))
      (check-equal (length frame) (* 256 240)
                   "NES produces a 256x240 framebuffer")
      (check (ppu-frame-ready-p (nes-ppu nes))
             "NES frame execution reaches VBlank"))
    (nes-reset! nes)
    (check-equal (ppu-status (nes-ppu nes)) 0
                 "NES reset clears PPU status")
    (check-equal (cl-nes::ppu-scanline (nes-ppu nes)) 0
                 "NES reset restarts PPU timing")
    (check-equal (cl-nes::ppu-dot (nes-ppu nes)) 0
                 "NES reset clears the PPU dot")
    (check (not (ppu-frame-ready-p (nes-ppu nes)))
           "NES reset clears the frame-ready state")
    (let* ((cartridge (make-cartridge
                       :prg-rom (make-banked-rom 4 #x4000 #x10)
                       :mapper 1
                       :mirroring :vertical))
           (nes (make-nes :cartridge cartridge))
           (bus (nes-bus nes)))
      (bus-write! bus #x6000 #x5A)
      (dotimes (bit 5)
        (bus-write! bus #x8000 0))
      (check-equal (cartridge-mirroring cartridge) :single-screen-lower
                   "MMC1 reset test changes mapper mirroring")
      (check-equal (cartridge-read-prg cartridge #xC000) #x11
                   "MMC1 reset test changes the active PRG mode")
      (nes-load-cartridge! nes cartridge)
      (check-equal (cartridge-mirroring cartridge) :vertical
                   "NES cartridge reload restores the initial mirroring")
      (check-equal (cartridge-read-prg cartridge #xC000) #x13
                   "NES cartridge reload restores the MMC1 PRG registers")
      (nes-reset! nes)
      (check-equal (cartridge-mirroring cartridge) :vertical
                   "NES reset restores the cartridge mirroring")
      (check-equal (cartridge-read-prg cartridge #xC000) #x13
                   "NES reset restores the MMC1 PRG registers")
      (check-equal (cartridge-read-prg-ram cartridge #x6000) #x5A
                   "NES reset retains PRG-RAM contents"))
  (let* ((cartridge (make-test-cartridge :program (list #xEA #xEA)))
         (nes (make-nes :cartridge cartridge))
         (ppu (nes-ppu nes)))
    (ppu-write-register! ppu 0 #x80)
    (ppu-tick! ppu (- (* 241 341) 5))
    (check-equal (nes-step/k nes #'identity) 2
                 "NES completes the instruction that exposes a new NMI")
    (check-equal (nes-step/k nes #'identity) 9
                 "NES accounts for the seven-cycle NMI after its delay")
    (check-equal (cl-nes::ppu-scanline ppu) 241
                 "NMI timing keeps the PPU on the VBlank scanline")
    (check-equal (cl-nes::ppu-dot ppu) 28
                 "NMI timing advances the PPU after the following instruction"))))


