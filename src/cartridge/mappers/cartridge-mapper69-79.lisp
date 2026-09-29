(in-package #:cl-nes)

(defun %mapper69-prg-rom-at-6000-p (cartridge)
  (not (logbitp 6 (aref (cartridge-mapper69-registers cartridge) 8))))

(defun %mapper69-prg-ram-enabled-p (cartridge)
  (and (not (%mapper69-prg-rom-at-6000-p cartridge))
       (logbitp 7 (aref (cartridge-mapper69-registers cartridge) 8))))

(defun %mapper69-prg-ram-offset (cartridge address)
  (+ (* (mod (ldb (byte 6 0)
                  (aref (cartridge-mapper69-registers cartridge) 8))
              (floor (length (cartridge-prg-ram cartridge))
                     +prg-ram-bank-size+))
         +prg-ram-bank-size+)
     (mod (- address #x6000) +prg-ram-bank-size+)))

(defun %mapper69-prg-offset (cartridge address)
  (let* ((slot (if (< address #x8000)
                   0
                   (floor (- address #x8000) +prg-bank-8k-size+)))
         (bank-count (floor (length (cartridge-prg-rom cartridge))
                            +prg-bank-8k-size+))
         (registers (cartridge-mapper69-registers cartridge))
         (bank (if (< address #x8000)
                   (aref registers 8)
                   (case slot
                     (0 (aref registers 9))
                     (1 (aref registers 10))
                     (2 (aref registers 11))
                     (otherwise (1- bank-count))))))
    (+ (* (mod bank bank-count) +prg-bank-8k-size+)
       (mod (if (< address #x8000)
                (- address #x6000)
                (- address #x8000))
            +prg-bank-8k-size+))))

(defun %mapper69-chr-offset (cartridge address)
  (let ((bank (aref (cartridge-mapper69-registers cartridge)
                    (floor address +chr-bank-1k-size+))))
    (+ (* (mod bank (floor (length (cartridge-chr-rom cartridge))
                           +chr-bank-1k-size+))
          +chr-bank-1k-size+)
       (mod address +chr-bank-1k-size+))))

(defun %mapper69-write! (cartridge address value)
  (let ((command (cartridge-mapper69-command cartridge)))
    (cond
      ((= (logand address #xE000) #x8000)
       (setf (cartridge-mapper69-command cartridge) (logand value #x0F)))
      ((= (logand address #xE000) #xA000)
       (cond
         ((<= command 11)
          (setf (aref (cartridge-mapper69-registers cartridge) command) value))
         ((= command 12)
          (unless (cartridge-four-screen-p cartridge)
            (set-cartridge-mirroring!
             cartridge
             (case (logand value #x03)
               (0 :vertical)
               (1 :horizontal)
               (2 :single-screen-lower)
               (otherwise :single-screen-upper)))))
         ((= command 13)
          (setf (cartridge-mapper69-irq-counter cartridge)
                (dpb value (byte 8 8) (cartridge-mapper69-irq-counter cartridge))))
         ((= command 14)
          (setf (cartridge-mapper69-irq-counter cartridge)
                (dpb value (byte 8 0) (cartridge-mapper69-irq-counter cartridge))))
         ((= command 15)
          (setf (cartridge-mapper69-irq-enabled-p cartridge) (logbitp 0 value)))))
      ((= (logand address #xE000) #xC000)
       (setf (cartridge-mapper69-command cartridge) (logand value #x0F))))
  value))

(defun cartridge-clock-cpu! (cartridge cycles)
  (when (and cartridge (= (cartridge-mapper cartridge) 69)
             (cartridge-mapper69-irq-enabled-p cartridge))
    (let ((counter (cartridge-mapper69-irq-counter cartridge)))
      (if (> cycles counter)
          (progn
            (setf (cartridge-mapper69-irq-counter cartridge) 0
                  (cartridge-mapper69-irq-pending-p cartridge) t))
          (decf (cartridge-mapper69-irq-counter cartridge) cycles))))
  cartridge)

(defun %mapper79-prg-offset (cartridge address)
  (%banked-32k-prg-offset cartridge address))

(defun %mapper79-write! (cartridge value)
  (set-cartridge-prg-bank! cartridge
                           (mod (logand value #x07)
                                (floor (length (cartridge-prg-rom cartridge))
                                       (* 2 +prg-bank-size+))))
  (set-cartridge-chr-bank! cartridge
                           (mod (ash value -4)
                                (floor (length (cartridge-chr-rom cartridge))
                                       +chr-bank-size+)))
  value)
