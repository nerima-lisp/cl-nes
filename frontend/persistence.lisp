(in-package #:cl-nes/frontend)

(defconstant +savestate-slot-count+ 10)

(defparameter +sha256-round-constants+
  #( #x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5 #x3956c25b #x59f111f1
     #x923f82a4 #xab1c5ed5 #xd807aa98 #x12835b01 #x243185be #x550c7dc3
     #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174 #xe49b69c1 #xefbe4786
     #x0fc19dc6 #x240ca1cc #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
     #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7 #xc6e00bf3 #xd5a79147
     #x06ca6351 #x14292967 #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13
     #x650a7354 #x766a0abb #x81c2c92e #x92722c85 #xa2bfe8a1 #xa81a664b
     #xc24b8b70 #xc76c51a3 #xd192e819 #xd6990624 #xf40e3585 #x106aa070
     #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5 #x391c0cb3 #x4ed8aa4a
     #x5b9cca4f #x682e6ff3 #x748f82ee #x78a5636f #x84c87814 #x8cc70208
     #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

(defun %sha256-rotr (value count)
  (logand #xffffffff
          (logior (ash value (- count))
                  (ash (ldb (byte count 0) value) (- 32 count)))))

(defun %sha256-word (octets position)
  (logior (ash (aref octets position) 24)
          (ash (aref octets (+ position 1)) 16)
          (ash (aref octets (+ position 2)) 8)
          (aref octets (+ position 3))))

(defun %sha256-hex (octets)
  (let* ((bit-length (* 8 (length octets)))
         (padding (mod (- 56 (mod (1+ (length octets)) 64)) 64))
         (input (make-array (+ (length octets) 1 padding 8)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0))
         (state (vector #x6a09e667 #xbb67ae85 #x3c6ef372 #xa54ff53a
                        #x510e527f #x9b05688c #x1f83d9ab #x5be0cd19))
         (schedule (make-array 64 :element-type '(unsigned-byte 32))))
    (replace input octets)
    (setf (aref input (length octets)) #x80)
    (loop for index from 0 below 8
          do (setf (aref input (+ (length input) (- index 8)))
                   (ldb (byte 8 (* (- 7 index) 8)) bit-length)))
    (loop for block from 0 below (length input) by 64 do
      (loop for index below 16
            do (setf (aref schedule index) (%sha256-word input (+ block (* index 4)))))
      (loop for index from 16 below 64
            for x = (aref schedule (- index 2))
            for y = (aref schedule (- index 15))
            do (setf (aref schedule index)
                     (logand #xffffffff
                             (+ (aref schedule (- index 16))
                                (logxor (%sha256-rotr x 17) (%sha256-rotr x 19) (ash x -10))
                                (aref schedule (- index 7))
                                (logxor (%sha256-rotr y 7) (%sha256-rotr y 18) (ash y -3))))))
      (let ((a (aref state 0)) (b (aref state 1)) (c (aref state 2)) (d (aref state 3))
            (e (aref state 4)) (f (aref state 5)) (g (aref state 6)) (h (aref state 7)))
        (loop for index below 64 do
          (let* ((s1 (logxor (%sha256-rotr e 6) (%sha256-rotr e 11) (%sha256-rotr e 25)))
                 (ch (logxor (logand e f) (logand (lognot e) g)))
                 (temp1 (logand #xffffffff (+ h s1 ch (aref +sha256-round-constants+ index)
                                                   (aref schedule index))))
                 (s0 (logxor (%sha256-rotr a 2) (%sha256-rotr a 13) (%sha256-rotr a 22)))
                 (maj (logxor (logand a b) (logand a c) (logand b c)))
                 (temp2 (logand #xffffffff (+ s0 maj))))
            (setf h g g f f e e (logand #xffffffff (+ d temp1))
                  d c c b b a a (logand #xffffffff (+ temp1 temp2)))))
        (loop for index below 8
              for value in (list a b c d e f g h)
              do (setf (aref state index)
                       (logand #xffffffff (+ (aref state index) value))))))
    (with-output-to-string (stream)
      (loop for value across state do (format stream "~8,'0X" value)))))

(defun rom-identity (rom-path)
  "Return the lowercase SHA-256 identity of ROM-PATH's bytes."
  (string-downcase (%sha256-hex (restore-octets rom-path))))

(defun frontend-data-directory (&optional state-directory)
  (host-kit:ensure-directory-pathname
   (or state-directory (host-kit:user-data-directory))))

(defun rom-state-directory (rom-path &key state-directory)
  (merge-pathnames
   (make-pathname :directory (list :relative "cl-nes" (rom-identity rom-path)))
   (frontend-data-directory state-directory)))

(defun savestate-path (rom-path slot &key state-directory)
  (check-type slot (integer 0 9))
  (merge-pathnames (make-pathname :name (format nil "slot-~D" slot) :type "state")
                   (rom-state-directory rom-path :state-directory state-directory)))

(defun savestate-select-key (slot)
  (check-type slot (integer 0 9))
  (intern (format nil "~D" slot) :keyword))

(defun savestate-save-key () :f5)

(defun savestate-load-key () :f7)

(defun save-state-slot (nes rom-path slot &key state-directory)
  "Atomically save NES in SLOT for ROM-PATH and return its pathname."
  (let ((pathname (savestate-path rom-path slot :state-directory state-directory)))
    (atomic-save-octets pathname (cl-nes:nes-save-state nes))))

(defun load-state-slot (nes rom-path slot &key state-directory)
  "Load SLOT for ROM-PATH, signaling INVALID-SAVESTATE for bad contents."
  (cl-nes:nes-load-state
   nes (restore-octets (savestate-path rom-path slot :state-directory state-directory))))

(defun atomic-save-octets (pathname octets)
  "Write OCTETS atomically through cl-host-kit."
  (let ((target (pathname pathname)))
    (host-kit:ensure-directory-tree (host-kit:pathname-directory-pathname target))
    (host-kit:write-file-octets
     (if (typep octets '(vector (unsigned-byte 8)))
         octets
         (make-array (length octets)
                     :element-type '(unsigned-byte 8)
                     :initial-contents octets))
     target
     :synchronize t)))

(defun restore-octets (pathname)
  (host-kit:read-file-octets pathname))
