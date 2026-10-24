(in-package #:cl-nes)

(defun %mapper30-prg-offset (cartridge address)
  (let* ((bank-count (floor (length (cartridge-prg-rom cartridge))
                            +prg-bank-size+))
         (offset (- address #x8000)))
    (if (< offset +prg-bank-size+)
        (+ (* (mod (cartridge-prg-bank cartridge) bank-count)
              +prg-bank-size+)
           offset)
        (+ (* (1- bank-count) +prg-bank-size+)
           (- offset +prg-bank-size+)))))

(defun %mapper30-chr-offset (cartridge address)
  (+ (* (mod (cartridge-chr-bank cartridge)
             (floor (length (cartridge-chr-rom cartridge)) +chr-bank-size+))
        +chr-bank-size+)
     (mod address +chr-bank-size+)))

(defun %mapper30-write! (cartridge address value)
  ;; All supported submappers latch at $C000-$FFFF. Submapper 2 and submapper 0
  ;; without battery-backed flash also latch at $8000-$BFFF.
  (let* ((submapper (cartridge-submapper cartridge))
         (register-write-p
           (and (<= #x8000 address #xFFFF)
                (or (= submapper 2)
                    (and (= submapper 0)
                         (not (cartridge-battery-backed-p cartridge)))
                    (>= address #xC000)))))
    ;; Battery-backed PRG flash stays immutable because this cartridge model has no
    ;; flash command or persistence state.
    (when register-write-p
      (let ((prg-bank-count (floor (length (cartridge-prg-rom cartridge))
                                   +prg-bank-size+))
            (chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                                   +chr-bank-size+)))
        (set-cartridge-prg-bank! cartridge
                                 (mod (logand value #x1F) prg-bank-count))
        (set-cartridge-chr-bank! cartridge
                                 (mod (ldb (byte 2 5) value) chr-bank-count))
        ;; Register bit 7 (N) selects horizontal/vertical mirroring on submapper 3.
        ;; Submappers 0, 1, 2, and 4 apply N only for one-screen header mirroring.
        (cond
          ((= submapper 3)
           (set-cartridge-mirroring!
            cartridge
            (if (logbitp 7 value) :vertical :horizontal)))
          ((and (or (= submapper 0)
                    (= submapper 1)
                    (= submapper 2)
                    (= submapper 4))
                (or (eq (cartridge-initial-mirroring cartridge)
                        :single-screen-lower)
                    (eq (cartridge-initial-mirroring cartridge)
                        :single-screen-upper)))
           (set-cartridge-mirroring!
            cartridge
            (if (logbitp 7 value)
                :single-screen-upper
                :single-screen-lower)))))
    value)))
