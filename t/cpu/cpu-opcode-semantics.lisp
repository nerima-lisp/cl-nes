(in-package #:cl-nes/test)

(defmacro expect-cpu-semantic-state
    ((cpu bus &key a x y sp pc p cycles memory) &body setup)
  `(progn
     ,@setup
     (expect-cpu-step-cycles ,cpu ,bus ,cycles)
     ,@(remove nil (list (and a `(expect (cpu-a ,cpu) :to-be ,a))
                         (and x `(expect (cpu-x ,cpu) :to-be ,x))
                         (and y `(expect (cpu-y ,cpu) :to-be ,y))
                         (and sp `(expect (cpu-sp ,cpu) :to-be ,sp))
                         (and pc `(expect (cpu-pc ,cpu) :to-be ,pc))
                         (and p `(expect (cpu-p ,cpu) :to-be ,p))))
     ,@(mapcar (lambda (entry)
                 `(expect (bus-read ,bus ,(first entry)) :to-be ,(second entry)))
               memory)))

(defmacro expect-cpu-state (cpu bus &rest options)
  (let ((memory (getf options :memory))
        (state-options (loop for (key value) on options by #'cddr
                             unless (eq key :memory)
                             append (list key value))))
    `(progn
       (expect-cpu-semantic-state (,cpu ,bus ,@state-options))
       ,@(mapcar (lambda (entry)
                   `(expect (bus-read ,bus ,(first entry)) :to-be ,(second entry)))
                 memory))))

(describe "CPU opcode semantics"
  (it "loads immediate values and updates Z/N flags"
    (with-fixture-cpu-state (cpu bus :program (list #xA9 0) :p #x24)
      (expect-cpu-state cpu bus :a 0 :pc #x8002 :p #x26 :cycles 2))
    (with-fixture-cpu-state (cpu bus :program (list #xA2 #x80) :p #x24)
      (expect-cpu-state cpu bus :x #x80 :pc #x8002 :p #xA4 :cycles 2)))

  (it "stores through zero page without changing registers or flags"
    (with-fixture-cpu-state (cpu bus :program (list #x85 #x10)
                                      :a #x5A :x #x11 :y #x22 :p #xA4)
      (expect-cpu-state cpu bus :a #x5A :x #x11 :y #x22 :pc #x8002 :p #xA4
                        :cycles 3)
      (expect (bus-read bus #x10) :to-be #x5A)))

  (it "computes ADC and SBC carry/overflow boundaries in binary mode"
    (with-fixture-cpu-state (cpu bus :program (list #x69 #x50)
                                      :a #x50 :p #x24)
      (expect-cpu-state cpu bus :a #xA0 :pc #x8002 :p #xE4 :cycles 2))
    (with-fixture-cpu-state (cpu bus :program (list #x69 #x01)
                                      :a #xFF :p #x24)
      (expect-cpu-state cpu bus :a 0 :pc #x8002 :p #x27 :cycles 2))
    (with-fixture-cpu-state (cpu bus :program (list #xE9 1)
                                      :a 0 :p #x25)
      (expect-cpu-state cpu bus :a #xFF :pc #x8002 :p #xA4 :cycles 2)))

  (it "performs accumulator shifts and rotates through carry"
    (with-fixture-cpu-state (cpu bus :program (list #x0A)
                                      :a #x81 :p #x24)
      (expect-cpu-state cpu bus :a 2 :pc #x8001 :p #x25 :cycles 2))
    (with-fixture-cpu-state (cpu bus :program (list #x6A)
                                      :a 1 :p #x25)
      (expect-cpu-state cpu bus :a #x80 :pc #x8001 :p #xA5 :cycles 2)))

  (it "compares values and sets carry and zero exactly"
    (with-fixture-cpu-state (cpu bus :program (list #xC9 #x10)
                                      :a #x10 :p #x24)
      (expect-cpu-state cpu bus :a #x10 :pc #x8002 :p #x27 :cycles 2)))

  (it "pushes PHP with B and bit five set and restores PLP status"
    (with-fixture-cpu-state (cpu bus :program (list #x08) :p #xA5 :sp #xFD)
      (expect-cpu-state cpu bus :sp #xFC :p #xA5 :pc #x8001 :cycles 3)
      (expect (bus-read bus #x01FD) :to-be #xB5))
    (with-fixture-cpu-state (cpu bus :program (list #x28) :p #x24 :sp #xFC)
      (bus-write! bus #x01FD #xB5)
      (expect-cpu-state cpu bus :sp #xFD :p #xA5 :pc #x8001 :cycles 4)))

  (it "updates BIT N, V, and Z without changing A"
    (with-fixture-cpu-state (cpu bus :program (list #x24 #x40)
                                      :a #x3F :p #x24)
      (bus-write! bus #x0040 #xC0)
      (expect-cpu-state cpu bus :a #x3F :p #xE6 :pc #x8002 :cycles 3)))

  (it "uses branch timing for taken and not-taken branches"
    (with-fixture-cpu-state (cpu bus :program (list #xD0 2) :p #x24)
      (expect-cpu-state cpu bus :pc #x8004 :p #x24 :cycles 3))
    (with-fixture-cpu-state (cpu bus :program (list #xD0 2) :p #x26)
      (expect-cpu-state cpu bus :pc #x8002 :p #x26 :cycles 2)))

  (it "pushes the return address for JSR and restores it with RTS"
    (with-fixture-cpu-state (cpu bus :program (list #x20 #x05 #x80)
                                      :sp #xFD :p #x24)
      (expect-cpu-state cpu bus :sp #xFB :pc #x8005 :p #x24 :cycles 6
                        )
      (expect (bus-read bus #x01FD) :to-be #x80)
      (expect (bus-read bus #x01FC) :to-be #x02))
    (with-fixture-cpu-state (cpu bus :program (list #x60)
                                      :sp #xFB :p #x24)
      (bus-write! bus #x01FC #x02)
      (bus-write! bus #x01FD #x80)
      (expect-cpu-state cpu bus :sp #xFD :pc #x8003 :p #x24 :cycles 6)))

  (it "implements the NMOS JMP indirect page-wrap behavior"
    (with-fixture-cpu-state (cpu bus :program (list #x6C #xFF 0)
                                      :p #x24)
      (bus-write! bus #x00FF #x34)
      (bus-write! bus #x0000 #x12)
      (bus-write! bus #x0100 #x99)
      (expect-cpu-state cpu bus :pc #x1234 :p #x24 :cycles 5)))

  (it "executes representative unofficial combined operations"
    (with-fixture-cpu-state (cpu bus :program (list #xA7 #x10)
                                      :p #x24)
      (bus-write! bus #x10 #x7F)
      (expect-cpu-state cpu bus :a #x7F :x #x7F :pc #x8002 :p #x24 :cycles 3))
    (with-fixture-cpu-state (cpu bus :program (list #x87 #x10)
                                      :a #xCC :x #x0F :p #x24)
      (expect-cpu-state cpu bus :a #xCC :x #x0F :pc #x8002 :p #x24 :cycles 3
                        )
      (expect (bus-read bus #x10) :to-be #x0C))))
