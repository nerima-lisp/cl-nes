(in-package #:cl-nes/test)

(defun mapper69-write-command! (cartridge command value)
  (cartridge-write-prg! cartridge #x8000 command)
  (cartridge-write-prg! cartridge #xA000 value))

(describe "Mapper 69 contracts"
  (it "maps registers 8 through 11 to the four switchable PRG windows"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 69
                      :prg-banks 16
                      :chr-banks 8)))
      (mapper69-write-command! cartridge 8 2)
      (mapper69-write-command! cartridge 9 3)
      (mapper69-write-command! cartridge 10 4)
      (mapper69-write-command! cartridge 11 5)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be 2)
      (expect (cl-nes::cartridge-cpu-read cartridge #x8000) :to-be 3)
      (expect (cl-nes::cartridge-cpu-read cartridge #xA000) :to-be 4)
      (expect (cl-nes::cartridge-cpu-read cartridge #xC000) :to-be 5)
      (expect (cl-nes::cartridge-cpu-read cartridge #xE000) :to-be 15)))

  (it "maps command 8 between PRG-ROM and banked PRG-RAM at $6000"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 69
                      :prg-banks 16
                      :chr-banks 8
                      :prg-ram-size (* 4 cl-nes::+prg-ram-bank-size+))))
      (mapper69-write-command! cartridge 8 2)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be 2)
      (mapper69-write-command! cartridge 8 #xC1)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be 0)
      (cl-nes::cartridge-cpu-write! cartridge #x6000 #xA5)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be #xA5)
      (mapper69-write-command! cartridge 8 #xC2)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be 0)
      (cl-nes::cartridge-cpu-write! cartridge #x6000 #x5A)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be #x5A)
      (mapper69-write-command! cartridge 8 #x41)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be nil)
      (cl-nes::cartridge-cpu-write! cartridge #x6000 #xFF)
      (mapper69-write-command! cartridge 8 #xC1)
      (expect (cl-nes::cartridge-cpu-read cartridge #x6000) :to-be #xA5)))

  (it "updates all four nametable mirroring modes with command 12"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 69
                      :prg-banks 4
                      :chr-banks 8)))
      (dolist (case '((0 . :vertical)
                      (1 . :horizontal)
                      (2 . :single-screen-lower)
                      (3 . :single-screen-upper)))
        (mapper69-write-command! cartridge 12 (car case))
        (expect (cartridge-mirroring cartridge) :to-be (cdr case))))))
