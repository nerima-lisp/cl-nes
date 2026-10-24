(in-package #:cl-nes/test)

(describe "CPU opcode dispatch (80-9F)"
  (define-opcode-dispatch-spec
      "dispatches opcode #x~2,'0X in ~D cycles"
    ((#x80 2) (#x81 6) (#x82 2) (#x83 6) (#x84 3) (#x85 3) (#x86 3) (#x87 3)
     (#x88 2) (#x89 2) (#x8A 2) (#x8C 4) (#x8D 4) (#x8E 4) (#x8F 4)
     (#x90 3) (#x91 6) (#x94 4) (#x95 4) (#x96 4) (#x97 4) (#x98 2)
     (#x99 5) (#x9A 2) (#x9C 5) (#x9D 5) (#x9E 5)))
  (it "reads $4015 on the indexed-store dummy cycle"
    (with-fixture-cpu-system
        (cpu bus :program (list #x9C #x18 #x40))
      (setf (cpu-x cpu) #xFD
            (cpu-y cpu) #xFF
            (cl-nes::apu-frame-irq-pending-p (cl-nes::bus-apu bus)) t)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (cl-nes::apu-frame-irq-pending-p
               (cl-nes::bus-apu bus))
              :to-be nil))
    (with-fixture-cpu-system
        (cpu bus :program (list #x9B #x18 #x40))
      (setf (cpu-a cpu) #xFF
            (cpu-x cpu) #xFF
            (cpu-y cpu) #xFD
            (cl-nes::apu-frame-irq-pending-p (cl-nes::bus-apu bus)) t)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (cl-nes::apu-frame-irq-pending-p
               (cl-nes::bus-apu bus))
              :to-be nil))
    (with-fixture-cpu-system
        (cpu bus :program (list #x9E #x18 #x40))
      (setf (cpu-x cpu) #xFF
            (cpu-y cpu) #xFD
            (cl-nes::apu-frame-irq-pending-p (cl-nes::bus-apu bus)) t)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (cl-nes::apu-frame-irq-pending-p
               (cl-nes::bus-apu bus))
              :to-be nil))
    (with-fixture-cpu-system
        (cpu bus :program (list #x9F #x18 #x40))
      (setf (cpu-a cpu) #xFF
            (cpu-x cpu) #xFF
            (cpu-y cpu) #xFD
            (cl-nes::apu-frame-irq-pending-p (cl-nes::bus-apu bus)) t)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (cl-nes::apu-frame-irq-pending-p
               (cl-nes::bus-apu bus))
              :to-be nil))
    (with-fixture-cpu-system
        (cpu bus :program (list #x93 #x00))
      (bus-write! bus #x0000 #x18)
      (bus-write! bus #x0001 #x40)
      (setf (cpu-a cpu) #xFF
            (cpu-x cpu) #xFF
            (cpu-y cpu) #xFD
            (cl-nes::apu-frame-irq-pending-p (cl-nes::bus-apu bus)) t)
      (expect-cpu-step-cycles cpu bus 6)
      (expect (cl-nes::apu-frame-irq-pending-p
               (cl-nes::bus-apu bus))
              :to-be nil))))

(define-cpu-semantic-case "LDA immediate sets N for a negative value"
  :program (#xA9 #x80) :p 0 :expected-a #x80 :expected-x 0 :expected-y 0
  :expected-sp #xFD :expected-p #xA0 :expected-pc #x8002 :cycles 2)

(define-cpu-semantic-case "LDX zero-page loads zero and sets Z"
  :program (#xA6 #x40) :p #x80 :writes ((#x0040 0)) :expected-a 0
  :expected-x 0 :expected-y 0 :expected-sp #xFD :expected-p #x22
  :expected-pc #x8002 :expected-memory ((#x0040 0)) :cycles 3)

(define-cpu-semantic-case "STA absolute-X stores A at the indexed address"
  :program (#x9D #xFF #x01) :a #x5A :x 1 :expected-a #x5A :expected-x 1
  :expected-y 0 :expected-sp #xFD :expected-p #x24 :expected-pc #x8003
  :expected-memory ((#x0200 #x5A)) :cycles 5)

(define-cpu-semantic-case "STA zero-page-X wraps at FF"
  :program (#x95 #xFF) :a #x66 :x 1 :expected-a #x66 :expected-x 1
  :expected-y 0 :expected-sp #xFD :expected-p #x24 :expected-pc #x8002
  :expected-memory ((#x0000 #x66)) :cycles 4)

(define-cpu-semantic-case "LDA indirect-Y wraps pointer high byte and page-crosses"
  :program (#xB1 #xFF) :y 1 :writes ((#x00FF #xFF) (#x0000 #x00) (#x0100 #xA5))
  :expected-a #xA5 :expected-x 0 :expected-y 1 :expected-sp #xFD
  :expected-p #xA4 :expected-pc #x8002 :expected-memory ((#x0100 #xA5))
  :cycles 6)

(define-cpu-semantic-case "BCC takes a forward branch when carry is clear"
  :program (#x90 #x02 #xEA #xEA) :p 0 :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p 0 :expected-pc #x8004 :cycles 3)
(describe "CPU unstable indexed stores"
  (it "masks data without changing the page when indexing stays in-page"
    (with-fixture-cpu-system
        (cpu bus :program (list #x9E #x00 #x1D))
      (setf (cpu-x cpu) #x0F
            (cpu-y cpu) 0
            (cpu-p cpu) #x24)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (aref (cl-nes::bus-ram bus) #x500) :to-be #x0E)
      (expect (cpu-p cpu) :to-be #x24)))
  (it "corrupts the destination page and masks stored data on crossing"
    (with-fixture-cpu-system
        (cpu bus :program (list #x9E #x10 #x7D))
      (setf (cpu-x cpu) #x0F
            (cpu-y cpu) #xF0
            (cpu-p cpu) #x24)
      (expect-cpu-step-cycles cpu bus 5)
      (expect (aref (cl-nes::bus-ram bus) #x600) :to-be #x0E)
      (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x0E00)
      (expect (cpu-p cpu) :to-be #x24))))
