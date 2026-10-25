(in-package #:cl-nes/test)

(describe "PPU register memory transitions"
  (it "updates the temporary address and propagates the rendering mask"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 0 #x03)
      (expect (ppu-control ppu) :to-be #x03)
      (expect (cl-nes::ppu-temporary-address ppu) :to-be #x0C00)
      (ppu-write-register! ppu 1 #x18)
      (expect (ppu-mask ppu) :to-be #x18)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be #x18)))

  (it "wraps the 15-bit VRAM address and masks immediate palette reads in greyscale"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 6 #x7F)
      (ppu-write-register! ppu 6 #xFF)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3FFF)
      (ppu-write-vram! ppu #x3F00 #x2A)
      (ppu-write-register! ppu 6 #x3F)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be #x2A)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3F01)
      (ppu-write-register! ppu 1 #x01)
      (ppu-write-register! ppu 6 #x3F)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be #x20)
      (expect (ppu-read-vram ppu #x3F00) :to-be #x2A)))

  (it "resets the scroll latch when status is read"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 5 #x12)
      (setf (ppu-status ppu) #xE0)
      (expect (ppu-read-register ppu 2) :to-be #xE0)
      (expect (ppu-status ppu) :to-be #x60)
      (ppu-write-register! ppu 5 #x34)
      (ppu-write-register! ppu 5 #xA8)
      (expect (cl-nes::ppu-scroll-x ppu) :to-be #x34)
      (expect (cl-nes::ppu-scroll-y ppu) :to-be #xA8)
      (expect (cl-nes::ppu-fine-x ppu) :to-be 4)))

  (it "cancels a delayed NMI when status is read in the vblank suppression window"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80
            (cl-nes::ppu-scanline ppu) 241
            (cl-nes::ppu-dot ppu) 1
            (cl-nes::ppu-nmi-pending-p ppu) t
            (cl-nes::ppu-nmi-delay-p ppu) 2)
      (expect (ppu-read-register ppu 2) :to-be #x80)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be nil)))

  (it "uses the delayed NMI timing for a CPU control write at vblank"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80
            (cl-nes::ppu-scanline ppu) 241)
      (ppu-write-register! ppu 0 #x80 t)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be 6)
      (ppu-write-register! ppu 0 #x80)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)))

  (it "keeps pattern-table memory open when no cartridge is loaded"
    (let ((ppu (make-ppu)))
      (expect (ppu-read-vram ppu #x1000) :to-be 0)
      (expect (ppu-write-vram! ppu #x1000 #xA5) :to-be #xA5)
      (expect (ppu-read-vram ppu #x1000) :to-be 0)))

  (it "buffers nametable reads and increments VRAM by 32 when selected"
    (let ((ppu (make-ppu)))
      (ppu-write-vram! ppu #x2000 #x55)
      (ppu-write-register! ppu 0 #x04)
      (ppu-write-register! ppu 6 #x20)
      (ppu-write-register! ppu 6 #x00)
      (ppu-write-register! ppu 7 #x11)
      (ppu-write-register! ppu 7 #x22)
      (expect (ppu-read-vram ppu #x2000) :to-be #x11)
      (expect (ppu-read-vram ppu #x2020) :to-be #x22)
      (ppu-write-register! ppu 6 #x20)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be 0)
      (expect (ppu-read-register ppu 7) :to-be #x11)
      (setf (cl-nes::ppu-vram-address ppu) #x2000
            (cl-nes::ppu-read-buffer ppu) #x34
            (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-dot ppu) 330)
      (expect (ppu-read-register ppu 7 t) :to-be #x34)
      (ppu-tick! ppu 6)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x34)
      (ppu-tick! ppu 1)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be 0)))

  (it "wraps coarse Y at the final nametable row"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-vram-address ppu) #x73E0)
      (cl-nes::%ppu-vertical-increment! ppu)
      (expect (cl-nes::ppu-vram-address ppu) :to-be 0)))
  (it-each ((#x08) (#x10))
    "increments both scroll axes when PPUDATA is accessed during rendering"
    (mask)
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 1 mask)
      (ppu-tick! ppu 3)
      (ppu-write-register! ppu 0 #x04)
      (ppu-write-register! ppu 6 #x2C)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be 0)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3C01)))
  (it "wraps coarse X and Y when PPUDATA is accessed during rendering"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 1 #x18)
      (ppu-tick! ppu 3)
      (ppu-write-register! ppu 0 #x04)
      (setf (cl-nes::ppu-vram-address ppu) #x73BF)
      (expect (ppu-read-register ppu 7) :to-be 0)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x0C00)))
  (it "reads the post-increment v address after delayed rendering PPUDATA reads"
    (let ((ppu (make-ppu)))
      (ppu-write-vram! ppu #x2A5A #x11)
      (ppu-write-vram! ppu #x2C00 #x42)
      (ppu-write-vram! ppu #x3C01 #xA5)
      (expect (ppu-read-vram ppu #x2A5A) :to-be #x11)
      (expect (ppu-read-vram ppu #x2C00) :to-be #x42)
      (expect (ppu-read-vram ppu #x3C01) :to-be #xA5)
      (setf (cl-nes::ppu-vram-address ppu) #x2C00
            (cl-nes::ppu-address-bus ppu) #x2A5A
            (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-scanline ppu) 239
            (cl-nes::ppu-dot ppu) 340)
      (expect (ppu-read-register ppu 7 t) :to-be 0)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3C01)
      (expect (cl-nes::ppu-read-buffer-pending-address ppu) :to-be #x3C01)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x2A5A)
      (ppu-tick! ppu 7)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #xA5)
      (expect (cl-nes::ppu-read-buffer-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x3C01)))
  (it "clocks background shifters only in fetch windows while rendering"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-dot ppu) 256
            (cl-nes::ppu-background-shift-low ppu) #x1234
            (cl-nes::ppu-background-shift-high ppu) #x5678)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 257)
      (expect (cl-nes::ppu-background-shift-low ppu) :to-be #x1234)
      (expect (cl-nes::ppu-background-shift-high ppu) :to-be #x5678)
      (setf (cl-nes::ppu-dot ppu) 320)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 321)
      (expect (cl-nes::ppu-background-shift-low ppu) :to-be #x2468)
      (expect (cl-nes::ppu-background-shift-high ppu) :to-be #xACF1)
      (setf (cl-nes::ppu-mask ppu) 0
            (cl-nes::ppu-rendering-mask ppu) 0
            (cl-nes::ppu-rendering-mask-pending ppu) 0
            (cl-nes::ppu-rendering-mask-delay ppu) 0
            (cl-nes::ppu-rendering-mask-valid-p ppu) t
            (cl-nes::ppu-dot ppu) 320
            (cl-nes::ppu-background-shift-low ppu) #x1234
            (cl-nes::ppu-background-shift-high ppu) #x5678)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 321)
      (expect (cl-nes::ppu-background-shift-low ppu) :to-be #x1234)
      (expect (cl-nes::ppu-background-shift-high ppu) :to-be #x5678)
      (setf (cl-nes::ppu-mask ppu) #x10
            (cl-nes::ppu-rendering-mask-pending ppu) #x10
            (cl-nes::ppu-rendering-mask-delay ppu) 2
            (cl-nes::ppu-dot ppu) 320)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 321)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (expect (cl-nes::ppu-background-shift-low ppu) :to-be #x1234)
      (expect (cl-nes::ppu-background-shift-high ppu) :to-be #x5678)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 322)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be #x10)
      (expect (cl-nes::ppu-background-shift-low ppu) :to-be #x2468)
      (expect (cl-nes::ppu-background-shift-high ppu) :to-be #xACF1)))
  (it "preserves fine Y when a second $2006 write follows $2005 writes"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 6 #x2C)
      (ppu-write-register! ppu 5 #x17)
      (ppu-write-register! ppu 5 #x17)
      (expect (cl-nes::ppu-temporary-address ppu) :to-be #x7C42)
      (ppu-write-register! ppu 6 #x00)
      (expect (cl-nes::ppu-temporary-address ppu) :to-be #x7C00)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x7C00)
      (expect (cl-nes::ppu-write-toggle ppu) :to-be nil)))
  (it "reads primary and secondary OAM buses during rendering phases"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-mask ppu) #x18
            (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 0
            (ppu-oam-address ppu) 0
            (aref (ppu-oam ppu) 0) #x5A
            (aref (cl-nes::ppu-secondary-oam ppu) 0) #x7F
            (aref (cl-nes::ppu-secondary-oam ppu) 1) #x7E
            (aref (cl-nes::ppu-secondary-oam ppu) 2) #x61
            (aref (cl-nes::ppu-secondary-oam ppu) 3) #x7C)
      (expect (ppu-read-register ppu 4 t) :to-be #x7F)
      (setf (cl-nes::ppu-dot ppu) 1)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 64)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-sprite-evaluation-latch ppu) #xA5
            (cl-nes::ppu-dot ppu) 65)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 66)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 256)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 257)
      (expect (ppu-read-register ppu 4 t) :to-be #x7F)
      (setf (cl-nes::ppu-dot ppu) 258)
      (expect (ppu-read-register ppu 4 t) :to-be #x7E)
      (setf (cl-nes::ppu-dot ppu) 259)
      (expect (ppu-read-register ppu 4 t) :to-be #x61)
      (setf (cl-nes::ppu-dot ppu) 260)
      (expect (ppu-read-register ppu 4 t) :to-be #x7C)
      (setf (cl-nes::ppu-dot ppu) 264)
      (expect (ppu-read-register ppu 4 t) :to-be #x7C)
      (setf (cl-nes::ppu-dot ppu) 320)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 321)
      (expect (ppu-read-register ppu 4 t) :to-be #x7F)
      (setf (cl-nes::ppu-dot ppu) 340)
      (expect (ppu-read-register ppu 4 t) :to-be #x7F)
      (setf (cl-nes::ppu-scanline ppu) 240
            (cl-nes::ppu-dot ppu) 1)
      (expect (ppu-read-register ppu 4 t) :to-be #x5A))))
