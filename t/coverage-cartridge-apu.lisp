(in-package #:cl-nes/test)

(describe "Coverage: cartridge and APU contracts"
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
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil))))
