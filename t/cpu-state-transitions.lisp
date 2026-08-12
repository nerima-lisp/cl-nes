(in-package #:cl-nes/test)

(describe "CPU state transitions"
  (with-fixture-cpu-suite (cpu bus cartridge)
    (it "does not advance a stopped CPU"
      (setf (cpu-stopped-p cpu) t)
      (let ((before-pc (cpu-pc cpu))
            (before-cycles (cpu-cycles cpu)))
        (expect (cpu-step! cpu bus) :to-be 0)
        (expect (cpu-pc cpu) :to-be before-pc)
        (expect (cpu-cycles cpu) :to-be before-cycles))))
  (define-cpu-branch-step-spec
      "applies branch flags and page-crossing cycle penalties"
    ((#x10 #x24 #x8000 #x10 #x8012 3)
     (#x30 #xA4 #x8000 #x30 #x8032 3)
     (#x50 #x24 #x8000 #x50 #x8052 3)
     (#x70 #x64 #x8000 #x70 #x8072 3)
     (#x90 #x24 #x8000 #x10 #x8012 3)
     (#xB0 #x25 #x8000 #x30 #x8032 3)
     (#xD0 #x24 #x8000 #x50 #x8052 3)
     (#xF0 #x26 #x8000 #x70 #x8072 3)
     (#x10 #xA4 #x8000 #x10 #x8002 2)
     (#x30 #x24 #x8000 #x30 #x8002 2)
     (#x50 #x64 #x8000 #x50 #x8002 2)
     (#x70 #x24 #x8000 #x70 #x8002 2)
     (#x90 #x25 #x8000 #x90 #x8002 2)
     (#xB0 #x24 #x8000 #xB0 #x8002 2)
     (#xD0 #x26 #x8000 #xD0 #x8002 2)
     (#xF0 #x24 #x8000 #xF0 #x8002 2)
     (#x10 #x24 #x80F0 #x10 #x8102 4)
     (#x10 #x24 #x8100 #xF0 #x80F2 4)))

  (define-cpu-branch-irq-delay-spec
      "marks only taken non-page-crossing branches for deferred IRQ polling"
    ((#x24 #x8000 #x10 t)
     (#x24 #x80F0 #x10 nil)
     (#xA4 #x8000 #x10 nil))))
