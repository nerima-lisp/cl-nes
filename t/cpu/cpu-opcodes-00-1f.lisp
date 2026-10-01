(in-package #:cl-nes/test)

(describe "CPU opcode dispatch reachability (00-1F)"
  (define-opcode-dispatch-reachability-spec
      "reaches opcode #x~2,'0X through the unified dispatch"
    ((#x00)
     (#x01)
     (#x03)
     (#x04)
     (#x05)
     (#x06)
     (#x07)
     (#x08)
     (#x09)
     (#x0A)
     (#x0B)
     (#x0C)
     (#x0D)
     (#x0E)
     (#x0F)
     (#x10)
     (#x11)
     (#x13)
     (#x14)
     (#x15)
     (#x16)
     (#x17)
     (#x18)
     (#x19)
     (#x1A)
     (#x1B)
     (#x1C)
     (#x1D)
     (#x1E)
     (#x1F))))

#+cl-nes-semantic-table-disabled
(describe "CPU opcode semantics (00-1F)"
  (define-cpu-semantics-spec
      "executes opcode #x~2,'0X with the specified CPU state transition"
    ((#x06 '(#x06 #x10)
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000
       :memory ((#x0010 #x81)))
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x25 :pc #x8002
       :memory ((#x0010 #x02)) :cycles 5))
     (#x09 '(#x09 #x0F)
      (:a #x40 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000
       :memory ((#x0010 #xAA)))
      (:a #x4F :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8002
       :memory ((#x0010 #xAA)) :cycles 2))
     (#x10 '(#x10 #x05)
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000
       :memory ((#x0010 #xAA)))
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8007
       :memory ((#x0010 #xAA)) :cycles 3))
     (#x18 '(#x18)
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x25 :pc #x8000
       :memory ((#x0010 #xAA)))
     (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8001
       :memory ((#x0010 #xAA)) :cycles 2))
     (#xA9 '(#xA9 #x80)
      (:a 0 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000 :memory ())
      (:a #x80 :x #x22 :y #x33 :sp #x44 :p #xA4 :pc #x8002
       :memory () :cycles 2))
     (#x85 '(#x85 #x10)
      (:a #x5A :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000
       :memory ((#x0010 0)))
      (:a #x5A :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8002
       :memory ((#x0010 #x5A)) :cycles 3))
     (#x69 '(#x69 #x01)
      (:a #xFF :x #x22 :y #x33 :sp #x44 :p #x25 :pc #x8000 :memory ())
      (:a #x01 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8002
       :memory () :cycles 2))
     (#xE9 '(#xE9 #x01)
      (:a 0 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000 :memory ())
      (:a #xFE :x #x22 :y #x33 :sp #x44 :p #xA4 :pc #x8002
       :memory () :cycles 2))
     (#x0A '(#x0A)
      (:a #x80 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000 :memory ())
      (:a 0 :x #x22 :y #x33 :sp #x44 :p #x27 :pc #x8001
       :memory () :cycles 2))
     (#x6A '(#x6A)
      (:a 1 :x #x22 :y #x33 :sp #x44 :p #x25 :pc #x8000 :memory ())
      (:a #x80 :x #x22 :y #x33 :sp #x44 :p #xA5 :pc #x8001
       :memory () :cycles 2))
     (#xD0 '(#xD0 #x02)
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8000 :memory ())
      (:a #x11 :x #x22 :y #x33 :sp #x44 :p #x24 :pc #x8004
       :memory () :cycles 3)))))
