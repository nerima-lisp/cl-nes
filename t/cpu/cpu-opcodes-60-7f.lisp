(in-package #:cl-nes/test)

(describe "CPU opcode dispatch (60-7F)"
  (define-opcode-dispatch-spec
      "dispatches opcode #x~2,'0X in ~D cycles"
    ((#x60 6) (#x61 6) (#x63 8) (#x64 3) (#x65 3) (#x66 5) (#x67 5)
     (#x68 4) (#x69 2) (#x6A 2) (#x6B 2) (#x6C 5) (#x6D 4) (#x6E 6) (#x6F 6)
     (#x70 2) (#x71 5) (#x73 8) (#x74 4) (#x75 4) (#x76 6) (#x77 6)
     (#x78 2) (#x79 4) (#x7A 2) (#x7B 7) (#x7C 4) (#x7D 4) (#x7E 7) (#x7F 7))))

(define-cpu-semantic-case "RTS pulls the return address and resumes at PC+1"
  :program (#x60) :sp #xFB :writes ((#x01FC #x34) (#x01FD #x12))
  :expected-a 0 :expected-x 0 :expected-y 0 :expected-sp #xFD
  :expected-p #x24 :expected-pc #x1235
  :expected-memory ((#x01FC #x34) (#x01FD #x12)) :cycles 6)

(define-cpu-semantic-case "ROR accumulator shifts carry into bit seven"
  :program (#x6A) :a 1 :p #x25 :expected-a #x80 :expected-x 0 :expected-y 0
  :expected-sp #xFD :expected-p #xA5 :expected-pc #x8001 :cycles 2)

(define-cpu-semantic-case "ADC immediate produces a binary sum and carry"
  :program (#x69 #x91) :a #x7F :p #x25 :expected-a #x11 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p #x25 :expected-pc #x8002 :cycles 2)

(define-cpu-semantic-case "ROR zero-page writes the shifted byte"
  :program (#x66 #x40) :writes ((#x0040 #x02)) :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p #x24 :expected-pc #x8002
  :expected-memory ((#x0040 1)) :cycles 5)

(it "JMP indirect wraps the high-byte lookup within its page"
  (with-fixture-cpu-state (cpu bus :program '(#x6C #xFF #x00))
    (bus-write! bus #x00FF #x34)
    (bus-write! bus #x0000 #x12)
    (expect (cpu-step! cpu bus) :to-be 5)
    (expect (list (cpu-pc cpu) (cpu-sp cpu) (cpu-p cpu) (cpu-cycles cpu))
            :to-equal (list #x1234 #xFD #x24 12))))

(define-cpu-semantic-case "LDA indirect-Y pays one cycle for a page crossing"
  :program (#xB1 #xFF) :y 1 :writes ((#x00FF #xFF) (#x0000 #x00) (#x0100 #xA5))
  :expected-a #xA5 :expected-x 0 :expected-y 1 :expected-sp #xFD
  :expected-p #xA4 :expected-pc #x8002 :expected-memory ((#x0100 #xA5))
  :cycles 6)

(define-cpu-semantic-case "BVS crosses a page with both branch penalties"
  :program (#x70 #xFE) :start #x80FE :p #x40 :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p #x40 :expected-pc #x80FE :cycles 4)
