(in-package #:cl-nes/test)

(describe "Coverage: CPU illegal opcode contracts"
  (it "delays IRQ after status changes and rotates ARR with carry"
    (let ((cpu (make-cpu)))
      (setf (cpu-p cpu) cl-nes::+flag-interrupt-disable+
            (cl-nes::cpu-irq-delay cpu) 0)
      (cl-nes::%restore-status! cpu 0)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 1)
      (setf (cl-nes::cpu-irq-delay cpu) 0
            (cpu-p cpu) cl-nes::+flag-interrupt-disable+)
      (cl-nes::%restore-status! cpu cl-nes::+flag-interrupt-disable+)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 0)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%arr! cpu #xFF) :to-be #x7F)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) cl-nes::+flag-carry+)
      (expect (cl-nes::%arr! cpu #xFF) :to-be #xFF)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%arr! cpu #x80) :to-be #x40)
      (expect (logand (cpu-p cpu) cl-nes::+flag-overflow+)
              :to-be cl-nes::+flag-overflow+)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%aac! cpu #x80) :to-be #x80)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+)
              :to-be cl-nes::+flag-carry+)
      (setf (cpu-a cpu) #xFF
            (cpu-p cpu) 0)
      (expect (cl-nes::%aac! cpu 0) :to-be 0)
      (expect (logand (cpu-p cpu) cl-nes::+flag-carry+) :to-be 0))))
