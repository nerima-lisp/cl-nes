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
      (expect (cpu-pc cpu) :to-be #xA000)
      (cpu-reset! cpu bus)
      (set-fixture-vector! cartridge #xFFFA #xB000)
      (setf (cpu-p cpu) 0
            (cpu-pc cpu) #x8123)
      (expect (cpu-interrupt! cpu bus :irq nil (lambda () t)) :to-be 7)
      (expect (cpu-pc cpu) :to-be #xB000)))
  (it "preserves registers and stack memory during reset"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge)
                       #xFFFC
                       #x9000))
           (bus (make-bus :cartridge cartridge))
           (cpu (make-cpu)))
      (setf (cpu-a cpu) #x11
            (cpu-x cpu) #x22
            (cpu-y cpu) #x33
            (cpu-p cpu) #x28
            (cpu-sp cpu) 0
            (cpu-pc cpu) #x8123)
      (bus-write! bus #x0100 #xA0)
      (bus-write! bus #x01FF #xA1)
      (bus-write! bus #x01FE #xA2)
      (expect (cpu-reset! cpu bus) :to-be cpu)
      (expect (list (cpu-a cpu) (cpu-x cpu) (cpu-y cpu) (cpu-p cpu)
                    (cpu-sp cpu) (cpu-pc cpu) (cpu-cycles cpu))
              :to-equal (list #x11 #x22 #x33 #x2C #xFD #x9000 7))
      (expect (bus-read bus #x0100) :to-be #xA0)
      (expect (bus-read bus #x01FF) :to-be #xA1)
      (expect (bus-read bus #x01FE) :to-be #xA2))))
