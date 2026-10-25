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

  (it "queues a DMC load request during an NES-owned open-bus read"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::bus-open-bus bus) #xA7
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x5000) :to-be #xA7)
      (expect (cl-nes::bus-dmc-read-replay-p bus) :to-be nil)
      (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :load)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :wait)
      (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 2)
      (expect (cl-nes::bus-dma-stall-cycles bus) :to-be 0)))

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
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
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
           (dmc (cl-nes::apu-dmc (cl-nes::nes-apu nes))))
      (setf (aref (cl-nes::ppu-nametable ppu) 0) #x22
            (aref (cl-nes::ppu-nametable ppu) 1) #x33
            (aref (cl-nes::ppu-nametable ppu) 2) #x44
            (cl-nes::ppu-vram-address ppu) #x2000
            (cl-nes::ppu-read-buffer ppu) #x11
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-dmc-dma-stage bus) :ready
            (cl-nes::bus-dmc-dma-kind bus) :load
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x2007) :to-be #x33)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x44)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2003)
      (expect (cl-nes::bus-cpu-access-count bus) :to-be 4)
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
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes)))
      (cl-nes::%nes-run-dma-stalls! nes
                                    (cl-nes::bus-take-dma-stall-cycles! bus))
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
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes))
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (cl-nes::%nes-run-dma-stalls! nes
                                    (cl-nes::bus-take-dma-stall-cycles! bus)
                                    (lambda ()
                                      (incf clock-count)))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-dmc-dma-remaining bus) :to-be 0)
      (expect clock-count :to-be 516))))

  (it "charges DMC and OAM DMA competition at the CPU instruction boundary"
    (let* ((cartridge (make-fixture-cartridge
                       :program (list #xA9 #x07 #x8D #x14 #x40)))
           (nes (make-nes :cartridge cartridge))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (dotimes (offset 256)
        (setf (aref (cl-nes::bus-ram bus) offset) offset))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) nil
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-sample-buffer dmc) #xA5
            (cl-nes::apu-dmc-bits-remaining dmc) 0
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 5)
      ;; The nonempty buffer prevents a request during LDA. Its sixth APU
      ;; clock empties it on STA write, after OAM DMA has started.
      (let ((instruction-cycles (nes-step/k nes (function identity))))
        (expect instruction-cycles :to-be 2)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-timer dmc) :to-be 3)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle))
      (let* ((sta-cycles 4)
             (oam-halt-cycles 1)
             (oam-get-put-cycles (* 256 2))
             ;; DMC reload halt is on put. Its dummy overlaps OAM get,
             ;; alignment overlaps OAM put, then DMC get takes the next OAM
             ;; get. The odd-phase get retry is the second delayed cycle.
             (dmc-oam-delay-cycles 2)
             (oam-write-phase (logxor (cl-nes::bus-cpu-cycle-phase bus) 1))
             (oam-alignment-cycles (if (= oam-write-phase 1) 1 0))
             (expected-cycles (+ sta-cycles
                                 oam-halt-cycles
                                 oam-get-put-cycles
                                 oam-alignment-cycles
                                 dmc-oam-delay-cycles))
             (cycles (nes-step/k nes (function identity))))
        (expect cycles :to-be expected-cycles)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8005)
        (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
        (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :reload)
        (expect (cl-nes::bus-dmc-dma-remaining bus) :to-be 0))))
  (it "arbitrates DMC halts and no-op reads against OAM DMA"
    (let* ((load-bus (make-bus))
           (load-ppu (cl-nes::bus-ppu load-bus))
           (reload-bus (make-bus))
           (bus (make-bus))
           (ppu (cl-nes::bus-ppu bus)))
      (setf (cl-nes::bus-oam-dma-active-p load-bus) t
            (cl-nes::bus-oam-dma-stage load-bus) :put
            (cl-nes::bus-oam-dma-data load-bus) #x5A
            (cl-nes::bus-cpu-cycle-phase load-bus) 1
            (cl-nes::bus-last-cpu-access-kind load-bus) :read
            (cl-nes::bus-dmc-dma-stage load-bus) :ready
            (cl-nes::bus-dmc-dma-kind load-bus) :load)
      (cl-nes::%bus-advance-dma-cycle! load-bus)
      (expect (cl-nes::bus-dmc-dma-stage load-bus) :to-be :ready)
      (expect (cl-nes::bus-oam-dma-index load-bus) :to-be 1)
      (expect (aref (ppu-oam load-ppu) 0) :to-be #x5A)
      (setf (cl-nes::bus-cpu-cycle-phase load-bus) 0
            (cl-nes::bus-oam-dma-stage load-bus) :get)
      (cl-nes::%bus-advance-dma-cycle! load-bus)
      (expect (cl-nes::bus-dmc-dma-stage load-bus) :to-be :dummy)
      (expect (cl-nes::bus-dmc-dma-remaining load-bus) :to-be 2)
      (expect (cl-nes::bus-oam-dma-stage load-bus) :to-be :put)

      (setf (cl-nes::bus-oam-dma-active-p reload-bus) t
            (cl-nes::bus-oam-dma-stage reload-bus) :get
            (cl-nes::bus-cpu-cycle-phase reload-bus) 0
            (cl-nes::bus-last-cpu-access-kind reload-bus) :read
            (cl-nes::bus-dmc-dma-stage reload-bus) :ready
            (cl-nes::bus-dmc-dma-kind reload-bus) :reload)
      (cl-nes::%bus-advance-dma-cycle! reload-bus)
      (expect (cl-nes::bus-dmc-dma-stage reload-bus) :to-be :ready)
      (expect (cl-nes::bus-oam-dma-stage reload-bus) :to-be :put)
      (setf (cl-nes::bus-cpu-cycle-phase reload-bus) 1)
      (cl-nes::%bus-advance-dma-cycle! reload-bus)
      (expect (cl-nes::bus-dmc-dma-stage reload-bus) :to-be :dummy)
      (expect (cl-nes::bus-dmc-dma-remaining reload-bus) :to-be 3)
      (expect (cl-nes::bus-oam-dma-index reload-bus) :to-be 1)

      (setf (aref (cl-nes::ppu-nametable ppu) 0) #x22
            (aref (cl-nes::ppu-nametable ppu) 1) #x33
            (cl-nes::ppu-vram-address ppu) #x2000
            (cl-nes::ppu-read-buffer ppu) #x11
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x20
            (cl-nes::bus-oam-dma-index bus) 7
            (cl-nes::bus-oam-dma-stage bus) :get
            (cl-nes::bus-dmc-dma-stage bus) :dummy
            (cl-nes::bus-dmc-dma-remaining bus) 3
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x2007)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :alignment)
      (expect (cl-nes::bus-oam-dma-data bus) :to-be #x11)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :get)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 8)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 0)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
      (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 8)
      (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2002)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 0)
      (cl-nes::%bus-advance-dma-cycle! bus)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)))
