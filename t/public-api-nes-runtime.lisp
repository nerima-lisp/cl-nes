(in-package #:cl-nes/test)

(describe "Public API: NES runtime"
  (it "accepts controller input through the public step interface"
    (let* ((cartridge (make-fixture-cartridge))
           (controller (make-controller))
           (nes (make-nes :cartridge cartridge
                          :controller-1 controller)))
      (controller-set-buttons! controller +button-a+)
      (bus-write! (nes-bus nes) #x4016 1)
      (bus-write! (nes-bus nes) #x4016 0)
      (let ((sample (bus-read (nes-bus nes) #x4016)))
        (expect (logand sample 1) :to-be 1))))

  (it "creates cartridge-free consoles and resets their components"
    (let ((nes (make-nes)))
      (expect (typep (nes-cpu nes) 'cpu) :to-be-truthy)
      (expect (typep (nes-bus nes) 'bus) :to-be-truthy)
      (expect (typep (nes-ppu nes) 'ppu) :to-be-truthy)
      (expect (typep (nes-apu nes) 'apu) :to-be-truthy)
      (expect (nes-reset! nes) :to-be nes)))

  (it "exposes reusable continuations for NES stepping"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge))
           (continuation-result nil)
           (continuation-cycles nil))
      (expect (functionp #'nes-step/k) :to-be-truthy)
      (expect (functionp #'nes-run-frame/k) :to-be-truthy)
      (setf continuation-result
            (nes-step/k
             nes
             (lambda (cycles)
               (setf continuation-cycles cycles)
               :continued)))
      (expect continuation-cycles :to-be 2)
      (expect continuation-result :to-be :continued))))
