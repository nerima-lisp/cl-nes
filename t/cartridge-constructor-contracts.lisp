(in-package #:cl-nes/test)

(describe "Cartridge constructor contracts"
  (it-each ((0) (1) (2) (3) (4) (5) (7) (11) (22) (28) (34))
    "accepts the supported storage shape for mapper ~D"
    (mapper)
    (let ((cartridge (make-contract-cartridge mapper)))
      (expect (cartridge-mapper cartridge) :to-be mapper)))

  (it-each ((unsupported-mapper
              :mapper 6
              :prg-rom (contract-octets #x4000))
            (invalid-rom
              :mapper 0
              :mapper4-variant :unknown
              :prg-rom (contract-octets #x4000))
            (invalid-rom
              :mapper 0
              :prg-ram-size -1
              :prg-rom (contract-octets #x4000))
            (invalid-rom
              :mapper 0
              :prg-ram-size 1.5
              :prg-rom (contract-octets #x4000)))
    "rejects malformed constructor options as ~A"
    (condition-type &rest initargs)
    (let ((condition (apply #'make-cartridge-condition initargs)))
      (expect (typep condition condition-type) :to-be t))))
