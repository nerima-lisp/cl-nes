(in-package #:cl-nes/test)

(describe "CPU hardware interrupt transitions"
  (it "pushes the return state before entering an NMI vector"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge)
                       #xFFFA
                       #x9000))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (setf (cpu-pc cpu) #x8123)
      (expect (cpu-interrupt! cpu bus :nmi) :to-be 7)
      (expect (cpu-pc cpu) :to-be #x9000)
      (expect (cpu-sp cpu) :to-be #xFA)
      (expect (cpu-cycles cpu) :to-be 14)
      (expect (bus-read bus #x01FD) :to-be #x81)
      (expect (bus-read bus #x01FC) :to-be #x23)
      (let ((stack-status (bus-read bus #x01FB)))
        (expect (logand stack-status #x20) :to-be #x20)
        (expect (logand stack-status #x10) :to-be 0))))

  (it "handles masked, enabled, and forced IRQ delivery"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge)
                       #xFFFE
                       #xA000))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (cpu-reset! cpu bus)
      (setf (cpu-pc cpu) #x8123)
      (let ((before-pc (cpu-pc cpu))
            (before-sp (cpu-sp cpu))
            (before-cycles (cpu-cycles cpu)))
        (expect (cpu-interrupt! cpu bus :irq) :to-be nil)
        (expect (cpu-pc cpu) :to-be before-pc)
        (expect (cpu-sp cpu) :to-be before-sp)
        (expect (cpu-cycles cpu) :to-be before-cycles))
      (setf (cpu-p cpu) #x20)
      (expect (cpu-interrupt! cpu bus :irq) :to-be 7)
      (expect (cpu-pc cpu) :to-be #xA000)
      (cpu-reset! cpu bus)
      (setf (cpu-p cpu) #x24
            (cpu-pc cpu) #x8123)
      (expect (cpu-interrupt! cpu bus :irq t) :to-be 7)
      (expect (cpu-pc cpu) :to-be #xA000))))
