(in-package #:cl-nes/test)

(describe "Coverage: NES bus runtime paths"
  (it "reads the NROM 48 KiB window through the CPU bus"
    (let* ((prg (make-array (* 48 1024)
                            :element-type '(unsigned-byte 8)
                            :initial-element #x5A))
           (bus (make-bus
                 :cartridge (make-cartridge :prg-rom prg :chr-writable-p t))))
      (expect (bus-read bus #x4800) :to-be #x5A)
      (expect (bus-read bus #x7FFF) :to-be #x5A))))
