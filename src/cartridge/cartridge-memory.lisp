(in-package #:cl-nes)

(defun cartridge-prg-size (cartridge)
  (length (cartridge-prg-rom cartridge)))

(defun cartridge-chr-size (cartridge)
  (length (cartridge-chr-rom cartridge)))

(defun %nrom-368-p (cartridge)
  (and (= (cartridge-mapper cartridge) 0)
       (= (length (cartridge-prg-rom cartridge)) (* 48 1024))))

(defun %mirrored-nametable-index (cartridge address)
  (let* ((offset (mod (- address #x2000) #x1000))
         (table (floor offset #x400))
         (within (mod offset #x400))
         (mirrored-table
           (cond
             ((and cartridge (cartridge-four-screen-p cartridge))
              table)
             ((and cartridge
                   (eq (cartridge-mirroring cartridge)
                       :single-screen-upper))
              1)
             ((and cartridge
                   (eq (cartridge-mirroring cartridge)
                       :single-screen-lower))
              0)
             ((and cartridge
                   (eq (cartridge-mirroring cartridge) :vertical))
              (mod table 2))
             (t (floor table 2)))))
    (+ (* mirrored-table #x400) within)))

(defun %cartridge-chr-offset (cartridge address &optional (sprite-p t))
  (case (cartridge-mapper cartridge)
    (1 (%mapper1-chr-offset cartridge address))
    ((3 11 28)
     (+ (* (cartridge-chr-bank cartridge) +chr-bank-size+)
        (mod address +chr-bank-size+)))
    ((66 87)
     (+ (* (cartridge-chr-bank cartridge) +chr-bank-size+)
        (mod address +chr-bank-size+)))
    (69 (%mapper69-chr-offset cartridge address))
    (22
     (let ((slot (floor address +chr-bank-1k-size+)))
       (+ (* (ash (aref (cartridge-mapper-registers cartridge) slot) -1)
             +chr-bank-1k-size+)
          (mod address +chr-bank-1k-size+))))
    ((9 10) (%mapper9-10-chr-offset cartridge address))
    (4 (%mapper4-chr-offset cartridge address))
    (5 (%mapper5-chr-offset cartridge address sprite-p))
    (otherwise address)))
