(in-package #:cl-nes)

(defun %cartridge-chr-offset (cartridge address &optional (sprite-p t))
  (case (cartridge-mapper cartridge)
    (1 (%mapper1-chr-offset cartridge address))
    ((3 11 28)
     (+ (* (cartridge-chr-bank cartridge) +chr-bank-size+)
        (mod address +chr-bank-size+)))
    (22
     (let ((slot (floor address +chr-bank-1k-size+)))
       (+ (* (ash (aref (cartridge-mapper-registers cartridge) slot) -1)
             +chr-bank-1k-size+)
          (mod address +chr-bank-1k-size+))))
    (4 (%mapper4-chr-offset cartridge address))
    (5 (%mapper5-chr-offset cartridge address sprite-p))
    (otherwise address)))

(defun %cartridge-nametable-index (cartridge address)
  (let* ((offset (- address #x2000))
         (table (floor offset #x400))
         (within (mod offset #x400))
         (mirrored-table
           (cond
             ((and cartridge
                   (cartridge-four-screen-p cartridge))
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

(defun %cartridge-read-mapper5-nametable (cartridge nametable address)
  (%with-mmc5-nametable-location (source within cartridge address)
    (case source
      (:ciram-0 (aref nametable within))
      (:ciram-1 (aref nametable (+ #x400 within)))
      (:exram (cartridge-mmc5-read-exram cartridge within))
      (:fill (cartridge-mmc5-fill-value cartridge within)))))

(defun %cartridge-write-mapper5-nametable! (cartridge nametable address value)
  (%with-mmc5-nametable-location (source within cartridge address)
    (case source
      (:ciram-0 (setf (aref nametable within) value))
      (:ciram-1 (setf (aref nametable (+ #x400 within)) value))
      (:exram (cartridge-mmc5-write-exram! cartridge within value))
      (:fill nil)))
  value)
