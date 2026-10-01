(in-package #:cl-nes/test)

(describe "CPU opcode dispatch reachability (40-5F)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#x40 6) (#x41 6) (#x43 8) (#x44 3) (#x45 3) (#x46 5) (#x47 5)
     (#x48 3) (#x49 2) (#x4A 2) (#x4B 2) (#x4C 3) (#x4D 4) (#x4E 6) (#x4F 6)
     (#x50 2) (#x51 5) (#x53 8) (#x54 4) (#x55 4) (#x56 6) (#x57 6)
     (#x58 2) (#x59 4) (#x5A 2) (#x5B 7) (#x5C 4) (#x5D 4) (#x5E 7) (#x5F 7))))

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "RTI restores status and a little-endian PC"
  :program (#x40) :sp #xFA
  :writes ((#x01FB #xA5) (#x01FC #x78) (#x01FD #x56))
  :expected-a 0 :expected-x 0 :expected-y 0 :expected-sp #xFD
  :expected-p #xA5 :expected-pc #x5678 :cycles 6)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "PHA writes A to the current stack slot"
  :program (#x48) :a #xA6 :expected-a #xA6 :expected-x 0 :expected-y 0
  :expected-sp #xFC :expected-p #x24 :expected-pc #x8001
  :expected-memory ((#x01FD #xA6)) :cycles 3)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "PLA pulls A and sets the negative flag"
  :program (#x68) :sp #xFC :writes ((#x01FD #x80))
  :expected-a #x80 :expected-x 0 :expected-y 0 :expected-sp #xFD
  :expected-p #xA4 :expected-pc #x8001 :cycles 4)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "LSR zero-page writes zero and sets carry"
  :program (#x46 #x40) :writes ((#x0040 #x01))
  :expected-a 0 :expected-x 0 :expected-y 0 :expected-sp #xFD
  :expected-p #x25 :expected-pc #x8002 :expected-memory ((#x0040 0)) :cycles 5)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "BNE crosses a page with the extra branch cycle"
  :program (#xD0 #xFD) :start #x80FE :p 0 :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p 0 :expected-pc #x80FD :cycles 4)
