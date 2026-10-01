(in-package #:cl-nes/test)

(describe "CPU opcode dispatch reachability (C0-DF)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#xC0 2)
     (#xC1 6)
     (#xC2 2)
     (#xC3 8)
     (#xC4 3)
     (#xC5 3)
     (#xC6 5)
     (#xC7 5)
     (#xC8 2)
     (#xC9 2)
     (#xCA 2)
     (#xCB 2)
     (#xCC 4)
     (#xCD 4)
     (#xCE 6)
     (#xCF 6)
     (#xD0 3)
     (#xD1 5)
     (#xD3 8)
     (#xD4 4)
     (#xD5 4)
     (#xD6 6)
     (#xD7 6)
     (#xD8 2)
     (#xD9 4)
     (#xDA 2)
     (#xDB 7)
     (#xDC 4)
     (#xDD 4)
     (#xDE 7)
     (#xDF 7))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (C0-DF)"
  (define-opcode-semantics-spec
    ((#xC0 (#xC0 #x40) #x00 #x00 #x80 #xFD #x24 () #x00 #x00 #x80 #xFD #x25 #x8002 () 2)
     (#xC1 (#xC1 #x10) #x80 #x00 #x00 #xFD #x24 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x80)) #x80 #x00 #x00 #xFD #x27 #x8002 () 6)
     (#xC2 (#xC2 #x55) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8002 () 2)
     (#xC3 (#xC3 #x10) #x00 #x00 #x00 #xFD #x24 ((#x0011 #x40) (#x0012 #x00) (#x0040 #x01)) #x00 #x00 #x00 #xFD #x27 #x8002 ((#x0040 #x00)) 8)
     (#xC4 (#xC4 #x40) #x00 #x00 #x80 #xFD #x24 ((#x0040 #x40)) #x00 #x00 #x80 #xFD #x25 #x8002 () 3)
     (#xC5 (#xC5 #x40) #x80 #x00 #x00 #xFD #x24 ((#x0040 #x40)) #x80 #x00 #x00 #xFD #x25 #x8002 () 3)
     (#xC6 (#xC6 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x00)) #x00 #x00 #x00 #xFD #x24 #x8002 ((#x0040 #xFF)) 5)
     (#xC7 (#xC7 #x40) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x01)) #x00 #x00 #x00 #xFD #x27 #x8002 ((#x0040 #x00)) 5)
     (#xC8 (#xC8) #x00 #x00 #xFF #xFD #x24 () #x00 #x00 #x00 #xFD #x26 #x8001 () 2)
     (#xC9 (#xC9 #x80) #x80 #x00 #x00 #xFD #x24 () #x80 #x00 #x00 #xFD #x27 #x8002 () 2)
     (#xCA (#xCA) #x00 #x00 #x00 #xFD #x24 () #x00 #xFF #x00 #xFD #xA4 #x8001 () 2)
     (#xCB (#xCB #x01) #xF0 #x0F #x00 #xFD #x24 () #xF0 #x0E #x00 #xFD #x25 #x8002 () 2)
     (#xCC (#xCC #x40 #x00) #x00 #x00 #x80 #xFD #x24 ((#x0040 #x40)) #x00 #x00 #x80 #xFD #x25 #x8003 () 4)
     (#xCD (#xCD #x40 #x00) #x80 #x00 #x00 #xFD #x24 ((#x0040 #x40)) #x80 #x00 #x00 #xFD #x25 #x8003 () 4)
     (#xCE (#xCE #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x00)) #x00 #x00 #x00 #xFD #x24 #x8003 ((#x0040 #xFF)) 6)
     (#xCF (#xCF #x40 #x00) #x00 #x00 #x00 #xFD #x24 ((#x0040 #x01)) #x00 #x00 #x00 #xFD #x27 #x8003 ((#x0040 #x00)) 6)
     (#xD0 (#xD0 #x02) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8004 () 3)
     (#xD1 (#xD1 #x10) #x80 #x00 #x00 #xFD #x24 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x40)) #x80 #x00 #x00 #xFD #x25 #x8002 () 5)
     (#xD3 (#xD3 #x10) #x00 #x00 #x00 #xFD #x24 ((#x0010 #x40) (#x0011 #x00) (#x0040 #x01)) #x00 #x00 #x00 #xFD #x27 #x8002 ((#x0040 #x00)) 8)
     (#xD4 (#xD4 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #xAA)) #x00 #x01 #x00 #xFD #x24 #x8002 () 4)
     (#xD5 (#xD5 #x40) #x80 #x01 #x00 #xFD #x24 ((#x0041 #x40)) #x80 #x01 #x00 #xFD #x25 #x8002 () 4)
     (#xD6 (#xD6 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x00)) #x00 #x01 #x00 #xFD #x24 #x8002 ((#x0041 #xFF)) 6)
     (#xD7 (#xD7 #x40) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x01)) #x00 #x01 #x00 #xFD #x27 #x8002 ((#x0041 #x00)) 6)
     (#xD8 (#xD8) #x00 #x00 #x00 #xFD #x2C () #x00 #x00 #x00 #xFD #x24 #x8001 () 2)
     (#xD9 (#xD9 #x40 #x00) #x80 #x00 #x01 #xFD #x24 ((#x0041 #x40)) #x80 #x00 #x01 #xFD #x25 #x8003 () 4)
     (#xDA (#xDA) #x00 #x00 #x00 #xFD #x24 () #x00 #x00 #x00 #xFD #x24 #x8001 () 2)
     (#xDB (#xDB #x40 #x00) #x00 #x00 #x01 #xFD #x24 ((#x0041 #x01)) #x00 #x00 #x01 #xFD #x27 #x8003 ((#x0041 #x00)) 7)
     (#xDC (#xDC #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #xAA)) #x00 #x01 #x00 #xFD #x24 #x8003 () 4)
     (#xDD (#xDD #x40 #x00) #x80 #x01 #x00 #xFD #x24 ((#x0041 #x40)) #x80 #x01 #x00 #xFD #x25 #x8003 () 4)
     (#xDE (#xDE #x40 #x00) #x00 #x01 #x00 #xFD #x24 ((#x0041 #x00)) #x00 #x01 #x00 #xFD #x24 #x8003 ((#x0041 #xFF)) 7)
     (#xDF (#xDF #x40 #x00) #x00 #x00 #x01 #xFD #x24 ((#x0041 #x01)) #x00 #x00 #x01 #xFD #x27 #x8003 ((#x0041 #x00)) 7))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (C0-DF)"
  (it-each
      ((:opcode #xC0 :operands (#x40) :initial-a #x11 :initial-x #x22
        :initial-y #x40 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x40 :expected-sp #xFD
        :expected-p #x27 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xC9 :operands (#x20) :initial-a #x10 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x10 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xC6 :operands (#x10) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0010 :memory-before #x01
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x27 :expected-pc #x8002 :expected-memory #x00
        :expected-cycles 5)
       (:opcode #xC7 :operands (#x10) :initial-a #x00 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0010 :memory-before #x01
        :expected-a #x00 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x27 :expected-pc #x8002 :expected-memory #x00
        :expected-cycles 5)
       (:opcode #xC8 :operands () :initial-a #x11 :initial-x #x22
        :initial-y #xFF :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x00 :expected-sp #xFD
        :expected-p #x26 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xCA :operands () :initial-a #x11 :initial-x #x00
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #xFF :expected-y #x33 :expected-sp #xFD
        :expected-p #xA4 :expected-pc #x8001 :expected-cycles 2)
       (:opcode #xD4 :operands (#x10) :initial-a #x11 :initial-x #x01
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0011 :memory-before #xA5
        :expected-a #x11 :expected-x #x01 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8002 :expected-memory #xA5
        :expected-cycles 4)
       (:opcode #xD0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8004 :expected-cycles 3)
       (:opcode #xD0 :operands (#x02) :initial-a #x11 :initial-x #x22
        :initial-y #x33 :initial-sp #xFD :initial-p #x26
        :expected-a #x11 :expected-x #x22 :expected-y #x33 :expected-sp #xFD
        :expected-p #x26 :expected-pc #x8002 :expected-cycles 2)
       (:opcode #xDB :operands (#x00 #x02) :initial-a #x10 :initial-x #x22
        :initial-y #x01 :initial-sp #xFD :initial-p #x24
        :memory-address #x0201 :memory-before #x05
        :expected-a #x10 :expected-x #x22 :expected-y #x01 :expected-sp #xFD
        :expected-p #x25 :expected-pc #x8003 :expected-memory #x04
        :expected-cycles 7)
       (:opcode #xDC :operands (#xFF #x02) :initial-a #x11 :initial-x #x01
        :initial-y #x33 :initial-sp #xFD :initial-p #x24
        :memory-address #x0300 :memory-before #xA5
        :expected-a #x11 :expected-x #x01 :expected-y #x33 :expected-sp #xFD
        :expected-p #x24 :expected-pc #x8003 :expected-memory #xA5
        :expected-cycles 5))
      "executes a hand-calculated 6502 register and memory case"
    (&rest case)
    (run-cpu-semantic-case case)))
