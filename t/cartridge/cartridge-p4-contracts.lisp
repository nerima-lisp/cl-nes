(in-package #:cl-nes/test)

(defun make-exponent-rom-image ()
  (let ((image (make-array (+ 16 #x8000 #x2000)
                           :element-type '(unsigned-byte 8)
                           :initial-element #xA5)))
    (setf (aref image 0) #x4E
          (aref image 1) #x45
          (aref image 2) #x53
          (aref image 3) #x1A
          (aref image 4) #x3C
          (aref image 5) 1
          (aref image 6) 0
          (aref image 7) #x08
          (aref image 8) 0
          (aref image 9) #x0F)
    image))

(describe "P4 cartridge contracts"
  (it "loads NES 2.0 exponent ROM sizes and preserves submapper"
    (let ((cartridge (load-cartridge (make-exponent-rom-image))))
      (expect (cartridge-prg-size cartridge) :to-be #x8000)
      (expect (cartridge-chr-size cartridge) :to-be #x2000)
      (expect (cartridge-submapper cartridge) :to-be 0)))

  (it "saves and restores battery-backed PRG-RAM"
    (let ((cartridge (make-cartridge :mapper 0
                                     :prg-rom (make-array #x4000
                                                          :element-type '(unsigned-byte 8))
                                     :battery-backed-p t)))
      (setf (aref (cartridge-prg-ram cartridge) 0) #x7E)
      (let ((saved (cartridge-save-battery cartridge)))
        (setf (aref (cartridge-prg-ram cartridge) 0) 0)
        (cartridge-restore-battery! cartridge saved)
        (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #x7E))))

  (it "signals a battery condition for non-battery cartridges"
    (expect (lambda ()
              (cartridge-save-battery
               (make-cartridge :mapper 0
                               :prg-rom (make-array #x4000
                                                    :element-type '(unsigned-byte 8)))))
            :to-throw 'cartridge-battery-error)))

  (it "maps FME-7 and NINA-03/06 banks"
    (let ((fme (make-cartridge
                :mapper 69
                :prg-rom (make-array (* 4 cl-nes::+prg-bank-8k-size+)
                                     :element-type '(unsigned-byte 8))
                :chr-rom (make-array (* 8 cl-nes::+chr-bank-1k-size+)
                                     :element-type '(unsigned-byte 8)))))
      (cartridge-write-prg! fme #x8000 0)
      (cartridge-write-prg! fme #xA000 3)
      (expect (cl-nes::cartridge-mapper69-command fme) :to-be 0)
      (let ((nina (make-cartridge
                   :mapper 79
                   :prg-rom (make-array (* 8 cl-nes::+prg-bank-8k-size+)
                                        :element-type '(unsigned-byte 8))
                   :chr-rom (make-array (* 8 cl-nes::+chr-bank-1k-size+)
                                        :element-type '(unsigned-byte 8)))))
        (cartridge-write-prg! nina #x4100 #x11)
        (expect (cl-nes::cartridge-prg-bank nina) :to-be 1))))
