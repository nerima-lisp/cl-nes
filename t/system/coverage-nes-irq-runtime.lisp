(in-package #:cl-nes/test)

(describe "Coverage: NES IRQ runtime paths"
  (it "takes a pending IRQ after the instruction boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge)))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p (nes-cpu nes)) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (let ((cycles (nes-step/k nes #'identity)))
        (expect cycles :to-be 9)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x9000)
        (expect (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) :to-be t))))

  (it "samples IRQ before the final cycle of a three-cycle instruction"
    (let* ((cartridge (make-fixture-cartridge :program '(#xA5 #x00)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p cpu) 0)
      (let ((cycles
              (nes-step/k
               nes #'identity
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 1)
                   (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t))))))
        (expect cycles :to-be 10)
        (expect (cpu-pc cpu) :to-be #x9000))))

  (it "takes the sampled IRQ after a final-cycle $4015 acknowledge"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge
                        :program '(#xAD #x15 #x40))
                       #xFFFE
                       #x9000))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes)))
      (setf (cpu-p cpu) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (expect (nes-step/k nes #'identity) :to-be 11)
      (expect (cpu-pc cpu) :to-be #x9000)
      (expect (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) :to-be nil)))

  (it "uses the current two-cycle IRQ observation at the poll boundary"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes)))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p cpu) 0
            (cl-nes::cpu-irq-poll-delay cpu) nil
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (expect (nes-step/k nes #'identity) :to-be 9)
      (expect (cpu-pc cpu) :to-be #x9000)))

  (it "skips the third-cycle IRQ poll of a taken same-page branch"
    (let* ((cartridge (make-fixture-cartridge
                       :program '(#xD0 #x00 #xEA)))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (set-fixture-vector! cartridge #xFFFE #x9000)
      (setf (cpu-p cpu) 0)
      (let ((cycles
              (nes-step/k
               nes #'identity
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 2)
                   (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t))))))
        (expect cycles :to-be 3)
        (expect (cpu-pc cpu) :to-be #x8002)
        (expect (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) :to-be t))))

  (it "polls a taken page-crossing branch on its fourth cycle"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge
                        :program '(#xD0 #x01)
                        :start #x80FD)
                       #xFFFE
                       #x9000))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (setf (cpu-p cpu) 0)
      (let ((cycles
              (nes-step/k
               nes #'identity
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 2)
                   (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t))))))
        (expect cycles :to-be 11)
        (expect (cpu-pc cpu) :to-be #x9000))))
  (it "polls an IRQ seen on the first poll of a taken page-crossing branch"
    (let* ((cartridge (set-fixture-vector!
                       (make-fixture-cartridge
                        :program (list #xD0 #x01)
                        :start #x80FD)
                       #xFFFE
                       #x9000))
           (nes (make-nes :cartridge cartridge))
           (cpu (nes-cpu nes))
           (elapsed 0))
      (setf (cpu-p cpu) 0
            (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (let ((cycles
              (nes-step/k
               nes (function identity)
               :cycle-hook
               (lambda ()
                 (when (= (incf elapsed) 1)
                   (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes))
                         nil))))))
        (expect cycles :to-be 11)
        (expect (cpu-pc cpu) :to-be #x9000))))
  (it "does not count DMC stall cycles as the first instruction IRQ poll"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (cl-nes::*nes-step-context* nes)
           (cl-nes::*nes-step-first-irq-poll-seen-p* nil)
           (cl-nes::*nes-step-dma-cycles* 0))
      (setf (cl-nes::nes-irq-line-sample-p nes) t
            (cl-nes::bus-cpu-access-count bus) 3
            cl-nes::*nes-step-dma-cycles* 3)
      (cl-nes::%nes-poll-irq-before-cycle!)
      (expect cl-nes::*nes-step-first-irq-poll-seen-p* :to-be nil)
      (setf (cl-nes::bus-cpu-access-count bus) 4)
      (cl-nes::%nes-poll-irq-before-cycle!)
      (expect cl-nes::*nes-step-first-irq-poll-seen-p* :to-be t)))

  (it "exercises NES interrupt eligibility and injected components"
    (let* ((cpu (make-cpu))
           (nes (make-nes))
           (ppu (make-ppu))
           (apu (make-apu))
           (controller-1 (make-controller))
           (controller-2 (make-controller))
           (injected (make-nes :ppu ppu
                               :apu apu
                               :controller-1 controller-1
                               :controller-2 controller-2)))
      (expect (cl-nes::%nes-irq-eligible-p cpu t) :to-be nil)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be nil)
      (setf (cpu-p cpu) 0)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be t)
      (setf (cpu-p cpu) cl-nes::+flag-interrupt-disable+
            (cl-nes::cpu-irq-delay cpu) 0)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be nil)
      (setf (cl-nes::cpu-irq-delay cpu) 1)
      (expect (cl-nes::%nes-irq-eligible-p cpu nil) :to-be t)
      (expect (cl-nes::%nes-cartridge-irq-pending-p nes) :to-be nil)
      (expect (cl-nes::%nes-irq-pending-p nes) :to-be nil)
      (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) t)
      (expect (cl-nes::%nes-irq-pending-p nes) :to-be t)
      (setf (cl-nes::apu-frame-irq-pending-p (nes-apu nes)) nil)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be nil)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t
            (cl-nes::ppu-nmi-delay-p (nes-ppu nes)) 3)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be nil)
      (ppu-tick! (nes-ppu nes) 3)
      (cl-nes::%nes-poll-nmi-during-operation! nes)
      (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil)
      (setf (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) t)
      (expect (cl-nes::%nes-take-nmi! nes) :to-be t)
      (expect (cl-nes::ppu-nmi-pending-p (nes-ppu nes)) :to-be nil)
      (expect (nes-ppu injected) :to-be ppu)
      (expect (cl-nes::bus-apu (nes-bus injected)) :to-be apu)
      (expect (cl-nes::bus-controller-1 (nes-bus injected)) :to-be controller-1)
      (expect (cl-nes::bus-controller-2 (nes-bus injected)) :to-be controller-2))))
