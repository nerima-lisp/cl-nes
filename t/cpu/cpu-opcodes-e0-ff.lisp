(in-package #:cl-nes/test)

(describe "CPU opcode dispatch reachability (E0-FF)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#xE0 2)
     (#xE1 6)
     (#xE2 2)
     (#xE3 8)
     (#xE4 3)
     (#xE5 3)
     (#xE6 5)
     (#xE7 5)
     (#xE8 2)
     (#xE9 2)
     (#xEA 2)
     (#xEB 2)
     (#xEC 4)
     (#xED 4)
     (#xEE 6)
     (#xEF 6)
     (#xF0 2)
     (#xF1 5)
     (#xF3 8)
     (#xF4 4)
     (#xF5 4)
     (#xF6 6)
     (#xF7 6)
     (#xF8 2)
     (#xF9 4)
     (#xFA 2)
     (#xFB 7)
     (#xFC 4)
     (#xFD 4)
     (#xFE 7)
     (#xFF 7))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (E0-FF)"
  (define-opcode-semantics-spec
    ((#xE0 (#xE0 #x40) #x00 #x80 #x00 #xFD #x24 () #x00 #x80 #x00 #xFD #x25 #x8002 () 2)
     (#xE1 (#xE1 #x10) #x50 #x00 #x00 #xFD #x25 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x20)) #x30 #x00 #x00 #xFD #x25 #x8002 () 6)
     (#xE2 (#xE2 #x55) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8002 () 2)
     (#xE3 (#xE3 #x10) #x50 #x00 #x00 #xFD #x25 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x01)) #x4E #x00 #x00 #xFD #x25 #x8002 ((#x0040 #x02)) 8)
     (#xE4 (#xE4 #x40) #x00 #x80 #x00 #xFD #x24 ((#x0040 #x40)) #x00 #x80 #x00 #xFD #x25 #x8002 () 3)
     (#xE5 (#xE5 #x40) #x50 #x00 #x00 #xFD #x25 ((#x0040 #x20)) #x30 #x00 #x00 #xFD #x25 #x8002 () 3)
     (#xE6 (#xE6 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x00)) #x00 #x00 #x00 #xFD #x24 #x8002 ((#x0040 #x01)) 5)
     (#xE7 (#xE7 #x40) #x50 #x00 #x00 #xFD #x25 ((#x0040 #x01)) #x4E #x00 #x00 #xFD #x25 #x8002 ((#x0040 #x02)) 5)
     (#xE8 (#xE8) #x00 #xFF #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x26 #x8001 () 2)
     (#xE9 (#xE9 #x20) #x50 #x00 #x00 #xFD #x25 () #x30 #x00 #x00 #xFD #x25 #x8002 () 2)
     (#xEA (#xEA) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8001 () 2)
     (#xEB (#xEB #x20) #x50 #x00 #x00 #xFD #x25 () #x30 #x00 #x00 #xFD #x25 #x8002 () 2)
     (#xEC (#xEC #x40 #x00) #x00 #x80 #x00 #xFD #x24 ((#x0040 #x40)) #x00 #x80 #x00 #xFD #x25 #x8003 () 4)
     (#xED (#xED #x40 #x00) #x50 #x00 #x00 #xFD #x25 ((#x0040 #x20)) #x30 #x00 #x00 #xFD #x25 #x8003 () 4)
     (#xEE (#xEE #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x00)) #x00 #x00 #x00 #xFD #x24 #x8003 ((#x0040 #x01)) 6)
     (#xEF (#xEF #x40 #x00) #x50 #x00 #x00 #xFD #x25 ((#x0040 #x01)) #x4E #x00 #x00 #xFD #x25 #x8003 ((#x0040 #x02)) 6)
     (#xF0 (#xF0 #x02) #x00 #x00 #x00 #xFD #x26 () #x00 #x00 #x00 #xFD #x26 #x8004 () 3)
     (#xF1 (#xF1 #x10) #x50 #x00 #x00 #xFD #x25 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x20)) #x30 #x00 #x00 #xFD #x25 #x8002 () 5)
     (#xF3 (#xF3 #x10) #x50 #x00 #x00 #xFD #x25 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x01)) #x4E #x00 #x00 #xFD #x25 #x8002 ((#x0040 #x02)) 8)
     (#xF4 (#xF4 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #xAA)) #x00 #x01 #x00 #xFD #x24 #x8002 () 4)
     (#xF5 (#xF5 #x40) #x50 #x01 #x00 #xFD #x25 ((#x0041 #x20)) #x30 #x01 #x00 #xFD #x25 #x8002 () 4)
     (#xF6 (#xF6 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x00)) #x00 #x01 #x00 #xFD #x24 #x8002 ((#x0041 #x01)) 6)
     (#xF7 (#xF7 #x40) #x50 #x01 #x00 #xFD #x25 ((#x0041 #x01)) #x4E #x01 #x00 #xFD #x25 #x8002 ((#x0041 #x02)) 6)
     (#xF8 (#xF8) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x2C #x8001 () 2)
     (#xF9 (#xF9 #x40 #x00) #x50 #x00 #x01 #xFD #x25 ((#x0041 #x20)) #x30 #x00 #x01 #xFD #x25 #x8003 () 4)
     (#xFA (#xFA) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8001 () 2)
     (#xFB (#xFB #x40 #x00) #x50 #x00 #x01 #xFD #x25 ((#x0041 #x01)) #x4E #x00 #x01 #xFD #x25 #x8003 ((#x0041 #x02)) 7)
     (#xFC (#xFC #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #xAA)) #x00 #x01 #x00 #xFD #x24 #x8003 () 4)
     (#xFD (#xFD #x40 #x00) #x50 #x01 #x00 #xFD #x25 ((#x0041 #x20)) #x30 #x01 #x00 #xFD #x25 #x8003 () 4)
     (#xFE (#xFE #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x00)) #x00 #x01 #x00 #xFD #x24 #x8003 ((#x0041 #x01)) 7)
     (#xFF (#xFF #x40 #x00) #x50 #x01 #x00 #xFD #x25 ((#x0041 #x01)) #x4E #x01 #x00 #xFD #x25 #x8003 ((#x0041 #x02)) 7))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (E0-FF)"
  (it-each
      ((:opcode #xE0 :operands (#x40) :initial-a #x11 :initial-x #x40
        :initial-y #x22 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x40 :expected-y #x22 :expected-sp #xFD
        :expected-p #x27 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xE9 :operands (#x10) :initial-a #x30 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x25
        :expected-a #x20 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x25 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xE9 :operands (#x20) :initial-a #x10 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #xF0 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xE6 :operands (#x10) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0010 :memory-before #xFF
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8002 :expected-memory #x00
        :expected-cycles 5)
       (:opcode #xE7 :operands (#x10) :initial-a #x10 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x25
        :memory-address #x0010 :memory-before #x01
        :expected-a #x0E :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x25 :expected-pc #x8002 :expected-memory #x02
        :expected-cycles 5)
       (:opcode #xE8 :operands () :initial-a #x11 :initial-x #xFF
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x00 :expected-y #x33 :expected-sp #xFD
        :expected-p #x26 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xF0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x26
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x26 :expected-pc #x8004 :expected-cycles 3)
       (:opcode #xF0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xF8 :operands () :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x2C :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xFA :operands () :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #xA4
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xFF :operands (#xFF #x02) :initial-a #x10 :initial-x #x22
        :initial-y #x01 :initial-sp #xFD :initial-p #x25
        :memory-address #x0300 :memory-before #x0F
        :expected-a #x01 :expected-x #x22 :expected-y #x01 :expected-sp #xFD
        :expected-p #x25 :expected-pc #x8003 :expected-memory #x10
        :expected-cycles 7))
      "executes a hand-calculated 6502 register and memory case"
    (&rest case)
    (run-cpu-semantic-case case)))
