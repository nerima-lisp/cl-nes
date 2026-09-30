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

(defun %cartridge-chr-offset-by-mapper (cartridge address &optional (sprite-p t))
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

(defun %cartridge-chr-offset-mapper-0 (cartridge address &optional sprite-p)
  (declare (ignore cartridge sprite-p))
  address)

(defun %cartridge-chr-offset-mapper-1 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (%mapper1-chr-offset cartridge address))

(defun %cartridge-chr-offset-mapper-3 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (+ (* (cartridge-chr-bank cartridge) +chr-bank-size+)
     (mod address +chr-bank-size+)))

(defun %cartridge-chr-offset-mapper-4 (cartridge address &optional sprite-p)
  (%mapper4-chr-offset cartridge address))

(defun %cartridge-chr-offset-mapper-5 (cartridge address &optional (sprite-p t))
  (%mapper5-chr-offset cartridge address sprite-p))

(defun %cartridge-chr-offset-mapper-9-10 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (%mapper9-10-chr-offset cartridge address))

(defun %cartridge-chr-offset-mapper-22 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (let ((slot (floor address +chr-bank-1k-size+)))
    (+ (* (ash (aref (cartridge-mapper-registers cartridge) slot) -1)
          +chr-bank-1k-size+)
       (mod address +chr-bank-1k-size+))))

(defun %cartridge-chr-offset-mapper-69 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (%mapper69-chr-offset cartridge address))

(defun %cartridge-chr-offset-mapper-66-87 (cartridge address &optional sprite-p)
  (declare (ignore sprite-p))
  (+ (* (cartridge-chr-bank cartridge) +chr-bank-size+)
     (mod address +chr-bank-size+)))

(defparameter *cartridge-chr-offset-dispatch*
  (let ((dispatch (make-array 256 :initial-element #'%cartridge-chr-offset-by-mapper)))
    (setf (aref dispatch 0) #'%cartridge-chr-offset-mapper-0
          (aref dispatch 1) #'%cartridge-chr-offset-mapper-1
          (aref dispatch 3) #'%cartridge-chr-offset-mapper-3
          (aref dispatch 4) #'%cartridge-chr-offset-mapper-4
          (aref dispatch 5) #'%cartridge-chr-offset-mapper-5
          (aref dispatch 9) #'%cartridge-chr-offset-mapper-9-10
          (aref dispatch 10) #'%cartridge-chr-offset-mapper-9-10
          (aref dispatch 11) #'%cartridge-chr-offset-mapper-3
          (aref dispatch 22) #'%cartridge-chr-offset-mapper-22
          (aref dispatch 28) #'%cartridge-chr-offset-mapper-3
          (aref dispatch 66) #'%cartridge-chr-offset-mapper-66-87
          (aref dispatch 69) #'%cartridge-chr-offset-mapper-69
          (aref dispatch 87) #'%cartridge-chr-offset-mapper-66-87)
    dispatch))

(declaim (inline %cartridge-chr-offset))

(defun %cartridge-chr-offset (cartridge address &optional (sprite-p t))
  (funcall (aref *cartridge-chr-offset-dispatch*
                (cartridge-mapper cartridge))
           cartridge address sprite-p))
