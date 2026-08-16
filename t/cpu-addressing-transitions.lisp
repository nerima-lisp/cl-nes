(in-package #:cl-nes/test)

(describe "CPU addressing transitions"
  (it "applies page-crossing penalties to indexed reads"
    (let ((cartridge (make-fixture-cartridge
                      :program '(#xB9 #xFF #x80))))
      (setf (aref (cartridge-prg-rom cartridge) #x100) #xA5)
      (let ((bus (make-bus :cartridge cartridge))
            (cpu (make-cpu)))
        (cpu-reset! cpu bus)
        (setf (cpu-y cpu) 1)
        (expect (cpu-step! cpu bus) :to-be 5)
        (expect (cpu-a cpu) :to-be #xA5)
        (expect (cpu-pc cpu) :to-be #x8003)))
    (let ((cartridge (make-fixture-cartridge
                      :program '(#xB1 #x20))))
      (setf (aref (cartridge-prg-rom cartridge) #x100) #x5A)
      (let ((bus (make-bus :cartridge cartridge))
            (cpu (make-cpu)))
        (cpu-reset! cpu bus)
        (bus-write! bus #x20 #xFF)
        (bus-write! bus #x21 #x80)
        (setf (cpu-y cpu) 1)
        (expect (cpu-step! cpu bus) :to-be 6)
        (expect (cpu-a cpu) :to-be #x5A)
        (expect (cpu-pc cpu) :to-be #x8002))))

  (it "wraps the high byte of an indirect jump within its page"
    (let* ((cartridge (make-fixture-cartridge
                       :program '(#x6C #xFF #x00)))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (bus-write! bus 0 #x12)
      (bus-write! bus #x00FF #x34)
      (expect (cpu-step! cpu bus) :to-be 5)
      (expect (cpu-pc cpu) :to-be #x1234))))
