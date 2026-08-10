(in-package #:cl-nes)

(defun %octet-vector (sequence)
  (let ((result (make-array (length sequence)
                            :element-type '(unsigned-byte 8))))
    (replace result sequence)
    result))

(defun make-cartridge (&key prg-rom chr-rom (mapper 0) (mirroring :horizontal)
                            battery-backed-p four-screen-p
                            (chr-writable-p (null chr-rom))
                            (prg-ram-size +prg-ram-bank-size+)
                            (mapper4-variant :mmc3))
  (unless (member mapper '(0 1 2 3 4 5 7 11 22 28 34))
    (error 'unsupported-mapper :number mapper))
  (unless (member mapper4-variant '(:mmc3 :mmc6))
    (error 'invalid-rom
           :reason "MMC3 variant must be :MMC3 or :MMC6"))
  (unless (and (integerp prg-ram-size) (>= prg-ram-size 0))
    (error 'invalid-rom :reason "PRG-RAM size must be a non-negative integer"))
  (let ((prg (%octet-vector prg-rom))
        (chr (%octet-vector (or chr-rom (make-array (if (= mapper 28)
                                                        (* 4 +chr-bank-size+)
                                                        +chr-bank-size+)
                                                    :element-type '(unsigned-byte 8)
                                                    :initial-element 0))))
        (prg-ram (make-array prg-ram-size
                             :element-type '(unsigned-byte 8)
                             :initial-element 0))
        (mapper4-registers (make-array 8
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-prg-banks (make-array 8
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-chr-banks (make-array 12
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-exram (make-array #x400
                                   :element-type '(unsigned-byte 8)
                                   :initial-element 0)))
    (when (= mapper 28)
      (unless (and (plusp (length prg))
                   (zerop (mod (length prg) +prg-bank-size+)))
        (error 'invalid-rom :reason "Action 53 PRG data must use 16 KiB units")))
    (cond
      ((= mapper 0)
       (unless (member (length prg)
                       (list (* 16 1024) (* 32 1024) (* 48 1024)))
         (error 'invalid-rom
                :reason "NROM PRG data must be 16 KiB, 32 KiB, or 48 KiB")))
      ((= mapper 2)
       (unless (and (>= (length prg) (* 32 1024))
                    (zerop (mod (length prg) +prg-bank-size+)))
         (error 'invalid-rom
                :reason "UxROM PRG data must have at least two 16 KiB banks")))
      ((= mapper 1)
       (unless (and (>= (length prg) (* 16 1024))
                    (zerop (mod (length prg) +prg-bank-size+)))
         (error 'invalid-rom
                :reason "MMC1 PRG data must use 16 KiB banks")))
      ((= mapper 3)
       (unless (member (length prg) (list (* 16 1024) (* 32 1024)))
         (error 'invalid-rom :reason "CNROM PRG data must be 16 KiB or 32 KiB")))
      ((= mapper 7)
       (unless (and (plusp (length prg))
                    (zerop (mod (length prg) +prg-bank-size+)))
         (error 'invalid-rom :reason "AxROM PRG data must use 16 KiB units")))
      ((member mapper '(11 34))
       (unless (and (>= (length prg) (* 32 1024))
                    (zerop (mod (length prg) (* 32 1024))))
         (error 'invalid-rom :reason "32 KiB banked PRG data is required")))
      ((= mapper 22)
       (unless (and (>= (length prg) +prg-bank-size+)
                    (zerop (mod (length prg) +prg-bank-8k-size+)))
         (error 'invalid-rom :reason "VRC2 PRG data must use 8 KiB units")))
      ((member mapper '(4 5))
       (unless (and (>= (length prg) (* 2 +prg-bank-8k-size+))
                    (zerop (mod (length prg) +prg-bank-8k-size+)))
         (error 'invalid-rom
                :reason "MMC3/MMC5 PRG data must have at least two 8 KiB banks"))))
    (when (= mapper 5)
      (setf (aref mapper5-prg-banks 4) #x80
            (aref mapper5-prg-banks 5) #x80
            (aref mapper5-prg-banks 6) #x80
            (aref mapper5-prg-banks 7)
            (logior #x80
                    (1- (floor (length prg) +prg-bank-8k-size+)))))
  (unless (case mapper
            (22 (and (plusp (length chr))
                     (zerop (mod (length chr) +chr-bank-1k-size+))))
            ((1 3 11 28) (and (>= (length chr) +chr-bank-size+)
                              (zerop (mod (length chr) +chr-bank-size+))))
            ((4 5) (and (plusp (length chr))
                        (zerop (mod (length chr) +chr-bank-1k-size+))))
            (otherwise (= (length chr) +chr-bank-size+)))
      (error 'invalid-rom
             :reason "CHR storage size is not supported by this mapper"))
    (%make-cartridge :prg-rom prg
                     :chr-rom chr
                     :prg-ram prg-ram
                     :mapper mapper
                     :mirroring mirroring
                     :initial-mirroring mirroring
                     :battery-backed-p battery-backed-p
                     :four-screen-p four-screen-p
                     :chr-writable-p chr-writable-p
                     :prg-bank 0
                     :chr-bank 0
                     :mapper-shift #x10
                     :mapper-control #x0C
                     :mapper-chr-bank-0 0
                     :mapper-chr-bank-1 0
                     :mapper-prg-bank-1 0
                     :mapper-registers (make-array 8
                                                   :element-type '(unsigned-byte 8)
                                                   :initial-element 0)
                     :mapper-register-select 0
                     :mapper-mode (if (= mapper 28)
                                      (if (eq mirroring :vertical) #x0E #x0F)
                                      0)
                     :mapper-outer-bank #xFF
                     :mapper4-bank-select 0
                     :mapper4-registers mapper4-registers
                     :mapper4-variant mapper4-variant
                     :mapper4-prg-ram-enabled-p t
                     :mapper4-prg-ram-write-protected-p nil
                     :mapper4-irq-latch 0
                     :mapper4-irq-counter 0
                     :mapper4-irq-reload-p nil
                     :mapper4-irq-enabled-p nil
                     :mapper4-irq-pending-p nil
                     :mapper4-ppu-a12-high-p nil
                     :mapper4-ppu-a12-low-cycles 0
                     :mapper5-prg-mode 3
                     :mapper5-chr-mode 3
                     :mapper5-prg-banks mapper5-prg-banks
                     :mapper5-chr-banks mapper5-chr-banks
                     :mapper5-prg-ram-protect-1 0
                     :mapper5-prg-ram-protect-2 0
                     :mapper5-exram-mode 0
                     :mapper5-nametable-mapping 0
                     :mapper5-fill-tile 0
                     :mapper5-fill-attribute 0
                     :mapper5-split-control 0
                     :mapper5-split-scroll 0
                     :mapper5-split-bank 0
                     :mapper5-irq-scanline 0
                     :mapper5-irq-enabled-p nil
                     :mapper5-irq-pending-p nil
                     :mapper5-in-frame-p nil
                     :mapper5-multiplier-a 0
                     :mapper5-multiplier-b 0
                     :mapper5-exram mapper5-exram)))

(defun %reset-mapper5-prg-banks! (cartridge)
  (let ((banks (cartridge-mapper5-prg-banks cartridge)))
    (fill banks 0)
    (setf (aref banks 4) #x80
          (aref banks 5) #x80
          (aref banks 6) #x80
          (aref banks 7)
          (logior #x80
                  (1- (floor (length (cartridge-prg-rom cartridge))
                             +prg-bank-8k-size+))))))

(defun cartridge-reset! (cartridge)
  "Reset mapper registers while retaining cartridge-backed RAM contents."
  (let ((mapper (cartridge-mapper cartridge)))
    (setf (cartridge-mirroring cartridge)
          (cartridge-initial-mirroring cartridge)
          (cartridge-prg-bank cartridge) 0
          (cartridge-chr-bank cartridge) 0
          (cartridge-mapper-shift cartridge) #x10
          (cartridge-mapper-control cartridge) #x0C
          (cartridge-mapper-chr-bank-0 cartridge) 0
          (cartridge-mapper-chr-bank-1 cartridge) 0
          (cartridge-mapper-prg-bank-1 cartridge) 0
          (cartridge-mapper-register-select cartridge) 0
          (cartridge-mapper-mode cartridge)
          (if (= mapper 28)
              (if (eq (cartridge-initial-mirroring cartridge) :vertical)
                  #x0E
                  #x0F)
              0)
          (cartridge-mapper-outer-bank cartridge) #xFF
          (cartridge-mapper4-bank-select cartridge) 0
          (cartridge-mapper4-prg-ram-enabled-p cartridge) t
          (cartridge-mapper4-prg-ram-write-protected-p cartridge) nil
          (cartridge-mapper4-irq-latch cartridge) 0
          (cartridge-mapper4-irq-counter cartridge) 0
          (cartridge-mapper4-irq-reload-p cartridge) nil
          (cartridge-mapper4-irq-enabled-p cartridge) nil
          (cartridge-mapper4-irq-pending-p cartridge) nil
          (cartridge-mapper4-ppu-a12-high-p cartridge) nil
          (cartridge-mapper4-ppu-a12-low-cycles cartridge) 0
          (cartridge-mapper5-prg-mode cartridge) 3
          (cartridge-mapper5-chr-mode cartridge) 3
          (cartridge-mapper5-prg-ram-protect-1 cartridge) 0
          (cartridge-mapper5-prg-ram-protect-2 cartridge) 0
          (cartridge-mapper5-exram-mode cartridge) 0
          (cartridge-mapper5-nametable-mapping cartridge) 0
          (cartridge-mapper5-fill-tile cartridge) 0
          (cartridge-mapper5-fill-attribute cartridge) 0
          (cartridge-mapper5-split-control cartridge) 0
          (cartridge-mapper5-split-scroll cartridge) 0
          (cartridge-mapper5-split-bank cartridge) 0
          (cartridge-mapper5-irq-scanline cartridge) 0
          (cartridge-mapper5-irq-enabled-p cartridge) nil
          (cartridge-mapper5-irq-pending-p cartridge) nil
          (cartridge-mapper5-in-frame-p cartridge) nil
          (cartridge-mapper5-multiplier-a cartridge) 0
          (cartridge-mapper5-multiplier-b cartridge) 0)
    (fill (cartridge-mapper-registers cartridge) 0)
    (fill (cartridge-mapper4-registers cartridge) 0)
    (fill (cartridge-mapper5-chr-banks cartridge) 0)
    (when (= mapper 5)
      (%reset-mapper5-prg-banks! cartridge)))
  cartridge)
