(in-package #:cl-nes/test)

(defun make-ines-image
    (&key (prg-banks 1) (chr-banks 0)
          (flags6 0) (flags7 0) (byte8 0) (byte9 0) (byte10 0)
          trainer-p (prg-fill #xA5) (chr-fill #x5A))
  (let* ((prg-size (* prg-banks cl-nes::+prg-bank-size+))
         (chr-size (* chr-banks cl-nes::+chr-bank-size+))
         (offset (+ cl-nes::+ines-header-size+
                    (if trainer-p cl-nes::+ines-trainer-size+ 0)))
         (image (make-array (+ offset prg-size chr-size)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0)))
    (setf (aref image 0) #x4E
          (aref image 1) #x45
          (aref image 2) #x53
          (aref image 3) #x1A
          (aref image 4) prg-banks
          (aref image 5) chr-banks
          (aref image 6) (if trainer-p (logior flags6 #x04) flags6)
          (aref image 7) flags7
          (aref image 8) byte8
          (aref image 9) byte9
          (aref image 10) byte10)
    (loop for index from offset below (+ offset prg-size)
          do (setf (aref image index) prg-fill))
    (loop for index from (+ offset prg-size) below (length image)
          do (setf (aref image index) chr-fill))
    image))

(defun captured-condition (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (condition (condition) condition)))

(describe "iNES loader boundaries"
  (it "rejects malformed sources and ROM images"
    (let ((source-condition
            (captured-condition (lambda () (load-cartridge '(1 2 3)))))
          (header-condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (make-array cl-nes::+ines-header-size+
                            :element-type '(unsigned-byte 8)
                            :initial-element 0)))))
          (empty-prg-condition
            (captured-condition
             (lambda () (load-cartridge (make-ines-image :prg-banks 0)))))
          (truncated-condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (subseq (make-ines-image) 0 cl-nes::+ines-header-size+))))))
      (expect (typep source-condition 'invalid-rom) :to-be t)
      (expect (typep header-condition 'invalid-rom) :to-be t)
      (expect (typep empty-prg-condition 'invalid-rom) :to-be t)
      (expect (typep truncated-condition 'invalid-rom) :to-be t)))

  (it "validates every iNES magic byte and decodes legacy PRG-RAM size"
    (dolist (index '(1 2 3))
      (let ((image (make-ines-image)))
        (setf (aref image index) 0)
        (expect (typep
                 (captured-condition (lambda () (load-cartridge image)))
                 'invalid-rom)
                :to-be t)))
    (let ((cartridge (load-cartridge (make-ines-image :byte8 2))))
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x4000)))

  (it "skips trainers and preserves cartridge metadata"
    (let ((cartridge
            (load-cartridge
             (make-ines-image :flags6 #x0B :trainer-p t))))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (expect (cartridge-battery-backed-p cartridge) :to-be t)
      (expect (cartridge-four-screen-p cartridge) :to-be t)
      (expect (cartridge-chr-writable-p cartridge) :to-be t)
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x2000)
      (expect (aref (cartridge-prg-rom cartridge) 0) :to-be #xA5)))

  (it "decodes NES 2.0 RAM sizes and rejects exponent ROM sizes"
    (let ((cartridge
            (load-cartridge
             (make-ines-image :flags7 #x08 :byte10 #x21))))
      (expect (length (cartridge-prg-ram cartridge)) :to-be 384)
      (expect (cartridge-chr-writable-p cartridge) :to-be t))
    (let ((condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (make-ines-image :flags7 #x08 :byte9 #x0F))))))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it "reports unsupported mapper numbers"
    (let ((condition
            (captured-condition
             (lambda ()
               (load-cartridge (make-ines-image :flags6 #x60))))))
      (expect (typep condition 'unsupported-mapper) :to-be t)
      (when (typep condition 'unsupported-mapper)
        (expect (unsupported-mapper-number condition) :to-be 6)))))

(describe "condition reports"
  (it "exposes invalid ROM reasons"
    (let ((condition
            (captured-condition
             (lambda () (error 'invalid-rom :reason "bad header")))))
      (expect (invalid-rom-reason condition) :to-equal "bad header")
      (expect (format nil "~A" condition)
              :to-equal "Invalid iNES ROM: bad header")))

  (it "formats mapper and opcode failures"
    (let ((mapper-condition
            (captured-condition
             (lambda () (error 'unsupported-mapper :number 22))))
          (opcode-condition
            (captured-condition
             (lambda ()
               (error 'illegal-opcode :opcode #x02 :address #xC123)))))
      (expect (format nil "~A" mapper-condition)
              :to-equal "Unsupported NES mapper: 22")
      (expect (illegal-opcode-value opcode-condition) :to-be #x02)
      (expect (illegal-opcode-address opcode-condition) :to-be #xC123)
      (expect (format nil "~A" opcode-condition)
              :to-equal "Illegal 6502 opcode #x02 at #xC123"))))

(describe "controller boundaries"
  (it "reads live button state while strobe is high"
    (let ((controller (make-controller)))
      (controller-set-buttons! controller +button-a+)
      (controller-write! controller 1)
      (expect (controller-read controller) :to-be 1)
      (controller-set-buttons! controller 0)
      (expect (controller-read controller) :to-be 0)
      (controller-write! controller 0)))

  (it "returns one after the serialized button stream"
    (let ((controller (make-controller)))
      (controller-set-buttons!
       controller
       (logior +button-a+ +button-right+))
      (controller-write! controller 1)
      (controller-write! controller 0)
      (loop for expected in '(1 0 0 0 0 0 0 1)
            do (expect (controller-read controller) :to-be expected))
      (expect (controller-read controller) :to-be 1))))

(describe "APU boundaries"
  (it "masks register addresses and values"
    (let ((apu (make-apu)))
      (expect (apu-write-register! apu #x14000 #x1FF) :to-be #xFF)
      (expect (apu-read-register apu #x14000) :to-be nil)))

  (it "reports active channel lengths and clears frame IRQ on status read"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4015 #x0F)
      (apu-write-register! apu #x4003 0)
      (apu-write-register! apu #x4007 0)
      (apu-write-register! apu #x400B 0)
      (apu-write-register! apu #x400F 0)
      (setf (cl-nes::apu-frame-irq-pending-p apu) t)
      (expect (logand (apu-read-register apu #x4015) #x4F) :to-be #x4F)
      (expect (apu-irq-pending-p apu) :to-be nil)))

  (it "fetches DMC bytes, wraps addresses, and loops samples"
    (let* ((addresses nil)
           (apu (make-apu
                 :memory-reader
                 (lambda (address)
                   (push address addresses)
                   #xFF)))
           (dmc (cl-nes::apu-dmc apu)))
      (apu-write-register! apu #x4010 #x80)
      (apu-write-register! apu #x4012 #xFF)
      (apu-write-register! apu #x4013 0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (length addresses) :to-be 1)
      (expect (first addresses) :to-be #xFFFF)
      (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x8000)
      (expect (apu-irq-pending-p apu) :to-be t)
      (expect (logbitp 7 (apu-read-register apu #x4015)) :to-be t)
      (apu-write-register! apu #x4010 #xC0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

  (it "delays frame mode changes and preserves console registers"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4017 #x80)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-five-step-p apu) :to-be t)
      (apu-write-register! apu #x4017 0)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 4)
      (apu-write-register! apu #x4000 #xFF)
      (apu-write-register! apu #x4002 #x34)
      (apu-write-register! apu #x4003 #x05)
      (cl-nes::apu-console-reset! apu)
      (expect (cl-nes::apu-frame-last-five-step-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (expect (cl-nes::apu-pulse-duty (cl-nes::apu-pulse-1 apu)) :to-be 3)
      (expect (cl-nes::apu-pulse-timer-period
               (cl-nes::apu-pulse-1 apu))
              :to-be #x534)
      (expect (cl-nes::apu-envelope-volume
               (cl-nes::apu-pulse-envelope (cl-nes::apu-pulse-1 apu)))
              :to-be 15))))
