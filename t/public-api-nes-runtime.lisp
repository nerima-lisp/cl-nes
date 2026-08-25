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
      (expect continuation-result :to-be :continued)))

  (it "invokes input-continuation once before the frame's first step"
    (let* ((controller-1 (make-controller))
           (controller-2 (make-controller))
           (cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge
                          :controller-1 controller-1
                          :controller-2 controller-2))
           (input-calls 0)
           (frame-calls 0))
      (nes-run-frame/k
       nes
       (lambda (framebuffer)
         (incf frame-calls)
         (length framebuffer))
       :input-continuation
       (lambda (current)
         (incf input-calls)
         (expect current :to-be nes)
         (controller-set-buttons! controller-1 (logior +button-a+ +button-start+))
         (controller-set-buttons! controller-2 +button-right+)))
      (expect input-calls :to-be 1)
      (expect frame-calls :to-be 1)
      (expect (controller-buttons controller-1)
              :to-be (logior +button-a+ +button-start+))
      (expect (controller-buttons controller-2) :to-be +button-right+)))

  (it "rejects a non-function input-continuation"
    (let* ((cartridge (make-fixture-cartridge :program '(#xEA)))
           (nes (make-nes :cartridge cartridge))
           (condition
             (captured-condition
              (lambda ()
                (nes-run-frame/k nes #'identity
                                 :input-continuation :not-a-function)))))
      (expect (typep condition 'error) :to-be t))))
