(in-package #:cl-nes/test)

(defun %controller-model-transition (state event)
  "Apply one controller command to a pure, replayable model state."
  (let ((buttons (getf state :buttons))
        (strobe (getf state :strobe))
        (shift (getf state :shift))
        (read-count (getf state :read-count))
        (last-read (getf state :last-read)))
    (case (first event)
      (:set-buttons
       (setf buttons (logand (second event) #xFF))
       (when strobe
         (setf shift buttons
               read-count 0)))
      (:write
       (let ((new-strobe (logbitp 0 (second event))))
         (when (or new-strobe
                   (and strobe (not new-strobe)))
           (setf shift buttons
                 read-count 0))
         (setf strobe new-strobe)))
      (:read
       (setf last-read
             (if strobe
                 (logand buttons 1)
                 (if (< read-count 8)
                     (prog1 (logand shift 1)
                       (setf shift (ash shift -1)
                             read-count (1+ read-count)))
                     1))))
      (otherwise
       (error "Unknown controller model event: ~S" event)))
    (list :buttons buttons
          :strobe strobe
          :shift shift
          :read-count read-count
          :last-read last-read)))

(defun %controller-event-generator ()
  (gen-one-of
   (gen-tuple (gen-member '(:set-buttons))
              (gen-integer :min 0 :max #x1FF))
   (gen-tuple (gen-member '(:write))
              (gen-integer :min 0 :max #xFF))
   (gen-member '((:read)))))

(defun %controller-trace-has-read-p (trace)
  (member '(:read) (getf trace :events) :test #'equal))

(describe "Generated behavioral contracts"
  (it-property "controller command traces match the pure protocol model"
      ((trace
        (gen-such-that
         #'%controller-trace-has-read-p
         (gen-state-machine
          '(:buttons 0 :strobe nil :shift 0 :read-count 0 :last-read 0)
          #'%controller-model-transition
          (%controller-event-generator)
          :min-length 1
          :max-length 24))))
    (let ((controller (make-controller)))
      (with-soft-assertions
        (loop for event in (getf trace :events)
              for expected-state in (rest (getf trace :states))
              do (case (first event)
                   (:set-buttons
                    (controller-set-buttons! controller (second event)))
                   (:write
                    (controller-write! controller (second event)))
                   (:read
                    (expect (controller-read controller)
                            :to-be
                            (getf expected-state :last-read))))))))

  (it-property "controller serialization preserves every generated button mask"
      ((buttons (gen-integer :min 0 :max #xFF)))
    (let ((controller (make-controller)))
      (controller-set-buttons! controller buttons)
      (controller-write! controller 1)
      (controller-write! controller 0)
      (expect
       (loop repeat 8 collect (controller-read controller))
       :to-equal
       (loop for bit from 0 below 8
             collect (if (logbitp bit buttons) 1 0)))
      (expect (controller-read controller) :to-be 1)))

  (it-property "CHR writes preserve the low octet of generated values"
      ((value (gen-integer :min 0 :max #xFFFF)))
    (let ((cartridge (make-fixture-cartridge)))
      (cartridge-write-chr! cartridge 0 value)
      (expect (cartridge-read-chr cartridge 0) :to-be (logand value #xFF))))

  (it-property "PPU VRAM addresses wrap at the 14-bit address bus"
      ((address (gen-integer :min 0 :max #x3FFF))
       (value (gen-integer :min 0 :max #xFFFF)))
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-vram! ppu (+ address #x4000) value)
      (expect (ppu-read-vram ppu address) :to-be (logand value #xFF))))

  (it-property "NROM PRG reads always return an octet"
      ((address (gen-integer :min #x8000 :max #xFFFF)))
    (let ((cartridge (make-patterned-cartridge
                      :mapper 0
                      :prg-banks 4
                      :chr-banks 8)))
      (expect (cartridge-read-prg cartridge address)
              :to-satisfy
              (lambda (byte)
                (and (integerp byte) (<= 0 byte #xFF)))))))
