(in-package #:cl-nes/test)

(describe "PPU nametable memory transitions"
  (it "applies horizontal, vertical, and four-screen nametable mapping"
    (let ((horizontal (make-ppu (make-state-transition-cartridge)))
          (vertical (make-ppu
                     (make-state-transition-cartridge
                      :mirroring :vertical)))
          (four-screen (make-ppu
                        (make-state-transition-cartridge
                         :four-screen-p t))))
      (ppu-write-vram! horizontal #x2000 #x11)
      (expect (ppu-read-vram horizontal #x2400) :to-be #x11)
      (ppu-write-vram! vertical #x2000 #x22)
      (ppu-write-vram! vertical #x2400 #x33)
      (expect (ppu-read-vram vertical #x2000) :to-be #x22)
      (expect (ppu-read-vram vertical #x2400) :to-be #x33)
      (ppu-write-vram! four-screen #x2000 #x44)
      (ppu-write-vram! four-screen #x2800 #x55)
      (expect (ppu-read-vram four-screen #x2000) :to-be #x44)
      (expect (ppu-read-vram four-screen #x2800) :to-be #x55)
      (ppu-write-vram! four-screen #x3F10 #x66)
      (expect (ppu-read-vram four-screen #x3F00) :to-be #x66)))

  (it "maps single-screen upper and lower nametables independently"
    (let ((upper (make-ppu
                  (make-state-transition-cartridge
                   :mirroring :single-screen-upper)))
          (lower (make-ppu
                  (make-state-transition-cartridge
                   :mirroring :single-screen-lower))))
      (ppu-write-vram! upper #x2000 #x11)
      (expect (ppu-read-vram upper #x2400) :to-be #x11)
      (ppu-write-vram! lower #x2800 #x22)
      (expect (ppu-read-vram lower #x2C00) :to-be #x22))))
