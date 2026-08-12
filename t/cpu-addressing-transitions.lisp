(in-package #:cl-nes/test)

(describe "CPU addressing transitions"
  (describe "indexed reads"
    (let (cpu bus cartridge)
      (describe "absolute,X addressing"
        (before-each
          (setf cartridge (make-fixture-cartridge
                           :program '(#xBD #x10 #x80 #xBD #xFF #x80))
                bus (make-bus :cartridge cartridge)
                cpu (make-cpu))
          (cpu-reset! cpu bus)
          (setf (aref (cartridge-prg-rom cartridge) #x12) #x33
                (aref (cartridge-prg-rom cartridge) #x101) #x44
                (cpu-x cpu) 2))
        (it "uses the base cycle count when the indexed read stays on-page"
          (expect (cpu-step! cpu bus) :to-be 4)
          (expect (cpu-a cpu) :to-be #x33)
          (expect (cpu-pc cpu) :to-be #x8003))
        (it "adds a cycle when the indexed read crosses a page"
          (cpu-step! cpu bus)
          (expect (cpu-step! cpu bus) :to-be 5)
          (expect (cpu-a cpu) :to-be #x44)
          (expect (cpu-pc cpu) :to-be #x8006)))

      (describe "absolute,Y addressing"
        (before-each
          (setf cartridge (make-fixture-cartridge :program '(#xB9 #xFF #x80))
                bus (make-bus :cartridge cartridge)
                cpu (make-cpu))
          (cpu-reset! cpu bus)
          (setf (aref (cartridge-prg-rom cartridge) #x100) #xA5
                (cpu-y cpu) 1))
        (it "adds a cycle on a page-crossing indexed read"
          (expect (cpu-step! cpu bus) :to-be 5)
          (expect (cpu-a cpu) :to-be #xA5)
          (expect (cpu-pc cpu) :to-be #x8003)))

      (describe "indirect,Y addressing"
        (before-each
          (setf cartridge (make-fixture-cartridge :program '(#xB1 #x20))
                bus (make-bus :cartridge cartridge)
                cpu (make-cpu))
          (cpu-reset! cpu bus)
          (setf (aref (cartridge-prg-rom cartridge) #x100) #x5A
                (cpu-y cpu) 1)
          (bus-write! bus #x20 #xFF)
          (bus-write! bus #x21 #x80))
        (it "adds a cycle when the indirect target crosses a page"
          (expect (cpu-step! cpu bus) :to-be 6)
          (expect (cpu-a cpu) :to-be #x5A)
          (expect (cpu-pc cpu) :to-be #x8002)))))

  (describe "indirect jump"
    (let (cpu bus cartridge)
      (before-each
        (setf cartridge (make-fixture-cartridge :program '(#x6C #xFF #x00))
              bus (make-bus :cartridge cartridge)
              cpu (make-cpu))
        (cpu-reset! cpu bus)
        (bus-write! bus 0 #x12)
        (bus-write! bus #x00FF #x34))
      (it "wraps the high byte of an indirect jump within its page"
        (expect (cpu-step! cpu bus) :to-be 5)
        (expect (cpu-pc cpu) :to-be #x1234))))

  (describe "indexed writes"
    (let (cpu bus cartridge)
      (before-each
        (setf cartridge (make-fixture-cartridge :program '(#x9D #xFF #x5F))
              bus (make-bus :cartridge cartridge)
              cpu (make-cpu))
        (cpu-reset! cpu bus)
        (setf (cpu-a cpu) #x5A
              (cpu-x cpu) 1))
      (it "keeps indexed writes at their fixed cycle cost across page crossings"
        (expect (cpu-step! cpu bus) :to-be 5)
        (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #x5A)
        (expect (cpu-pc cpu) :to-be #x8003)))))
