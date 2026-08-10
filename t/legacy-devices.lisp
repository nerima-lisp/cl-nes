(in-package #:cl-nes/test-runner)

(defun test-bus-and-controller ()
  (let* ((controller (make-controller))
         (bus (make-bus :controller-1 controller)))
    (bus-write! bus #x0000 #x5A)
    (check-equal (bus-read bus #x0800) #x5A
                 "CPU RAM is mirrored every $0800 bytes")
    (controller-set-buttons! controller (logior +button-a+ +button-right+))
    (bus-write! bus #x4016 1)
    (bus-write! bus #x4016 0)
    (check-equal (bus-read bus #x4016) 1 "controller reads A first")
    (dotimes (ignored 6)
      (bus-read bus #x4016))
    (check-equal (bus-read bus #x4016) 1 "controller reads Right eighth")
    (check-equal (bus-read bus #x4016) 1 "controller returns one after eight reads"))
  (let* ((cartridge (make-test-cartridge))
         (bus (make-bus :cartridge cartridge)))
    (bus-write! bus #x6000 #xA5)
    (check-equal (bus-read bus #x6000) #xA5
                 "cartridge PRG-RAM is readable at $6000")
    (bus-write! bus #x7FFF #x5A)
    (check-equal (bus-read bus #x7FFF) #x5A
                 "cartridge PRG-RAM covers the complete 8 KiB window")))

(defun test-ppu-registers-and-vblank ()
  (let ((ppu (make-ppu (make-test-cartridge))))
    (ppu-write-register! ppu 6 #x20)
    (ppu-write-register! ppu 6 #x00)
    (ppu-write-register! ppu 7 #x37)
    (check-equal (ppu-read-vram ppu #x2000) #x37
                 "PPUADDR and PPUDATA write nametable memory")
    (ppu-write-vram! ppu #x2001 #x4A)
    (ppu-write-register! ppu 6 #x20)
    (ppu-write-register! ppu 6 #x01)
    (check-equal (ppu-read-register ppu 7) 0
                 "PPUDATA uses a delayed read buffer")
    (check-equal (ppu-read-register ppu 7) #x4A
                 "PPUDATA returns the buffered byte")
    (ppu-write-register! ppu 0 #x80)
    (ppu-tick! ppu (+ (* 241 341) 1))
    (check (logbitp 7 (ppu-status ppu)) "PPU enters VBlank")
    (check (ppu-frame-ready-p ppu) "PPU marks a completed frame")
    (check (not (ppu-take-nmi! ppu))
           "PPU delays NMI recognition by one CPU boundary")
    (check (ppu-take-nmi! ppu) "PPU raises NMI when enabled")
    (check (not (ppu-take-nmi! ppu)) "PPU NMI is edge-consumed")
    (check (logbitp 7 (ppu-read-register ppu 2)) "PPUSTATUS reports VBlank")
    (check (not (logbitp 7 (ppu-status ppu))) "PPUSTATUS clears VBlank")))

(defun test-ppu-rendering ()
  (labels ((make-render-ppu ()
             (make-ppu
              (make-cartridge
               :prg-rom (make-array #x8000
                                    :element-type '(unsigned-byte 8)
                                    :initial-element 0)
               :four-screen-p t)))
           (set-pattern (ppu tile low high)
             (loop for row below 8 do
               (ppu-write-vram! ppu (+ (* tile 16) row) low)
               (ppu-write-vram! ppu (+ (* tile 16) 8 row) high)))
           (prepare-background (ppu)
             (set-pattern ppu 1 #xFF 0)
             (set-pattern ppu 2 0 #xFF)
             (ppu-write-vram! ppu #x2000 1)
             (ppu-write-vram! ppu #x2001 2)
             (ppu-write-vram! ppu #x2020 2)
             (ppu-write-vram! ppu #x3F01 #x12)
             (ppu-write-vram! ppu #x3F02 #x23)
             (ppu-write-vram! ppu #x3F05 #x25)
             (ppu-write-register! ppu 1 #x1E))
           (render (ppu)
             (ppu-tick! ppu (+ (* 241 341) 1)))
           (pixel (ppu x y)
             (aref (ppu-framebuffer ppu) (+ x (* y 256))))
           (hide-unused-sprites (ppu)
             (loop for sprite from 1 below 64 do
               (setf (aref (ppu-oam ppu) (* sprite 4)) #xFF))))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (render ppu)
      (check-equal (pixel ppu 0 0) #x12
                   "background tile pixels use the first palette")
      (check-equal (pixel ppu 8 0) #x23
                   "background tile pixels advance across nametable data"))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (ppu-write-register! ppu 5 8)
      (ppu-write-register! ppu 5 0)
      (render ppu)
      (check-equal (pixel ppu 0 0) #x23
                   "horizontal scroll crosses into the next tile"))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (ppu-write-register! ppu 5 0)
      (ppu-write-register! ppu 5 8)
      (render ppu)
      (check-equal (pixel ppu 0 0) #x23
                   "vertical scroll crosses into the next tile row"))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (ppu-write-vram! ppu #x23C0 1)
      (render ppu)
      (check-equal (pixel ppu 0 0) #x25
                   "background attribute data selects a palette"))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (ppu-write-vram! ppu #x3F11 #x34)
      (hide-unused-sprites ppu)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 1
            (aref (ppu-oam ppu) 2) 0
            (aref (ppu-oam ppu) 3) 0)
      (render ppu)
      (check-equal (pixel ppu 0 1) #x34
                   "opaque sprite pixels overlay the background")
      (check (logbitp 6 (ppu-status ppu))
             "sprite zero hit is reported")
      (check (not (logbitp 5 (ppu-status ppu)))
             "sprite overflow stays clear with eight or fewer sprites"))
    (let ((ppu (make-render-ppu)))
      (prepare-background ppu)
      (ppu-write-vram! ppu #x3F11 #x34)
      (hide-unused-sprites ppu)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 1
            (aref (ppu-oam ppu) 2) #x20
            (aref (ppu-oam ppu) 3) 0)
      (render ppu)
      (check-equal (pixel ppu 0 1) #x12
                   "behind-background sprites preserve opaque background"))
    (let ((ppu (make-render-ppu)))
      (set-pattern ppu 0 0 0)
      (set-pattern ppu 1 #xFF 0)
      (ppu-write-vram! ppu #x3F11 #x34)
      (ppu-write-register! ppu 0 #x20)
      (ppu-write-register! ppu 1 #x1E)
      (hide-unused-sprites ppu)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 0
            (aref (ppu-oam ppu) 2) 0
            (aref (ppu-oam ppu) 3) 0)
      (render ppu)
      (check-equal (pixel ppu 0 9) #x34
                   "8x16 sprites select the second pattern tile"))
    (let ((ppu (make-render-ppu)))
      (set-pattern ppu 1 #xFF 0)
      (ppu-write-vram! ppu #x3F11 #x34)
      (ppu-write-register! ppu 1 #x0C)
      (hide-unused-sprites ppu)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 1
            (aref (ppu-oam ppu) 2) 0
            (aref (ppu-oam ppu) 3) 4)
      (render ppu)
      (check-equal (pixel ppu 4 1) 0
                   "sprite left-edge masking hides the first eight pixels")
      (check-equal (pixel ppu 8 1) #x34
                   "sprite left-edge masking preserves pixels after x=8"))))


