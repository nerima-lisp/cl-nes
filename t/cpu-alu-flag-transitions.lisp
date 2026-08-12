(in-package #:cl-nes/test)

(describe "CPU ALU flag transitions"
  (define-cpu-alu-step-spec
      "propagates arithmetic and rotate flag transitions for ~A"
      (("adc overflow to negative"
        (#x69 #x01)
        #x7F
        0
        #x80
        (#x40 #x80))
       ("adc carry-out"
        (#x69 #x01)
        #xFF
        #x01
        1
        (#x01))
       ("rol shifts carry into bit 0"
        (#x2A)
        #x80
        #x01
        1
        (#x01))
       ("rol produces zero"
        (#x2A)
        0
        0
        0
        (#x02))
       ("ror shifts carry into bit 7"
        (#x6A)
        1
        #x01
        #x80
        (#x01 #x80))
       ("ror produces zero"
        (#x6A)
        0
        0
        0
        (#x02)))))
