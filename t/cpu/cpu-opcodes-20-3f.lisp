(in-package #:cl-nes/test)

(defmacro define-cpu-semantic-case
    (description &key program (start #x8000) (a 0) (x 0) (y 0) (p #x24)
                       (sp #xFD) (writes '()) expected-a expected-x expected-y
                       expected-sp expected-p expected-pc expected-memory cycles)
  `(it ,description
     (with-fixture-cpu-state (cpu bus :program ',program :start ,start
                              :a ,a :x ,x :y ,y :p ,p :sp ,sp)
       (dolist (write ',writes)
         (bus-write! bus (first write) (second write)))
       (expect (list (cpu-a cpu) (cpu-x cpu) (cpu-y cpu) (cpu-sp cpu)
                     (cpu-pc cpu) (cpu-p cpu) (cpu-cycles cpu))
               :to-be (list ,a ,x ,y ,sp ,start ,p 7))
       (expect (cpu-step! cpu bus) :to-be ,cycles)
       (expect (list (cpu-a cpu) (cpu-x cpu) (cpu-y cpu) (cpu-sp cpu)
                     (cpu-pc cpu) (cpu-p cpu) (cpu-cycles cpu))
               :to-be (list ,expected-a ,expected-x ,expected-y ,expected-sp
                            ,expected-pc ,expected-p (+ 7 ,cycles)))
       (dolist (memory ',expected-memory)
         (expect (bus-read bus (first memory)) :to-be (second memory))))))

(describe "CPU opcode dispatch reachability (20-3F)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#x20 6) (#x21 6) (#x23 8) (#x24 3) (#x25 3) (#x26 5) (#x27 5)
     (#x28 4) (#x29 2) (#x2A 2) (#x2B 2) (#x2C 4) (#x2D 4) (#x2E 6) (#x2F 6)
     (#x30 2) (#x31 5) (#x33 8) (#x34 4) (#x35 4) (#x36 6) (#x37 6)
     (#x38 2) (#x39 4) (#x3A 2) (#x3B 7) (#x3C 4) (#x3D 4) (#x3E 7) (#x3F 7))))

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "JSR pushes PC-1 high then low and jumps"
  :program (#x20 #x34 #x12) :expected-a 0 :expected-x 0 :expected-y 0
  :expected-sp #xFB :expected-p #x24 :expected-pc #x1234
  :expected-memory ((#x01FD #x80) (#x01FC #x02)) :cycles 6)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "ROL accumulator uses carry and updates C"
  :program (#x2A) :a #x80 :p #x25 :expected-a 1 :expected-x 0 :expected-y 0
  :expected-sp #xFD :expected-p #x25 :expected-pc #x8001 :cycles 2)

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "BRK pushes the padding-advanced PC and vectors"
  :program (#x00 #x99) :p #x24 :expected-a 0 :expected-x 0 :expected-y 0
  :expected-sp #xFA :expected-p #x24 :expected-pc #x8000 :cycles 7)

#+cl-nes-semantic-table-disabled
(it "BRK pushes the return frame and loads the IRQ vector"
  (let* ((cartridge (set-fixture-vector!
                     (make-fixture-cartridge :program '(#x00 #x99))
                     #xFFFE #x3456))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (cpu-reset! cpu bus)
    (expect (cpu-step! cpu bus) :to-be 7)
    (expect (list (cpu-a cpu) (cpu-x cpu) (cpu-y cpu) (cpu-sp cpu)
                  (cpu-pc cpu) (cpu-p cpu) (cpu-cycles cpu))
            :to-be (list 0 0 0 #xFA #x3456 #x24 14))
    (expect (bus-read bus #x01FD) :to-be #x80)
    (expect (bus-read bus #x01FC) :to-be #x02)
    (expect (bus-read bus #x01FB) :to-be #x34)))

#+cl-nes-semantic-table-disabled
(define-cpu-semantic-case "BNE takes a same-page branch when Z is clear"
  :program (#xD0 #x02 #xEA #xEA) :p 0 :expected-a 0 :expected-x 0
  :expected-y 0 :expected-sp #xFD :expected-p 0 :expected-pc #x8004 :cycles 3)
