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

(describe "Cartridge construction contracts"
  (it-each ((0 #x2000)
            (1 #x2000)
            (2 #x4000)
            (3 #x2000)
            (4 #x1000)
            (5 #x1000)
            (7 #x2000)
            (7 0)
            (11 #x4000)
            (22 #x2000)
            (28 #x1000)
            (28 0)
            (34 #x4000))
    "rejects an invalid PRG size for mapper ~D"
    (mapper size)
    (let ((condition
            (contract-condition
             (lambda ()
               (make-cartridge
                :mapper mapper
                :prg-rom (contract-octets size)
                :chr-rom (contract-octets (contract-valid-chr-size mapper)))))))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it-each ((0 #x400)
            (1 #x1000)
            (2 #x400)
            (3 #x1000)
            (4 0)
            (5 0)
            (7 #x400)
            (11 #x1000)
            (22 0)
            (28 #x1000)
            (34 #x400))
    "rejects an invalid CHR size for mapper ~D"
    (mapper size)
    (let ((condition
            (contract-condition
             (lambda ()
               (make-cartridge
                :mapper mapper
                :prg-rom (contract-octets (contract-valid-prg-size mapper))
                :chr-rom (contract-octets size))))))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it-each ((0) (1) (2) (3) (4) (5) (7) (11) (22) (28) (34))
    "accepts the supported storage shape for mapper ~D"
    (mapper)
    (let ((cartridge (make-contract-cartridge mapper)))
      (expect (cartridge-mapper cartridge) :to-be mapper)))

  (it "rejects unsupported mapper and malformed constructor options"
    (let ((unsupported
            (contract-condition
             (lambda ()
               (make-cartridge :mapper 6
                               :prg-rom (contract-octets #x4000)))))
          (variant
            (contract-condition
             (lambda ()
               (make-cartridge :mapper 0
                               :mapper4-variant :unknown
                               :prg-rom (contract-octets #x4000)))))
          (negative-ram
            (contract-condition
             (lambda ()
               (make-cartridge :mapper 0
                               :prg-ram-size -1
                               :prg-rom (contract-octets #x4000)))))
          (fractional-ram
            (contract-condition
             (lambda ()
               (make-cartridge :mapper 0
                               :prg-ram-size 1.5
                               :prg-rom (contract-octets #x4000))))))
      (expect (typep unsupported 'unsupported-mapper) :to-be t)
      (expect (typep variant 'invalid-rom) :to-be t)
      (expect (typep negative-ram 'invalid-rom) :to-be t)
      (expect (typep fractional-ram 'invalid-rom) :to-be t)))

  (it "uses the mapper 28 CHR default and keeps RAM across reset"
    (let ((cartridge
            (make-cartridge :mapper 28
                            :mirroring :vertical
                            :prg-rom (contract-octets #x4000)
                            :prg-ram-size #x2000)))
      (expect (length (cartridge-chr-rom cartridge)) :to-be (* 4 #x2000))
      (setf (aref (cartridge-prg-ram cartridge) 0) #xA5
            (cl-nes::cartridge-mapper-mode cartridge) #x02)
      (cartridge-reset! cartridge)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0E)))

  (it "initializes mapper 28 mode for horizontal mirroring"
    (let ((cartridge
            (make-cartridge :mapper 28
                            :mirroring :horizontal
                            :prg-rom (contract-octets #x4000))))
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0F)
      (cartridge-reset! cartridge)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0F)))

  (it "restores mapper 5 bank defaults without clearing RAM"
    (let ((cartridge (make-patterned-cartridge :mapper 5
                                               :prg-banks 4
                                               :chr-banks 8)))
      (setf (aref (cartridge-prg-ram cartridge) 0) #x5A
            (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 0) #x7F)
      (cartridge-reset! cartridge)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #x5A)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 0) :to-be 0)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 4) :to-be #x80))))

  (it "keeps AxROM bank and mirroring writes explicit"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 7 :prg-banks 4 :chr-banks 8)))
      (cartridge-write-prg! cartridge #x8000 #x1A)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 2)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (cartridge-write-prg! cartridge #x8000 #x02)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "maps VRC2 mirroring and split CHR registers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 22 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #x9000 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (cartridge-write-prg! cartridge #x9000 1)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (cartridge-write-prg! cartridge #xB000 #x05)
      (cartridge-write-prg! cartridge #xB002 #x0A)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 0)
              :to-be #xA5)
      (cartridge-write-prg! cartridge #xF000 #xFF)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 0)
              :to-be #xA5)))

  (it "bounds PRG-RAM and CHR memory windows"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 0 :prg-banks 2 :chr-banks 8
                      :prg-ram-size #x2000)))
      (expect (cartridge-read-prg cartridge #x7FFF) :to-be nil)
      (cartridge-write-prg-ram! cartridge #x6000 #x1FF)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xFF)
      (expect (cartridge-read-prg-ram cartridge #x5FFF) :to-be nil)
      (expect (cartridge-read-prg-ram cartridge #x8000) :to-be nil)
      (expect (cartridge-write-prg-ram! cartridge #x8000 #x42) :to-be #x42))
    (let ((empty (make-patterned-cartridge
                  :mapper 0 :prg-banks 2 :chr-banks 8
                  :prg-ram-size 0)))
      (expect (cartridge-read-prg-ram empty #x6000) :to-be nil)
      (expect (cartridge-write-prg-ram! empty #x6000 #x42) :to-be #x42))
    (let ((read-only (make-patterned-cartridge
                      :mapper 0 :prg-banks 2 :chr-banks 8)))
      (expect (cartridge-write-chr! read-only 0 #xA5) :to-be #xA5)
      (expect (cartridge-read-chr read-only 0) :to-be 0))
    (let ((writable (make-fixture-cartridge)))
      (expect (cartridge-write-chr! writable 0 #x1FF) :to-be #x1FF)
      (expect (cartridge-read-chr writable 0) :to-be #xFF)
      (expect (cartridge-read-chr writable #x2000) :to-be nil)
      (expect (cartridge-write-chr! writable #x2000 #x77) :to-be #x77)))
