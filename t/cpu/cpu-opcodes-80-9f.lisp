(in-package #:cl-nes/test)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "LDA immediate sets N for a negative value"
  :program (#xA9 #x80) :p 0 :expected-a #x80 :expected-x 0 :expected-y 0
  :expected-sp #xFD :expected-p #x80 :expected-pc #x8002 :cycles 2)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "LDX zero-page loads zero and sets Z"
  :program (#xA6 #x40) :p #x80 :writes ((#x0040 0)) :expected-a 0
  :expected-x 0 :expected-y 0 :expected-sp #xFD :expected-p #x02
  :expected-pc #x8002 :expected-memory ((#x0040 0)) :cycles 3)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "STA absolute-X stores A at the indexed address"
  :program (#x9D #xFF #x01) :a #x5A :x 1 :expected-a #x5A :expected-x 1
  :expected-y 0 :expected-sp #xFD :expected-p #x24 :expected-pc #x8003
  :expected-memory ((#x0200 #x5A)) :cycles 5)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "STA zero-page-X wraps at FF"
  :program (#x95 #xFF) :a #x66 :x 1 :expected-a #x66 :expected-x 1
  :expected-y 0 :expected-sp #xFD :expected-p #x24 :expected-pc #x8002
  :expected-memory ((#x0000 #x66)) :cycles 4)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "LDA indirect-Y wraps pointer high byte and page-crosses"
  :program (#xB1 #xFF) :y 1 :writes ((#x00FF #xFF) (#x0000 #x00) (#x0100 #xA5))
  :expected-a #xA5 :expected-x 0 :expected-y 1 :expected-sp #xFD
  :expected-p #xA4 :expected-pc #x8002 :expected-memory ((#x0100 #xA5))
  :cycles 6)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "BCC takes a forward branch when carry is clear"
  :program (#x90 #x02 #xEA #xEA) :p 0 :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p 0 :expected-pc #x8004 :cycles 3)
