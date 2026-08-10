(in-package #:cl-nes/test)

(describe "Coverage contracts"
  (it "exercises cartridge constructor and loader defaults"
    (let* ((prg (make-array (* 16 1024)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0))
           (cartridge (make-cartridge :prg-rom prg))
           (loaded (load-cartridge (make-ines-image))))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x2000)
      (expect (cartridge-mapper4-variant cartridge) :to-be :mmc3)
      (expect (cartridge-mapper4-variant loaded) :to-be :mmc3)))

  (it "routes excluded APU reads and frame-counter writes"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (expect (bus-read bus #x4014) :to-be 0)
      (expect (bus-read bus #x4016) :to-be 0)
      (expect (bus-read bus #x4800) :to-be 0)
      (bus-write! bus #x4017 #xC0)
      (expect (cl-nes::apu-frame-irq-inhibit-p apu) :to-be t)
      (expect (cl-nes::apu-frame-last-five-step-p apu) :to-be t)))

  (it "programs pulse one sweep registers"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-1 apu)))
      (apu-write-register! apu #x4001 #xB6)
      (expect (cl-nes::apu-pulse-sweep-enabled-p pulse) :to-be t)
      (expect (cl-nes::apu-pulse-sweep-period pulse) :to-be 4)
      (expect (cl-nes::apu-pulse-sweep-negate-p pulse) :to-be nil)
      (expect (cl-nes::apu-pulse-sweep-shift pulse) :to-be 6)
      (expect (cl-nes::apu-pulse-sweep-reload-p pulse) :to-be t)))

  (it "reports DMC bit activity and honors frame IRQ inhibit"
    (let* ((apu (make-apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-bits-remaining dmc) 1
            (cl-nes::apu-dmc-bytes-remaining dmc) 0
            (cl-nes::apu-dmc-silence-p dmc) t)
      (expect (logbitp 4 (apu-read-register apu #x4015)) :to-be nil)
      (setf (cl-nes::apu-dmc-silence-p dmc) nil)
      (expect (logbitp 4 (apu-read-register apu #x4015)) :to-be t)
      (setf (cl-nes::apu-frame-irq-repeat-count apu) 1
            (cl-nes::apu-frame-irq-inhibit-p apu) t
            (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (setf (cl-nes::apu-frame-irq-inhibit-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)))

  (it "does not load a pulse length while the channel is disabled"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-1 apu)))
      (apu-write-register! apu #x4003 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 0)
      (apu-write-register! apu #x4015 1)
      (apu-write-register! apu #x4003 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 48)
      (let ((pulse-2 (cl-nes::apu-pulse-2 apu)))
        (apu-write-register! apu #x4007 #xA0)
        (expect (cl-nes::apu-pulse-length-counter pulse-2) :to-be 0)
        (apu-write-register! apu #x4015 2)
        (apu-write-register! apu #x4007 #xA0)
        (expect (cl-nes::apu-pulse-length-counter pulse-2) :to-be 48))))

  (it "preserves an active DMC sample when status is rewritten"
    (let* ((apu (make-apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-bytes-remaining dmc) 4)
      (apu-write-register! apu #x4015 #x10)
      (expect (cl-nes::apu-dmc-enabled-p dmc) :to-be t)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 4)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

  (it "fetches DMC bytes through its reader and raises terminal IRQs"
    (let ((read-address nil))
      (let* ((apu (make-apu
                   :memory-reader
                   (lambda (address)
                     (setf read-address address)
                     #x1FF)))
             (dmc (cl-nes::apu-dmc apu)))
        (setf (cl-nes::apu-dmc-enabled-p dmc) t
              (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
              (cl-nes::apu-dmc-bytes-remaining dmc) 1
              (cl-nes::apu-dmc-irq-enabled-p dmc) t
              (cl-nes::apu-dmc-current-address dmc) #xFFFF)
        (cl-nes::%apu-dmc-fetch! apu)
        (expect read-address :to-be #xFFFF)
        (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #xFF)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x8000)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
        (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be t)))
    (let* ((apu (make-apu :memory-reader (lambda (address)
                                           (declare (ignore address))
                                           #x7F)))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 2)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x7F)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil))
    (let* ((apu (make-apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be 0)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)))

  (it "resets MMC1 shift state and forces safe mirroring"
    (let ((cartridge (make-contract-cartridge 1)))
      (cartridge-write-prg! cartridge #x8000 #x80)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x10)
      (expect (cl-nes::cartridge-mapper-control cartridge) :to-be #x0C)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "selects MMC1 mirroring and 8 KiB CHR mode"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1 :prg-banks 4 :chr-banks 32)))
      (labels ((serial-write (address value)
                 (dotimes (bit 5)
                   (cartridge-write-prg!
                    cartridge address (ldb (byte 1 bit) value)))))
        (serial-write #x8000 2)
        (expect (cartridge-mirroring cartridge) :to-be :vertical)
        (serial-write #x8000 3)
        (expect (cartridge-mirroring cartridge) :to-be :horizontal)
        (serial-write #x8000 0)
        (serial-write #xA000 2)
        (expect (cartridge-read-chr cartridge 0) :to-be 16)
        (serial-write #xC000 1)
        (expect (cl-nes::cartridge-mapper-chr-bank-1 cartridge) :to-be 1))))

  (it "updates mapper 28 mirroring and bank registers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 28 :prg-banks 4 :chr-banks 16)))
      (labels ((write-register (register value)
                 (cartridge-write-prg! cartridge #x5000 register)
                 (cartridge-write-prg! cartridge #x8000 value)))
        (write-register #x80 2)
        (expect (cartridge-mirroring cartridge) :to-be :vertical)
        (write-register #x80 3)
        (expect (cartridge-mirroring cartridge) :to-be :horizontal)
        (write-register #x80 0)
        (write-register #x00 #x10)
        (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
        (write-register #x01 0)
        (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)
        (write-register #x80 3)
        (write-register #x00 #x10)
        (expect (cartridge-mirroring cartridge) :to-be :horizontal)
        (write-register #x81 #x2A)
        (expect (cl-nes::cartridge-mapper-outer-bank cartridge) :to-be #x2A))))

  (it "does not retrigger MMC3 on a high-to-high A12 sample"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #xC000 0)
      (cartridge-write-prg! cartridge #xE001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (setf (cl-nes::cartridge-mapper4-irq-pending-p cartridge) nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)))

  (it "delays IRQ after status changes and rotates ARR with carry"
    (let ((cpu (make-cpu)))
      (setf (cpu-p cpu) cl-nes::+flag-interrupt-disable+
            (cl-nes::cpu-irq-delay cpu) 0)
      (cl-nes::%restore-status! cpu 0)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 1)
      (setf (cl-nes::cpu-irq-delay cpu) 0
            (cpu-p cpu) cl-nes::+flag-interrupt-disable+)
      (cl-nes::%restore-status! cpu cl-nes::+flag-interrupt-disable+)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 0)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%arr! cpu #xFF) :to-be #x7F)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) cl-nes::+flag-carry+)
      (expect (cl-nes::%arr! cpu #xFF) :to-be #xFF)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%arr! cpu #x80) :to-be #x40)
      (expect (logand (cpu-p cpu) cl-nes::+flag-overflow+)
              :to-be cl-nes::+flag-overflow+)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%aac! cpu #x80) :to-be #x80)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%aac! cpu 0) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+) :to-be 0)))

  (it "covers BIT and shift flag transitions"
    (let ((cpu (make-cpu)))
      (setf (cpu-a cpu) #xFF)
      (cl-nes::%bit! cpu #xC0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-overflow+)
              :to-be cl-nes::+flag-overflow+)
      (expect (logand (cpu-p cpu) cl-nes::+flag-negative+)
              :to-be cl-nes::+flag-negative+)
      (setf (cpu-a cpu) 0)
      (cl-nes::%bit! cpu 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+)
              :to-be cl-nes::+flag-zero+)
      (expect (logand (cpu-p cpu) cl-nes::+flag-overflow+) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-negative+) :to-be 0)
      (expect (cl-nes::%asl-value! cpu #x80) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+)
              :to-be cl-nes::+flag-zero+)
      (expect (cl-nes::%asl-value! cpu 1) :to-be 2)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+) :to-be 0)
      (expect (cl-nes::%lsr-value! cpu 1) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+)
              :to-be cl-nes::+flag-zero+)
      (expect (cl-nes::%lsr-value! cpu 2) :to-be 1)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+) :to-be 0)
      (setf (cpu-p cpu) cl-nes::+flag-carry+)
      (expect (cl-nes::%rol-value! cpu #x80) :to-be 1)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (setf (cpu-p cpu) 0)
      (expect (cl-nes::%rol-value! cpu 0) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-zero+)
              :to-be cl-nes::+flag-zero+)
      (setf (cpu-p cpu) cl-nes::+flag-carry+)
      (expect (cl-nes::%ror-value! cpu 1) :to-be #x80)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (setf (cpu-p cpu) 0)
      (expect (cl-nes::%ror-value! cpu 2) :to-be 1)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+) :to-be 0)))

  (it "delays IRQ after enabling interrupts"
      (let* ((bus (make-bus :cartridge
                            (make-fixture-cartridge :program '(#x78))))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (expect (cpu-interrupt! cpu bus :reset) :to-be nil)
      (setf (cpu-p cpu) 0
            (cl-nes::cpu-irq-delay cpu) 0)
      (expect (cpu-step! cpu bus) :to-be 2)
      (expect (logand (cpu-p cpu) cl-nes::+flag-interrupt-disable+)
              :to-be cl-nes::+flag-interrupt-disable+)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 1)))

  (it "switches nametable storage and distinguishes buffered palette reads"
    (let* ((ppu (make-ppu))
           (four (make-patterned-cartridge
                  :mapper 0 :prg-banks 2 :chr-banks 8 :four-screen-p t))
           (normal (make-patterned-cartridge
                    :mapper 0 :prg-banks 2 :chr-banks 8)))
      (ppu-load-cartridge! ppu four)
      (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x1000)
      (ppu-load-cartridge! ppu four)
      (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x1000)
      (ppu-load-cartridge! ppu normal)
      (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x800)
      (ppu-load-cartridge! ppu normal)
      (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x800)
      (ppu-write-vram! ppu #x2000 #xA5)
      (expect (ppu-read-vram ppu #x3000) :to-be #xA5)
      (ppu-write-vram! ppu #x3F00 #x3C)
      (ppu-write-register! ppu 6 #x3F)
      (ppu-write-register! ppu 6 0)
      (expect (ppu-read-register ppu 7) :to-be #x3C)
      (setf (ppu-status ppu) #x80
            (ppu-control ppu) 0
            (ppu-nmi-pending-p ppu) nil
            (cl-nes::ppu-nmi-delay-p ppu) nil)
      (ppu-write-register! ppu 0 #x80)
      (expect (ppu-nmi-pending-p ppu) :to-be t)
      (expect (ppu-take-nmi! ppu) :to-be nil)
      (expect (ppu-take-nmi! ppu) :to-be t)
      (setf (ppu-nmi-pending-p ppu) t
            (cl-nes::ppu-nmi-delay-p ppu) t)
      (cl-nes::%request-nmi! ppu)
      (setf (ppu-oam-address ppu) #x12
            (aref (ppu-oam ppu) #x12) #xA6)
      (expect (ppu-read-register ppu 4) :to-be #xA6)
      (expect (ppu-read-register ppu 1) :to-be 0)
      (ppu-read-register ppu 2)
      (expect (ppu-nmi-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be nil)))

  (it "covers rendering gates and pattern fetch phases"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-mask ppu) 0
            (cl-nes::ppu-scanline ppu) 0)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be nil)
      (setf (ppu-mask ppu) #x08)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be t)
      (setf (cl-nes::ppu-scanline ppu) 240)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be nil)
      (setf (cl-nes::ppu-scanline ppu) 261)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be t)
      (setf (ppu-control ppu) 0
            (cl-nes::ppu-dot ppu) 10)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (ppu-control ppu) #x10)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 14)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (cl-nes::ppu-dot ppu) 330)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 334)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (ppu-control ppu) #x08
            (cl-nes::ppu-dot ppu) 266)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 270)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (cl-nes::%ppu-clock-render-a12! (make-ppu) t)
      (let ((background-ppu (make-ppu (make-fixture-cartridge))))
        (ppu-write-register! background-ppu 1 0)
        (multiple-value-bind (color present)
            (cl-nes::%background-pixel background-ppu 0 0)
          (expect color :to-be 0)
          (expect present :to-be nil))
        (ppu-write-register! background-ppu 1 #x02)
        (multiple-value-bind (color present)
            (cl-nes::%background-pixel background-ppu 0 0)
          (expect color :to-be 0)
          (expect present :to-be nil))
        (ppu-write-register! background-ppu 1 #x06)
        (multiple-value-bind (color present)
            (cl-nes::%background-pixel background-ppu 0 0)
          (expect color :to-be 0)
          (expect present :to-be nil)))
      (let ((sprite-ppu (make-ppu (make-fixture-cartridge))))
        (ppu-write-register! sprite-ppu 1 #x10)
        (ppu-write-vram! sprite-ppu #x0000 #x80)
        (ppu-write-vram! sprite-ppu #x3F11 #x21)
        (setf (aref (ppu-oam sprite-ppu) 0) 0
              (aref (ppu-oam sprite-ppu) 1) 0
              (aref (ppu-oam sprite-ppu) 2) 0
              (aref (ppu-oam sprite-ppu) 3) 8
              (ppu-control sprite-ppu) 0)
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 8 1)
          (expect color :to-be #x21)
          (expect present :to-be t)
          (expect behind :to-be nil))
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
          (expect color :to-be nil)
          (expect present :to-be nil)
          (expect behind :to-be nil))
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 8 0)
          (expect color :to-be nil)
          (expect present :to-be nil)
          (expect behind :to-be nil))
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 16 1)
          (expect color :to-be nil)
          (expect present :to-be nil)
          (expect behind :to-be nil))
        (setf (aref (ppu-oam sprite-ppu) 3) 0)
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
          (expect color :to-be #x21)
          (expect present :to-be t)
          (expect behind :to-be nil))
        (setf (ppu-mask sprite-ppu) 0)
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
          (expect color :to-be nil)
          (expect present :to-be nil)
          (expect behind :to-be nil))
        (setf (aref (ppu-oam sprite-ppu) 3) 8
              (ppu-mask sprite-ppu) #x10)
        (let ((background-opaque
                (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                            :element-type 'bit
                            :initial-element 0))
              (occupied
                (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                            :element-type 'bit
                            :initial-element 0)))
          (cl-nes::%draw-sprite-pixel!
           sprite-ppu 1 0 1 background-opaque occupied)
          (expect (aref occupied cl-nes::+ppu-width+) :to-be 1))
        (ppu-write-vram! sprite-ppu #x1000 #x80)
        (setf (ppu-control sprite-ppu) #x08)
        (multiple-value-bind (color present behind)
            (cl-nes::%sprite-pixel sprite-ppu 0 8 1)
          (expect color :to-be #x21)
          (expect present :to-be t)
          (expect behind :to-be nil)))))

  (it "covers the even-frame wrap"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 340
            (cl-nes::ppu-odd-frame-p ppu) nil)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be t)))

  (it "loads iNES images from pathname designators"
    (let* ((pathname (merge-pathnames
                      (make-pathname
                       :name (format nil "cl-nes-contract-~D"
                                     (get-internal-real-time))
                       :type "nes")
                      (uiop:temporary-directory)))
           (image (make-ines-image)))
      (unwind-protect
           (progn
             (with-open-file
                 (stream pathname
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create
                         :element-type '(unsigned-byte 8))
               (write-sequence image stream))
             (expect (cartridge-mapper (load-cartridge pathname)) :to-be 0)
             (expect (cartridge-mapper
                      (load-cartridge (namestring pathname)))
                     :to-be 0))
        (when (probe-file pathname)
          (delete-file pathname))))))
