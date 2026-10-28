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
      (progn (ppu-write-register! ppu 6 #xFF) (ppu-tick! ppu 2))
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3FFF)
      (ppu-write-vram! ppu #x3F00 #x2A)
      (ppu-write-register! ppu 6 #x3F)
      (progn (ppu-write-register! ppu 6 #x00) (ppu-tick! ppu 2))
      (expect (ppu-read-register ppu 7) :to-be #x2A)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3F01)
      (ppu-write-register! ppu 1 #x01)
      (ppu-write-register! ppu 6 #x3F)
      (progn (ppu-write-register! ppu 6 #x00) (ppu-tick! ppu 2))
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
  (it "refreshes the end-phase status snapshot after the pre-render clear"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x60
            (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 0)
      (ppu-tick! ppu)
      (expect (ppu-status ppu) :to-be #x00)
      (expect (aref (cl-nes::ppu-status-history ppu) 0) :to-be #x00)
      (expect (ppu-read-register ppu 2 t :end) :to-be #x00)))

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
      (progn (ppu-write-register! ppu 6 #x00) (ppu-tick! ppu 2))
      (ppu-write-register! ppu 7 #x11)
      (ppu-write-register! ppu 7 #x22)
      (expect (ppu-read-vram ppu #x2000) :to-be #x11)
      (expect (ppu-read-vram ppu #x2020) :to-be #x22)
      (ppu-write-register! ppu 6 #x20)
      (progn (ppu-write-register! ppu 6 #x00) (ppu-tick! ppu 2))
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
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x11)))

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
      (progn (ppu-write-register! ppu 6 #x00) (ppu-tick! ppu 2))
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
  (it "keeps the pre-increment v address until a delayed rendering PPUDATA read commits"
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
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2C00)
      (expect (cl-nes::ppu-read-buffer-pending-address ppu) :to-be #x2C00)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x2A5A)
      (ppu-tick! ppu 7)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x42)
      (expect (cl-nes::ppu-read-buffer-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3C01)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x2C00)))
  (it "samples the rendering pattern byte when a delayed PPUDATA read commits"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-vram! ppu #x2802 #x02)
      (ppu-write-vram! ppu #x2BC0 #x00)
      (ppu-write-vram! ppu #x0022 #x46)
      (setf (cl-nes::ppu-vram-address ppu) #x2802
            (cl-nes::ppu-address-bus ppu) #x2802
            (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 340)
      (expect (ppu-read-register ppu 7 t) :to-be 0)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2802)
      (expect (cl-nes::ppu-read-buffer-pending-address ppu) :to-be #x2802)
      (ppu-tick! ppu 6)
      (expect (cl-nes::ppu-dot ppu) :to-be 5)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x0022)
      (expect (cl-nes::ppu-read-buffer-pending-p ppu) :to-be t)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x46)
      (expect (cl-nes::ppu-read-buffer-pending-p ppu) :to-be nil)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3803)))
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
      (progn
        (ppu-write-register! ppu 6 #x00)
        (expect (cl-nes::ppu-vram-address ppu) :to-be 0)
        (ppu-tick! ppu 2))
      (expect (cl-nes::ppu-temporary-address ppu) :to-be #x7C00)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x7C00)
      (expect (cl-nes::ppu-write-toggle ppu) :to-be nil)))
  (it "clears a scheduled T-to-V copy on reset"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-vram-address ppu) #x7F19
            (cl-nes::ppu-pending-vram-address-copy-p ppu) t
            (cl-nes::ppu-pending-vram-address-copy-delay ppu) 1
            (cl-nes::ppu-pending-vram-address-copy-value ppu) #x2F00
            (cl-nes::ppu-pending-vram-address-copy-wait-for-phase1-p ppu) t
            (cl-nes::ppu-pending-vram-address-copy-phase1-seen-p ppu) t)
      (cl-nes::ppu-reset! ppu)
      (expect (cl-nes::ppu-pending-vram-address-copy-p ppu) :to-be nil)
      (expect (cl-nes::ppu-pending-vram-address-copy-delay ppu) :to-be 0)
      (expect (cl-nes::ppu-pending-vram-address-copy-value ppu) :to-be 0)
      (expect (cl-nes::ppu-pending-vram-address-copy-wait-for-phase1-p ppu)
              :to-be nil)
      (expect (cl-nes::ppu-pending-vram-address-copy-phase1-seen-p ppu)
              :to-be nil)
      (expect (cl-nes::ppu-vram-address ppu) :to-be 0)))
  (it "reads the OAM evaluation latch and secondary OAM during rendering"
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
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 1)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 64)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-sprite-evaluation-latch ppu) #xA5
            (cl-nes::ppu-sprite-evaluation-done-p ppu) nil
            (cl-nes::ppu-secondary-oam-count ppu) 0
            (cl-nes::ppu-dot ppu) 65)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-sprite-evaluation-latch ppu) #x5A
            (cl-nes::ppu-dot ppu) 66)
      (progn
        (expect (ppu-read-register ppu 4 t) :to-be #x5A)
        (setf (aref (ppu-oam ppu) 0) #xFF
              (cl-nes::ppu-sprite-evaluation-latch ppu) #x03
              (cl-nes::ppu-secondary-oam-count ppu) 2
              (cl-nes::ppu-sprite-evaluation-done-p ppu) nil
              (cl-nes::ppu-dot ppu) 204)
        (expect (ppu-read-register ppu 4 t) :to-be #x03))
      (setf (cl-nes::ppu-sprite-evaluation-latch ppu) #xA5
            (cl-nes::ppu-sprite-evaluation-done-p ppu) t
            (cl-nes::ppu-dot ppu) 205)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-sprite-evaluation-latch ppu) #x5A
            (cl-nes::ppu-dot ppu) 256)
      (expect (ppu-read-register ppu 4 t) :to-be #x5A)
      (setf (cl-nes::ppu-secondary-oam-count ppu) 0
            (aref (ppu-oam ppu) 0) #x5A
            (cl-nes::ppu-dot ppu) 257)
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
      (progn
        (expect (ppu-read-register ppu 4 t) :to-be #x7F)
        (setf (aref (cl-nes::ppu-secondary-oam ppu) 0) #x06)
        (expect (ppu-read-register ppu 4 t) :to-be #x06))
      (setf (cl-nes::ppu-dot ppu) 340)
      (expect (ppu-read-register ppu 4 t) :to-be #x06)
      (setf (cl-nes::ppu-scanline ppu) 240
            (cl-nes::ppu-dot ppu) 1)
      (expect (ppu-read-register ppu 4 t) :to-be #x5A)
      (fill (cl-nes::ppu-secondary-oam ppu) #xFF)
      (setf (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-secondary-oam-count ppu) 0
            (aref (ppu-oam ppu) #xFC) #x55
            (cl-nes::ppu-dot ppu) 256)
      (expect (ppu-read-register ppu 4 t) :to-be #x55)
      (setf (cl-nes::ppu-dot ppu) 257)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 258)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 259)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)
      (setf (cl-nes::ppu-dot ppu) 260)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)))
  (it "reads secondary OAM during overflow and primary OAM after wrap"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-mask ppu) #x18
            (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 66
            (cl-nes::ppu-oam-address ppu) 0
            (cl-nes::ppu-sprite-evaluation-done-p ppu) nil
            (cl-nes::ppu-secondary-oam-count ppu) 8
            (cl-nes::ppu-sprite-evaluation-m ppu) 0
            (cl-nes::ppu-sprite-evaluation-latch ppu) #xA5
            (aref (cl-nes::ppu-secondary-oam ppu) 0) #x5A
            (aref (cl-nes::ppu-oam ppu) 4) #xC3)
      (expect (ppu-read-register ppu 4 t) :to-be #x5A)
      (setf (cl-nes::ppu-dot ppu) 65)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 66
            (cl-nes::ppu-oam-address ppu) 4
            (cl-nes::ppu-sprite-evaluation-n ppu) 1
            (cl-nes::ppu-sprite-evaluation-done-p ppu) t
            (cl-nes::ppu-sprite-evaluation-latch ppu) #xC3)
      (expect (ppu-read-register ppu 4 t) :to-be #xC3)))
  (it "reads secondary OAM on even evaluation cycles once full"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-mask ppu) #x18
            (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 66
            (cl-nes::ppu-oam-address ppu) 0
            (cl-nes::ppu-sprite-evaluation-done-p ppu) nil
            (cl-nes::ppu-secondary-oam-count ppu) 8
            (cl-nes::ppu-sprite-evaluation-m ppu) 0
            (cl-nes::ppu-sprite-evaluation-latch ppu) #xA5
            (aref (cl-nes::ppu-secondary-oam ppu) 0) #x5A
            (aref (cl-nes::ppu-oam ppu) 4) #xC3)
      (expect (ppu-read-register ppu 4 t) :to-be #x5A)
      (setf (cl-nes::ppu-dot ppu) 65)
      (expect (ppu-read-register ppu 4 t) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 66
            (cl-nes::ppu-oam-address ppu) 4
            (cl-nes::ppu-sprite-evaluation-n ppu) 1
            (cl-nes::ppu-sprite-evaluation-done-p ppu) t
            (cl-nes::ppu-sprite-evaluation-latch ppu) #xC3)
      (expect (ppu-read-register ppu 4 t) :to-be #xC3)))
  (it "ignores OAMDATA writes during rendering and increments OAMADDR by four"
    (let ((ppu (make-ppu)))
      (setf (aref (cl-nes::ppu-oam ppu) 0) #xA5
            (aref (cl-nes::ppu-oam ppu) 4) #x8C
            (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 321
            (cl-nes::ppu-oam-address ppu) 0)
      (ppu-write-register! ppu 4 0 t)
      (expect (aref (cl-nes::ppu-oam ppu) 0) :to-be #xA5)
      (expect (cl-nes::ppu-oam-address ppu) :to-be 4)
      (setf (cl-nes::ppu-mask ppu) 0)
      (expect (ppu-read-register ppu 4 t) :to-be #x8C)))
  (it "continues OAM[n][0] reads and N increments after wrap"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-mask ppu) #x18
            (cl-nes::ppu-scanline ppu) 128
            (cl-nes::ppu-dot ppu) 231
            (cl-nes::ppu-oam-address ppu) #xFE
            (cl-nes::ppu-secondary-oam-count ppu) 1
            (cl-nes::ppu-oam2-address ppu) 2
            (cl-nes::ppu-sprite-evaluation-n ppu) 63
            (cl-nes::ppu-sprite-evaluation-m ppu) 2
            (cl-nes::ppu-sprite-evaluation-latch ppu) #x8C
            (aref (cl-nes::ppu-oam ppu) #x34) #xCB
            (aref (cl-nes::ppu-secondary-oam ppu) 4) #x77)
      (cl-nes::%ppu-evaluate-sprites! ppu 128 202)
      (expect (cl-nes::ppu-sprite-evaluation-m ppu) :to-be 3)
      (expect (cl-nes::ppu-oam-address ppu) :to-be #xFF)
      (cl-nes::%ppu-evaluate-sprites! ppu 128 204)
      (expect (cl-nes::ppu-sprite-evaluation-done-p ppu) :to-be t)
      (expect (cl-nes::ppu-sprite-evaluation-m ppu) :to-be 0)
      (expect (cl-nes::ppu-oam-address ppu) :to-be 0)
      (expect (aref (cl-nes::ppu-secondary-oam ppu) 2) :to-be #x8C)
      (expect (aref (cl-nes::ppu-secondary-oam ppu) 3) :to-be #x8C)
      (loop for evaluation-dot from 206 to 230 by 2
            do (cl-nes::%ppu-evaluate-sprites! ppu 128 evaluation-dot))
      (expect (cl-nes::ppu-sprite-evaluation-n ppu) :to-be 13)
      (expect (cl-nes::ppu-sprite-evaluation-m ppu) :to-be 0)
      (expect (cl-nes::ppu-oam-address ppu) :to-be #x34)
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 1)
      (cl-nes::%ppu-evaluate-sprites! ppu 128 231)
      (expect (cl-nes::ppu-sprite-evaluation-latch ppu) :to-be #xCB)
      (expect (aref (cl-nes::ppu-secondary-oam ppu) 4) :to-be #x77)
      (expect (ppu-read-register ppu 4 t) :to-be #xCB)))
  (it "resets OAMADDR throughout sprite fetch before dot-321 writes"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-mask ppu) #x08
            (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-oam-address ppu) 0
            (aref (cl-nes::ppu-oam ppu) 0) #x5A
            (aref (cl-nes::ppu-oam ppu) 4) #x8C)
      (loop for dot from 257 to 320
            do (setf (cl-nes::ppu-dot ppu) dot
                     (cl-nes::ppu-oam-address ppu) #x84)
               (cl-nes::%ppu-clock-pipeline! ppu)
               (expect (cl-nes::ppu-oam-address ppu) :to-be 0))
      (setf (cl-nes::ppu-dot ppu) 321)
      (ppu-write-register! ppu 4 0 t)
      (expect (cl-nes::ppu-oam-address ppu) :to-be 4)
      (expect (aref (cl-nes::ppu-oam ppu) 0) :to-be #x5A)
      (setf (cl-nes::ppu-mask ppu) 0)
      (expect (ppu-read-register ppu 4 t) :to-be #x8C))))
