(in-package #:cl-nes/test)

(defun contract-octets (size)
  (make-array size
              :element-type '(unsigned-byte 8)
              :initial-element 0))

(defun contract-condition (thunk)
  (handler-case (progn (funcall thunk) nil)
    (condition (condition) condition)))

(defun contract-valid-prg-size (mapper)
  (case mapper
    ((0 1 3 7 28) #x4000)
    ((2 4 5 22) #x8000)
    ((11 34) #x8000)))

(defun contract-valid-chr-size (mapper)
  (case mapper
    (22 #x400)
    ((4 5) #x400)
    ((1 3 11 28) #x2000)
    (otherwise #x2000)))

(defun make-contract-cartridge (mapper)
  (make-cartridge
   :mapper mapper
   :prg-rom (contract-octets (contract-valid-prg-size mapper))
   :chr-rom (contract-octets (contract-valid-chr-size mapper))))

(defun make-cartridge-condition (&rest initargs)
  (contract-condition
   (lambda ()
     (apply #'make-cartridge initargs))))

(defmacro expect-cartridge-condition (condition-type &body initargs)
  `(let ((condition
           (make-cartridge-condition ,@initargs)))
     (expect (typep condition ',condition-type) :to-be t)))
