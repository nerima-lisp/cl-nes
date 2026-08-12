(in-package #:cl-nes/test)

(describe "Coverage: cartridge memory and mapper contracts"
  (it "covers PRG-RAM protection and bus cartridge routing"
    (let* ((mapper-4 (make-patterned-cartridge
                      :mapper 4 :prg-banks 8 :chr-banks 8))
           (mapper-2 (make-patterned-cartridge
                      :mapper 2 :prg-banks 8 :chr-banks 8))
           (bus (make-bus :cartridge mapper-2)))
      (cartridge-write-prg-ram! mapper-4 #x6000 #xA5)
      (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #xA5)
      (setf (cl-nes::cartridge-mapper4-prg-ram-enabled-p mapper-4) nil)
      (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be nil)
      (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
      (setf (cl-nes::cartridge-mapper4-prg-ram-enabled-p mapper-4) t
            (cl-nes::cartridge-mapper4-prg-ram-write-protected-p mapper-4) t)
      (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
      (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #xA5)
      (setf (cl-nes::cartridge-mapper4-prg-ram-write-protected-p mapper-4) nil)
      (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
      (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #x5A)
      (bus-write! bus #x8000 2)
      (expect (cartridge-read-prg (cl-nes::bus-cartridge bus) #x8000) :to-be 4)
      (expect (funcall (cl-nes::apu-memory-reader (bus-apu bus)) #x8000)
              :to-be 4))))
