(in-package #:cl-nes/test)

(describe "Cartridge ROM size contracts"
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
    (expect-cartridge-condition
      invalid-rom
      :mapper mapper
      :prg-rom (contract-octets size)
      :chr-rom (contract-octets (contract-valid-chr-size mapper))))

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
    (expect-cartridge-condition
      invalid-rom
      :mapper mapper
      :prg-rom (contract-octets (contract-valid-prg-size mapper))
      :chr-rom (contract-octets size)))

  (it "rejects mapper 3 CHR-ROM larger than its four valid banks"
    (expect-cartridge-condition
      invalid-rom
      :mapper 3
      :prg-rom (contract-octets #x4000)
      :chr-rom (contract-octets #xA000))))
