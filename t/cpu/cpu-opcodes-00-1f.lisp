(in-package #:cl-nes/test)

(describe "CPU opcode dispatch (00-1F)"
  (define-opcode-dispatch-spec
      "dispatches opcode #x~2,'0X in ~D cycles"
    ((#x00 7) (#x01 6) (#x03 8) (#x04 3) (#x05 3) (#x06 5) (#x07 5)
     (#x08 3) (#x09 2) (#x0A 2) (#x0B 2) (#x0C 4) (#x0D 4) (#x0E 6)
     (#x0F 6) (#x10 3) (#x11 5) (#x13 8) (#x14 4) (#x15 4) (#x16 6)
     (#x17 6) (#x18 2) (#x19 4) (#x1A 2) (#x1B 7) (#x1C 4) (#x1D 4)
     (#x1E 7) (#x1F 7))))
