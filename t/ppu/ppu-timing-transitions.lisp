(in-package #:cl-nes/test)

(describe "PPU timing transitions"
  (it-each ((:vblank-set 241 0 #x00 #x80 t)
            (:vblank-clear 261 0 #xE0 #x00 nil)
            (:overflow 1 64 #x00 #x20 nil))
    "applies status transitions at the specified dot"
    (kind scanline dot initial-status expected-status frame-ready)
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) scanline
            (cl-nes::ppu-dot ppu) dot
            (ppu-status ppu) initial-status)
      (when (eql kind :overflow)
        (dotimes (sprite 9)
          (setf (aref (ppu-oam ppu) (* sprite 4)) 0)))
      (ppu-tick! ppu)
      (expect (logand (ppu-status ppu) (logior #x80 #x20))
              :to-be expected-status)
      (expect (ppu-frame-ready-p ppu) :to-be frame-ready)))
  (it "reproduces the n/m sprite overflow evaluation bug"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-mask ppu) #x08
            (cl-nes::ppu-scanline ppu) 1)
      (dotimes (sprite 8)
        (setf (aref (ppu-oam ppu) (* sprite 4)) 0))
      (setf (aref (ppu-oam ppu) (* 8 4)) 100
            (aref (ppu-oam ppu) (+ (* 8 4) 1)) 1)
      (cl-nes::%ppu-evaluate-sprites! ppu 1)
      (expect (logand (ppu-status ppu) #x20) :to-be #x20)))
  (it "suppresses the vblank NMI when status is read at the race dot"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 241
            (cl-nes::ppu-dot ppu) 0)
      (ppu-write-register! ppu 0 #x80)
      (ppu-tick! ppu)
      (expect (logand (ppu-status ppu) #x80) :to-be #x80)
      (ppu-read-register ppu 2 t)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)))
  (it "advances dots across scanline and frame boundaries"
    (dolist (case '((:name :ordinary-dot
                     :scanline 12 :dot 7 :odd-frame-p nil :mask 0
                     :ticks 1 :expected-scanline 12 :expected-dot 8
                     :expected-odd-frame-p nil)
                    (:name :scanline-wrap
                     :scanline 12 :dot 340 :odd-frame-p nil :mask 0
                     :ticks 1 :expected-scanline 13 :expected-dot 0
                     :expected-odd-frame-p nil)
                    (:name :even-frame-wrap
                     :scanline 261 :dot 340 :odd-frame-p nil :mask 0
                     :ticks 1 :expected-scanline 0 :expected-dot 0
                     :expected-odd-frame-p t)
                    (:name :odd-frame-rendering-skip
                     :scanline 261 :dot 338 :odd-frame-p t :mask #x08
                     :ticks 2 :expected-scanline 0 :expected-dot 0
                     :expected-odd-frame-p nil)
                    (:name :odd-frame-rendering-disabled
                     :scanline 261 :dot 338 :odd-frame-p t :mask 0
                     :ticks 3 :expected-scanline 0 :expected-dot 0
                     :expected-odd-frame-p nil)))
      (let ((ppu (make-ppu (make-fixture-cartridge))))
        (setf (cl-nes::ppu-scanline ppu) (getf case :scanline)
              (cl-nes::ppu-dot ppu) (getf case :dot)
              (cl-nes::ppu-odd-frame-p ppu) (getf case :odd-frame-p)
              (ppu-mask ppu) (getf case :mask))
        (ppu-tick! ppu (getf case :ticks))
        (expect (cl-nes::ppu-scanline ppu)
                :to-be (getf case :expected-scanline))
        (expect (cl-nes::ppu-dot ppu)
                :to-be (getf case :expected-dot))
        (expect (cl-nes::ppu-odd-frame-p ppu)
                :to-be (getf case :expected-odd-frame-p)))))
  (it "enters vblank, delays NMI delivery, and starts a new frame"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-register! ppu 0 #x80)
      (ppu-tick! ppu (* 241 341))
      (expect (cl-nes::ppu-scanline ppu) :to-be 241)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (ppu-frame-ready-p ppu) :to-be t)
      (expect (logand (ppu-status ppu) #x80) :to-be #x80)
      (expect (ppu-nmi-pending-p ppu) :to-be t)
      (expect (ppu-take-nmi! ppu) :to-be nil)
      (ppu-tick! ppu 3)
      (expect (ppu-take-nmi! ppu) :to-be t)
      (ppu-tick! ppu (- (* 20 341) 3))
      (expect (cl-nes::ppu-scanline ppu) :to-be 261)
      (expect (cl-nes::ppu-dot ppu) :to-be 1)
      (expect (ppu-frame-ready-p ppu) :to-be nil)
      (expect (ppu-status ppu) :to-be 0)))
  (it "skips the odd-frame pre-render dot when rendering is enabled"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 338
            (cl-nes::ppu-odd-frame-p ppu) t
            (ppu-mask ppu) #x08)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 340)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be nil)))
  (it "does not skip the odd-frame pre-render dot when rendering is disabled"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 338
            (cl-nes::ppu-odd-frame-p ppu) t
            (ppu-mask ppu) 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 339)
      (ppu-tick! ppu 2)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be nil)))
  (it-each ((256 0 #x7000 #x0021)
            (257 12 #x041F #x7FFF)
            (280 261 #x7BE0 #x7FFF)
            (292 261 #x7BE0 #x7FFF)
            (304 261 #x7BE0 #x7FFF))
    "updates scroll state at dot ~D on scanline ~D"
    (dot scanline temporary expected)
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) scanline
            (cl-nes::ppu-dot ppu) (1- dot)
            (cl-nes::ppu-temporary-address ppu) temporary
            (cl-nes::ppu-vram-address ppu)
            (if (= dot 256) #x7000
                (if (= dot 257) #x7BE0 #x041F)))
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-vram-address ppu) :to-be expected))))
