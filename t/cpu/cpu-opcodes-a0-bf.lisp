(in-package #:cl-nes/test)

(defmacro define-opcode-semantics-spec (cases)
  `(it-each ,cases
       "executes opcode #x~2,'0X with independent 6502 state expectations"
       (opcode program a x y sp p writes expected-a expected-x expected-y
        expected-sp expected-p expected-pc expected-writes expected-cycles)
     (with-fixture-cpu-state (cpu bus :program program
                                  :a a :x x :y y :sp sp :p p)
       (dolist (write writes)
         (bus-write! bus (first write) (second write)))
       (expect-cpu-step-cycles cpu bus expected-cycles)
       (expect (cpu-a cpu) :to-be expected-a)
       (expect (cpu-x cpu) :to-be expected-x)
       (expect (cpu-y cpu) :to-be expected-y)
       (expect (cpu-sp cpu) :to-be expected-sp)
       (expect (cpu-p cpu) :to-be expected-p)
       (expect (cpu-pc cpu) :to-be expected-pc)
       (dolist (write expected-writes)
         (expect (bus-read bus (first write)) :to-be (second write))))))

(describe "CPU opcode dispatch reachability (A0-BF)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#xA0 2)
     (#xA1 6)
     (#xA2 2)
     (#xA3 6)
     (#xA4 3)
     (#xA5 3)
     (#xA6 3)
     (#xA7 3)
     (#xA8 2)
     (#xA9 2)
     (#xAA 2)
     (#xAB 2)
     (#xAC 4)
     (#xAD 4)
     (#xAE 4)
     (#xAF 4)
     (#xB0 2)
     (#xB1 5)
     (#xB3 5)
     (#xB4 4)
     (#xB5 4)
     (#xB6 4)
     (#xB7 4)
     (#xB8 2)
     (#xB9 4)
     (#xBA 2)
     (#xBC 4)
     (#xBD 4)
     (#xBE 4)
     (#xBF 4))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (A0-BF)"
  (define-opcode-semantics-spec
    ((#xA0 (#xA0 #x80) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x80 #xFD #xA4 #x8002 () 2)
     (#xA1 (#xA1 #x10) #x00 #x01 #x00 #xFD #x24 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x80)) #x80 #x01 #x00 #xFD #xA4 #x8002 () 6)
     (#xA2 (#xA2 #x00) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x26 #x8002 () 2)
     (#xA3 (#xA3 #x10) #x00 #x01 #x00 #xFD #x24 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x80)) #x80 #x80 #x00 #xFD #xA4 #x8002 () 6)
     (#xA4 (#xA4 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x7F)) #x00 #x00 #x7F #xFD #x24 #x8002 () 3)
     (#xA5 (#xA5 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x80 #x00 #x00 #xFD #xA4 #x8002 () 3)
     (#xA6 (#xA6 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x00 #x80 #x00 #xFD #xA4 #x8002 () 3)
     (#xA7 (#xA7 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x80 #x80 #x00 #xFD #xA4 #x8002 () 3)
     (#xA8 (#xA8) #x80 #x00 #x00 #xFD #x24 () #x80 #x00 #x80 #xFD #xA4 #x8001 () 2)
     (#xA9 (#xA9 #x00) #x80 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x26 #x8002 () 2)
     (#xAA (#xAA) #x80 #x00 #x00 #xFD #x24 () #x80 #x80 #x00 #xFD #xA4 #x8001 () 2)
     (#xAB (#xAB #x80) #x00 #x00 #x00 #xFD #x24 () #x80 #x80 #x00 #xFD #xA4 #x8002 () 2)
     (#xAC (#xAC #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x7F)) #x00 #x00 #x7F #xFD #x24 #x8003 () 4)
     (#xAD (#xAD #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x80 #x00 #x00 #xFD #xA4 #x8003 () 4)
     (#xAE (#xAE #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x00 #x80 #x00 #xFD #xA4 #x8003 () 4)
     (#xAF (#xAF #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x80)) #x80 #x80 #x00 #xFD #xA4 #x8003 () 4)
     (#xB0 (#xB0 #x02) #x00 #x00 #x00 #xFD #x25 () #x00 #x00 #x00 #xFD #x25 #x8004 () 3)
     (#xB1 (#xB1 #x10) #x00 #x00 #x00 #xFD #x24 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x7F)) #x7F #x00 #x00 #xFD #x24 #x8002 () 5)
     (#xB3 (#xB3 #x10) #x00 #x00 #x00 #xFD #x24 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x7F)) #x7F #x7F #x00 #xFD #x24 #x8002 () 5)
     (#xB4 (#xB4 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x80)) #x80 #x01 #x00 #xFD #xA4 #x8002 () 4)
     (#xB5 (#xB5 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x80)) #x80 #x01 #x00 #xFD #xA4 #x8002 () 4)
     (#xB6 (#xB6 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x80)) #x00 #x80 #x00 #xFD #xA4 #x8002 () 4)
     (#xB7 (#xB7 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x80)) #x80 #x80 #x00 #xFD #xA4 #x8002 () 4)
     (#xB8 (#xB8) #x00 #x00 #x00 #xFD #x44 () #x00 #x00 #x00 #xFD #x24 #x8001 () 2)
     (#xB9 (#xB9 #x40 #x00) #x00 #x00 #x01 #xFD #x24 ((#x0041 #x7F)) #x7F #x00 #x01 #xFD #x24 #x8003 () 4)
     (#xBA (#xBA) #x00 #x00 #x00 #x80 #x24 () #x00 #x80 #x00 #x80 #xA4 #x8001 () 2)
     (#xBC (#xBC #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x7F)) #x00 #x01 #x7F #xFD #x24 #x8003 () 4)
     (#xBD (#xBD #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x80)) #x80 #x01 #x00 #xFD #xA4 #x8003 () 4)
     (#xBE (#xBE #x40 #x00) #x00 #x00 #x01 #xFD #x24 ((#x0041 #x80)) #x00 #x80 #x01 #xFD #xA4 #x8003 () 4)
     (#xBF (#xBF #x40 #x00) #x00 #x00 #x01 #xFD #x24 ((#x0041 #x80)) #x80 #x80 #x01 #xFD #xA4 #x8003 () 4))))

(defun run-cpu-semantic-case (case)
  (destructuring-bind
      (&key opcode operands initial-a initial-x initial-y initial-sp initial-p
            memory-address memory-before expected-a expected-x expected-y
            expected-sp expected-p expected-pc expected-memory expected-cycles)
      case
    (with-fixture-cpu-state (cpu bus
                             :program (list* opcode operands)
                             :a initial-a :x initial-x :y initial-y
                             :sp initial-sp :p initial-p)
      (when memory-address
        (bus-write! bus memory-address memory-before))
      (expect (cpu-step! cpu bus) :to-be expected-cycles)
      (expect (cpu-a cpu) :to-be expected-a)
      (expect (cpu-x cpu) :to-be expected-x)
      (expect (cpu-y cpu) :to-be expected-y)
      (expect (cpu-sp cpu) :to-be expected-sp)
      (expect (cpu-pc cpu) :to-be expected-pc)
      (expect (cpu-p cpu) :to-be expected-p)
      (when memory-address
        (expect (bus-read bus memory-address) :to-be expected-memory)))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (A0-BF)"
  (it-each
      ((:opcode #xA0 :operands (#x80) :initial-a #x11 :initial-x #x22
        :initial-y #x00 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x80 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xA2 :operands (#x00) :initial-a #x11 :initial-x #x80
        :initial-y #x22 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x00 :expected-y #x22 :expected-sp #xFD
        :expected-p #x26 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xAD :operands (#x00 #x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0200 :memory-before #x3C
        :expected-a #x3C :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8003 :expected-memory #x3C
        :expected-cycles 4)
       (:opcode #xB9 :operands (#xFF #x02) :initial-a #x11 :initial-x #x22
        :initial-y #x01 :initial-sp #xFD :initial-p #x24
        :memory-address #x0300 :memory-before #x80
        :expected-a #x80 :expected-x #x22 :expected-y #x01 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8003 :expected-memory #x80
        :expected-cycles 5)
       (:opcode #xAF :operands (#x00 #x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0200 :memory-before #x5A
        :expected-a #x5A :expected-x #x5A :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8003 :expected-memory #x5A
        :expected-cycles 4)
       (:opcode #x85 :operands (#x10) :initial-a #xA5 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0010 :memory-before #x00
        :expected-a #xA5 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8002 :expected-memory #xA5
        :expected-cycles 3)
       (:opcode #x87 :operands (#x10) :initial-a #xF0 :initial-x #x3C
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0010 :memory-before #x00
        :expected-a #xF0 :expected-x #x3C :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8002 :expected-memory #x30
        :expected-cycles 3)
       (:opcode #xBA :operands () :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #x80 :initial-p #x24
        :expected-a #x11 :expected-x #x80 :expected-y #x33 :expected-sp #x80
        :expected-p #xA4 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #x9A :operands () :initial-a #x11 :initial-x #x42
        :initial-y #x33 :initial-sp #xFD :initial-p #xA4
        :expected-a #x11 :expected-x #x42 :expected-y #x33 :expected-sp #x42
        :expected-p #xA4 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xB0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x25
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x25 :expected-pc #x8004 :expected-cycles 3)
       (:opcode #xB0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xBB :operands (#x00 #x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xF0 :initial-p #x24
        :memory-address #x0200 :memory-before #xA5
        :expected-a #xA0 :expected-x #xA0 :expected-y #x33 :expected-sp #xA0
        :expected-p #xA4 :expected-pc #x8003 :expected-memory #xA5
        :expected-cycles 4))
      "executes a hand-calculated 6502 register and memory case"
    (&rest case)
    (run-cpu-semantic-case case)))
