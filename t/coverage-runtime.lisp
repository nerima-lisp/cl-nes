(in-package #:cl-nes/test)

(describe "Coverage: runtime paths"
  (it "renders enabled backgrounds and sprites"
    (let* ((cartridge (make-fixture-cartridge))
           (ppu (make-ppu cartridge))
           (oam (cl-nes::ppu-oam ppu))
           (framebuffer (ppu-framebuffer ppu)))
      (fill oam #xFF)
      (setf (aref oam 0) 0
            (aref oam 1) 0
            (aref oam 2) #x20
            (aref oam 3) 8)
      (ppu-write-register! ppu 1 #x0E)
      (ppu-write-vram! ppu #x0000 #x80)
      (ppu-write-vram! ppu #x0001 #x80)
      (ppu-write-vram! ppu #x2000 0)
      (ppu-write-vram! ppu #x3F01 #x21)
      (ppu-write-vram! ppu #x3F11 #x22)
      (let ((background-opaque (cl-nes::%render-background! ppu)))
        (expect (aref framebuffer 0) :to-be #x21)
        (expect (aref background-opaque 0) :to-be 1)
        (let ((occupied
                (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                            :element-type 'bit
                            :initial-element 0)))
          (cl-nes::%draw-sprite-pixel!
           ppu 0 8 1 background-opaque occupied)
          (expect (aref framebuffer (+ 8 cl-nes::+ppu-width+))
                  :to-be #x21)
          (expect (aref occupied (+ 8 cl-nes::+ppu-width+)) :to-be 1)
          (expect (logand (ppu-status ppu) #x40) :to-be #x40))
        (cl-nes::%render-sprites! ppu background-opaque)
        (setf (ppu-status ppu) (logand (ppu-status ppu) #xDF))
        (dotimes (sprite 9)
          (setf (aref oam (* sprite 4)) 0))
        (cl-nes::%render-sprites! ppu background-opaque)
        (expect (logand (ppu-status ppu) #x20) :to-be #x20))))

  (it "expires decay and applies delayed masks"
    (let ((ppu (make-ppu)))
      (cl-nes::%ppu-drive-decay! ppu #xFF)
      (expect (ppu-read-register ppu 0 t) :to-be #xFF)
      (cl-nes::%ppu-clock-decay! ppu cl-nes::+ppu-decay-period+)
      (expect (cl-nes::ppu-decay-value ppu) :to-be 0)
      (ppu-write-register! ppu 3 2)
      (ppu-write-register! ppu 4 #xFF)
      (ppu-write-register! ppu 3 2)
      (expect (ppu-read-register ppu 4 t) :to-be #xE3)
      (setf (ppu-status ppu) #x80)
      (ppu-write-register! ppu 0 #x80)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be t)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)
      (ppu-write-register! ppu 1 #x08)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask-delay ppu) :to-be 1)
      (ppu-tick! ppu)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x08)))

  (it "loads and resets cartridges through the public NES lifecycle"
    (let ((nes (make-nes))
          (cartridge (make-fixture-cartridge)))
      (expect (nes-load-cartridge! nes cartridge) :to-be nes)
      (expect (nes-reset! nes) :to-be nes)
      (expect (nes-load-cartridge! nes nil) :to-be nes)
      (expect (cl-nes::bus-cartridge (nes-bus nes)) :to-be nil)
      (expect (nes-reset! nes) :to-be nes)))

  (it "runs DMA stalls as part of a NES step"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (bus-write! (nes-bus nes) #x4014 0)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect (plusp cycles) :to-be t)
        (expect (cl-nes::bus-dma-stall-cycles (nes-bus nes)) :to-be 0)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8001))))

  (it "hijacks BRK with a delayed NMI at the vector poll"
    (let* ((cartridge (make-fixture-cartridge :program '(#x00)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 7)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil))))

  (it "takes an external NMI after an instruction"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 9)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil))))

  (it "signals illegal opcodes at the CPU execution boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#x02)))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (let ((condition
              (captured-condition (lambda () (cpu-step! cpu bus)))))
        (expect (typep condition 'illegal-opcode) :to-be t)
        (expect (illegal-opcode-value condition) :to-be #x02)))))
