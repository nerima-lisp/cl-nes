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
      (expect (cpu-pc cpu) :to-be #x1234)))

  (it "performs the opcode-table NOP reads, including indexed page crossing"
    (dolist (case '(((#x80 #x82 #x89 #xC2 #xE2) (0) 2
                     (#x8000 #x8001))
                    ((#x04 #x44 #x64) (16) 3
                     (#x8000 #x8001 #x0010))
                    ((#x14 #x34 #x54 #x74 #xD4 #xF4) (16) 4
                     (#x8000 #x8001 #x0010 #x0010))
                    ((#x0C) (#x34 #x12) 4
                     (#x8000 #x8001 #x8002 #x1234))
                    ((#x1C #x3C #x5C #x7C #xDC #xFC) (#xFF #x12) 5
                     (#x8000 #x8001 #x8002 #x1200 #x1300))))
      (destructuring-bind (opcodes operand expected-cycles expected-addresses)
          case
        (dolist (opcode opcodes)
          (let* ((cartridge (make-fixture-cartridge
                             :program (list* opcode operand)))
                 (bus (make-bus :cartridge cartridge))
                 (cpu (make-cpu))
                 (addresses '()))
            (cpu-reset! cpu bus)
            (setf (cpu-x cpu) (if (member opcode '(#x1C #x3C #x5C #x7C #xDC #xFC))
                                  1
                                  0)
                  (cl-nes::bus-cpu-access-hook bus)
                  (lambda ()
                    (push (cl-nes::bus-last-cpu-access-address bus)
                          addresses)))
            (expect (cpu-step! cpu bus) :to-be expected-cycles)
            (expect (equal (nreverse addresses) expected-addresses)
                    :to-be t)))))))
