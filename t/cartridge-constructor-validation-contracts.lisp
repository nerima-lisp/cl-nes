(in-package #:cl-nes/test)

(defparameter +contract-prg-specs+
  '((0 #x4000)
    (1 #x4000)
    (2 #x8000)
    (3 #x4000)
    (4 #x4000)
    (5 #x4000)
    (7 #x4000)
    (11 #x8000)
    (22 #x4000)
    (28 #x4000)
    (34 #x8000)))

(defparameter +contract-chr-specs+
  '((0 #x2000)
    (1 #x2000)
    (2 #x2000)
    (3 #x2000)
    (4 #x0400)
    (5 #x0400)
    (7 #x2000)
    (11 #x2000)
    (22 #x0400)
    (28 #x2000)
    (34 #x2000)))

(defun constructor-condition (&rest initargs)
  (captured-condition
   (lambda ()
     (apply #'make-cartridge initargs))))

(defun invalid-prg-condition (mapper size)
  (constructor-condition
   :mapper mapper
   :prg-rom (contract-octets size)
   :chr-rom (contract-octets (contract-valid-chr-size mapper))))

(defun invalid-chr-condition (mapper size)
  (constructor-condition
   :mapper mapper
   :prg-rom (contract-octets (contract-valid-prg-size mapper))
   :chr-rom (contract-octets size)))

(defun validate-storage-condition (mapper size specs)
  (captured-condition
   (lambda ()
     (cl-nes::%validate-storage-size! mapper size specs))))

(defun expect-storage-spec-contract (mapper minimum specs minimum-size-fn validator)
  (let ((spec (cl-nes::%find-storage-validation-spec mapper specs)))
    (expect (first spec) :to-be mapper)
    (expect (cl-nes::%storage-validation-spec-minimum-size spec)
            :to-be minimum)
    (expect (funcall minimum-size-fn mapper) :to-be minimum)
    (expect (captured-condition
             (lambda ()
               (funcall validator mapper (contract-octets minimum))))
            :to-be nil)))

(describe "Cartridge constructor validation contracts"
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
    (let ((condition (invalid-prg-condition mapper size)))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it-each ((0 #x0400)
            (1 #x1000)
            (2 #x0400)
            (3 #x1000)
            (4 0)
            (5 0)
            (7 #x0400)
            (11 #x1000)
            (22 0)
            (28 #x1000)
            (34 #x0400))
    "rejects an invalid CHR size for mapper ~D"
    (mapper size)
    (let ((condition (invalid-chr-condition mapper size)))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it-each ((0) (1) (2) (3) (4) (5) (7) (11) (22) (28) (34))
    "accepts the supported storage shape for mapper ~D"
    (mapper)
    (let ((cartridge (make-contract-cartridge mapper)))
      (expect (cartridge-mapper cartridge) :to-be mapper)))

  (it "rejects unsupported mapper and malformed constructor options"
    (let ((unsupported
            (constructor-condition
             :mapper 6
             :prg-rom (contract-octets #x4000)))
          (variant
            (constructor-condition
             :mapper 0
             :mapper4-variant :unknown
             :prg-rom (contract-octets #x4000)))
          (negative-ram
            (constructor-condition
             :mapper 0
             :prg-ram-size -1
             :prg-rom (contract-octets #x4000)))
          (fractional-ram
            (constructor-condition
             :mapper 0
             :prg-ram-size 1.5
             :prg-rom (contract-octets #x4000))))
      (expect (typep unsupported 'unsupported-mapper) :to-be t)
      (expect (typep variant 'invalid-rom) :to-be t)
      (expect (typep negative-ram 'invalid-rom) :to-be t)
      (expect (typep fractional-ram 'invalid-rom) :to-be t)))

  (it "reports mapper-specific invalid-rom reasons for PRG size errors"
    (let ((nrom
            (constructor-condition
             :mapper 0
             :prg-rom (contract-octets #x2000)
             :chr-rom (contract-octets (contract-valid-chr-size 0))))
          (vrc2
            (constructor-condition
             :mapper 22
             :prg-rom (contract-octets #x2000)
             :chr-rom (contract-octets (contract-valid-chr-size 22))))
          (action53
            (constructor-condition
             :mapper 28
             :prg-rom (contract-octets #x1000)
             :chr-rom (contract-octets (contract-valid-chr-size 28)))))
      (expect (invalid-rom-reason nrom)
              :to-equal "NROM PRG data must be 16 KiB, 32 KiB, or 48 KiB")
      (expect (invalid-rom-reason vrc2)
              :to-equal "VRC2 PRG data must use 8 KiB units")
      (expect (invalid-rom-reason action53)
              :to-equal "Action 53 PRG data must use 16 KiB units")))

  (it "reports the shared invalid-rom reason for CHR size errors"
    (let ((condition
            (constructor-condition
             :mapper 4
             :prg-rom (contract-octets (contract-valid-prg-size 4))
             :chr-rom (contract-octets 0))))
      (expect (invalid-rom-reason condition)
              :to-equal "CHR storage size is not supported by this mapper")))

  (it "covers constructor validation helpers and minimum-size contracts"
    (expect (cl-nes::%size-one-of-p #x4000 #x4000 #x8000)
            :to-equal '(#x4000 #x8000))
    (expect (cl-nes::%size-one-of-p #x2000 #x4000 #x8000) :to-be nil)
    (expect (cl-nes::%banked-size-p #x4000 #x4000 #x2000) :to-be t)
    (expect (cl-nes::%banked-size-p #x2000 #x4000 #x2000) :to-be nil)
    (expect (cl-nes::%banked-size-p #x5000 #x4000 #x2000) :to-be nil)
    (expect (cl-nes::%exact-size-p #x2000 #x2000) :to-be t)
    (expect (cl-nes::%exact-size-p #x1000 #x2000) :to-be nil)
    (expect (contract-valid-prg-size 0) :to-be #x4000)
    (expect (contract-valid-prg-size 28) :to-be #x4000)
    (expect (contract-valid-chr-size 4) :to-be #x400)
    (expect (contract-valid-chr-size 28) :to-be #x2000))

  (it "validates storage specs through the internal validator entry point"
    (let ((valid-prg
            (validate-storage-condition
             1 #x4000 cl-nes::+prg-storage-validation-specs+))
          (short-prg
            (validate-storage-condition
             1 #x2000 cl-nes::+prg-storage-validation-specs+))
          (misaligned-prg
            (validate-storage-condition
             22 #x5000 cl-nes::+prg-storage-validation-specs+))
          (valid-chr
            (validate-storage-condition
             4 #x0400 cl-nes::+chr-storage-validation-specs+))
          (misaligned-chr
            (validate-storage-condition
             4 #x0401 cl-nes::+chr-storage-validation-specs+)))
      (expect valid-prg :to-be nil)
      (expect (typep short-prg 'invalid-rom) :to-be t)
      (expect (typep misaligned-prg 'invalid-rom) :to-be t)
      (expect valid-chr :to-be nil)
      (expect (typep misaligned-chr 'invalid-rom) :to-be t)))

  (it "covers internal storage spec helpers across supported mappers"
    (let ()
      (expect (length cl-nes::+supported-mappers+) :to-be 11)
      (expect (find 28 cl-nes::+supported-mappers+) :to-be 28)
      (expect (length cl-nes::+supported-mapper4-variants+) :to-be 3)
      (expect (find :mmc6 cl-nes::+supported-mapper4-variants+) :to-be :mmc6)
      (dolist (entry +contract-prg-specs+)
        (destructuring-bind (mapper minimum) entry
          (expect-storage-spec-contract
           mapper minimum
           cl-nes::+prg-storage-validation-specs+
           #'cl-nes::%minimum-valid-prg-storage-size
           #'cl-nes::%validate-prg-storage!)))
      (dolist (entry +contract-chr-specs+)
        (destructuring-bind (mapper minimum) entry
          (expect-storage-spec-contract
           mapper minimum
           cl-nes::+chr-storage-validation-specs+
           #'cl-nes::%minimum-valid-chr-storage-size
           #'cl-nes::%validate-chr-storage!)))
      (let ((missing-prg-spec
              (captured-condition
               (lambda ()
                 (cl-nes::%find-storage-validation-spec
                  999 cl-nes::+prg-storage-validation-specs+))))
            (missing-chr-spec
              (captured-condition
               (lambda ()
                 (cl-nes::%find-storage-validation-spec
                  999 cl-nes::+chr-storage-validation-specs+)))))
        (expect (typep missing-prg-spec 'simple-error) :to-be t)
        (expect (typep missing-chr-spec 'simple-error) :to-be t))))

  (it "covers direct validation helper branches"
    (let ((supported
            (captured-condition
             (lambda ()
               (cl-nes::%ensure-cartridge-options! 4 :mmc6 0))))
          (invalid-variant
            (captured-condition
             (lambda ()
               (cl-nes::%ensure-cartridge-options! 4 :bad 0))))
          (negative-ram
            (captured-condition
             (lambda ()
               (cl-nes::%ensure-cartridge-options! 4 :mmc3 -1))))
          (unsupported
            (captured-condition
             (lambda ()
               (cl-nes::%ensure-cartridge-options! 99 :mmc3 0)))))
      (expect supported :to-be nil)
      (expect (typep invalid-variant 'invalid-rom) :to-be t)
      (expect (typep negative-ram 'invalid-rom) :to-be t)
      (expect (typep unsupported 'unsupported-mapper) :to-be t))))
