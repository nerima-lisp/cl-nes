(in-package #:cl-nes/test)

(describe "CPU interrupt transitions"
  (with-fixture-cpu-suite (cpu bus cartridge)
    (it "restores the reset state and loads the reset vector"
      (set-fixture-vector! cartridge #xFFFC #x9000)
      (setf (cpu-a cpu) #x12
            (cpu-x cpu) #x34
            (cpu-y cpu) #x56
            (cpu-p cpu) #xFF
            (cpu-sp cpu) #x80
            (cpu-pc cpu) #x8123
            (cpu-cycles cpu) 99
            (cl-nes::cpu-irq-delay cpu) 3
            (cl-nes::cpu-irq-poll-delay cpu) t
            (cpu-stopped-p cpu) t)
      (expect (cpu-reset! cpu bus) :to-be cpu)
      (expect (cpu-a cpu) :to-be 0)
      (expect (cpu-x cpu) :to-be 0)
      (expect (cpu-y cpu) :to-be 0)
      (expect (cpu-p cpu) :to-be #x24)
      (expect (cpu-sp cpu) :to-be #xFD)
      (expect (cpu-pc cpu) :to-be #x9000)
      (expect (cpu-cycles cpu) :to-be 7)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 0)
      (expect (cl-nes::cpu-irq-poll-delay cpu) :to-be nil)
      (expect (cpu-stopped-p cpu) :to-be nil))

    (it "pushes the return state before entering an NMI vector"
      (set-fixture-vector! cartridge #xFFFA #x9000)
      (setf (cpu-pc cpu) #x8123)
      (expect (cpu-interrupt! cpu bus :nmi) :to-be 7)
      (expect (cpu-pc cpu) :to-be #x9000)
      (expect (cpu-sp cpu) :to-be #xFA)
      (expect (cpu-cycles cpu) :to-be 14)
      (expect (bus-read bus #x01FD) :to-be #x81)
      (expect (bus-read bus #x01FC) :to-be #x23)
      (let ((stack-status (bus-read bus #x01FB)))
        (expect (logand stack-status #x20) :to-be #x20)
        (expect (logand stack-status #x10) :to-be 0)))

    (it "handles masked, enabled, and forced IRQ delivery"
      (set-fixture-vector! cartridge #xFFFE #xA000)
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
      (expect (cpu-pc cpu) :to-be #xA000))

    (it "rejects an unknown interrupt type"
      (let ((condition
              (captured-condition
                (lambda ()
                  (cl-nes::%interrupt-vector-address :unknown)))))
        (expect (typep condition 'error) :to-be t)))

  (define-cpu-interrupt-vector-spec
      "routes IRQ delivery to the expected vector after polling NMI"
    (("keeps the IRQ vector when nmi-poll returns nil" nil #xA000)
     ("switches an IRQ to the NMI vector when nmi-poll returns true"
      t
      #x9000))))
)
