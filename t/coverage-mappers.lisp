(in-package #:cl-nes/test)

(describe "Coverage: mapper contracts"
  (it "resets MMC1 shift state and forces safe mirroring"
    (let ((cartridge (make-contract-cartridge 1)))
      (cartridge-write-prg! cartridge #x8000 #x80)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x10)
      (expect (cl-nes::cartridge-mapper-control cartridge) :to-be #x0C)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "selects MMC1 mirroring and 8 KiB CHR mode"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1 :prg-banks 4 :chr-banks 32)))
      (serial-write-mmc1-register cartridge #x8000 2)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (serial-write-mmc1-register cartridge #x8000 3)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (serial-write-mmc1-register cartridge #x8000 0)
      (serial-write-mmc1-register cartridge #xA000 2)
      (expect (cartridge-read-chr cartridge 0) :to-be 16)
      (serial-write-mmc1-register cartridge #xC000 1)
      (expect (cl-nes::cartridge-mapper-chr-bank-1 cartridge) :to-be 1)))

  (it "updates mapper 28 mirroring and bank registers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 28 :prg-banks 4 :chr-banks 16)))
      (write-mapper28-register cartridge #x80 2)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (write-mapper28-register cartridge #x80 3)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (write-mapper28-register cartridge #x80 0)
      (write-mapper28-register cartridge #x00 #x10)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (write-mapper28-register cartridge #x01 0)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)
      (write-mapper28-register cartridge #x80 3)
      (write-mapper28-register cartridge #x00 #x10)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (write-mapper28-register cartridge #x81 #x2A)
      (expect (cl-nes::cartridge-mapper-outer-bank cartridge) :to-be #x2A)))

  (it "does not retrigger MMC3 on a high-to-high A12 sample"
    (with-mmc3-cartridge (cartridge)
      (cartridge-write-prg! cartridge #xC000 0)
      (cartridge-write-prg! cartridge #xE001 0)
      (pulse-ppu-a12! cartridge)
      (setf (cl-nes::cartridge-mapper4-irq-pending-p cartridge) nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil)))

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
      (dolist (case `(("arr/no-carry" #xFF 0 0
                       cl-nes::%arr! #xFF #x7F (,cl-nes::+flag-carry+))
                      ("arr/with-carry" #xFF 0 ,cl-nes::+flag-carry+
                       cl-nes::%arr! #xFF #xFF (,cl-nes::+flag-carry+
                                                ,cl-nes::+flag-negative+))
                      ("arr/overflow" #xFF 0 0
                       cl-nes::%arr! #x80 #x40 (,cl-nes::+flag-carry+
                                                ,cl-nes::+flag-overflow+))
                      ("aac/carry" #xFF 0 0
                       cl-nes::%aac! #x80 #x80 (,cl-nes::+flag-carry+
                                               ,cl-nes::+flag-negative+))
                      ("aac/zero" #xFF 0 0
                       cl-nes::%aac! 0 0 (,cl-nes::+flag-zero+))
                      ("asr/zero" #x0F 0 0
                       cl-nes::%asr! #xF0 0 (,cl-nes::+flag-zero+))
                      ("lax/negative" 0 0 #x80
                       cl-nes::%lax! #x80 #x80 (,cl-nes::+flag-negative+))
                      ("atx/zero" #x55 0 0
                       cl-nes::%atx! 0 0 (,cl-nes::+flag-zero+))
                      ("axs/carry" #x0F #x0F 0
                       cl-nes::%axs! #x01 #x0E (,cl-nes::+flag-carry+))
                      ("axs/negative" #x00 #x00 0
                       cl-nes::%axs! #x01 #xFF (,cl-nes::+flag-negative+))))
        (destructuring-bind
            (label initial-a initial-x initial-status
             operator operand expected-value expected-flags)
            case
          (declare (ignore label))
          (setf (cpu-a cpu) initial-a
                (cpu-x cpu) initial-x
                (cpu-p cpu) initial-status)
          (expect (funcall operator cpu operand) :to-be expected-value)
          (expect-cpu-flags cpu expected-flags))))

  (it "covers BIT flag transitions"
    (let ((cpu (make-cpu)))
      (dolist (case `(("bit/full-mask" #xFF #xC0
                       () (,cl-nes::+flag-overflow+
                           ,cl-nes::+flag-negative+))
                      ("bit/zero" 0 0
                       (,cl-nes::+flag-zero+) ())
                      ("bit/overflow" 0 #x40
                       (,cl-nes::+flag-zero+
                        ,cl-nes::+flag-overflow+) ())
                      ("bit/negative" 0 #x80
                       (,cl-nes::+flag-zero+
                        ,cl-nes::+flag-negative+) ())))
        (destructuring-bind
            (label initial-a operand expected-flags absent-flags)
            case
          (declare (ignore label))
          (setf (cpu-a cpu) initial-a
                (cpu-p cpu) 0)
          (cl-nes::%bit! cpu operand)
          (expect-cpu-flags
           cpu expected-flags
           (append expected-flags absent-flags))))))

  (define-cpu-value-op-spec
      "covers shift helper flag transitions (~A)"
      (("asl/carry-zero" 0 0
        #'cl-nes::%asl-value! #x80 0 (1 2))
        ("asl/plain" 0 0
         #'cl-nes::%asl-value! 1 2 ())
        ("lsr/carry-zero" 0 0
         #'cl-nes::%lsr-value! 1 0 (1 2))
        ("lsr/plain" 0 0
         #'cl-nes::%lsr-value! 2 1 ())
        ("rol/keeps-carry" 0 1
         #'cl-nes::%rol-value! #x80 1 (1))
        ("rol/zero" 0 0
         #'cl-nes::%rol-value! 0 0 (2))
        ("ror/negative-carry" 0 1
         #'cl-nes::%ror-value! 1 #x80 (1 128))
        ("ror/plain" 0 0
         #'cl-nes::%ror-value! 2 1 ())))

  (it "covers CPU ALU macro frontends"
    (dolist (case '((cl-nes::define-cpu-alu-accumulator-ops
                     (cl-nes::%ora! cl-nes::%and! cl-nes::%eor!))
                    (cl-nes::define-cpu-alu-compare-ops
                     (cl-nes::%cmp-a! cl-nes::%cmp-x! cl-nes::%cmp-y!))
                    (cl-nes::define-cpu-alu-value-ops
                     (cl-nes::%asl-value! cl-nes::%lsr-value! cl-nes::%rol-value!
                      cl-nes::%ror-value! cl-nes::%inc-value! cl-nes::%dec-value!))
                    (cl-nes::define-cpu-alu-rmw-ops
                     (cl-nes::%slo-value! cl-nes::%rla-value! cl-nes::%sre-value!
                      cl-nes::%rra-value! cl-nes::%dcp-value! cl-nes::%isc-value!))
                    (cl-nes::define-cpu-alu-derived-ops
                     (cl-nes::%lax! cl-nes::%aac! cl-nes::%asr!
                      cl-nes::%arr! cl-nes::%atx! cl-nes::%axs!))))
      (destructuring-bind (macro-name expected-names) case
        (let ((expanded (macroexpand-1 `(,macro-name))))
          (expect (first expanded) :to-be 'progn)
          (expect (mapcar #'second (rest expanded)) :to-equal expected-names)))))
))
