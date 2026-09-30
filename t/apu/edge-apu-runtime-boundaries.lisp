(in-package #:cl-nes/test)

(describe "APU runtime boundaries"
  (it "fetches DMC bytes, wraps addresses, and loops samples"
    (let* ((addresses nil)
           (apu (make-apu
                 :memory-reader
                 (lambda (address)
                   (push address addresses)
                   #xFF)))
           (dmc (cl-nes::apu-dmc apu)))
      (apu-write-register! apu #x4010 #x80)
      (apu-write-register! apu #x4012 #xFF)
      (apu-write-register! apu #x4013 0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (length addresses) :to-be 1)
      (expect (first addresses) :to-be #xFFFF)
      (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x8000)
      (expect (apu-irq-pending-p apu) :to-be t)
      (expect (logbitp 7 (apu-read-register apu #x4015)) :to-be t)
      (apu-write-register! apu #x4010 #xC0)
      (apu-write-register! apu #x4015 #x10)
      (setf (cl-nes::apu-dmc-current-address dmc) #xFFFF)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)
      (apu-write-register! apu #x4015 0)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

  (it "delays frame mode changes and preserves console registers"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4017 #x80)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-five-step-p apu) :to-be t)
      (apu-write-register! apu #x4017 0)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 4)
      (apu-write-register! apu #x4000 #xFF)
      (apu-write-register! apu #x4002 #x34)
      (apu-write-register! apu #x4003 #x05)
      (cl-nes::apu-console-reset! apu)
      (expect (cl-nes::apu-frame-last-five-step-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (expect (cl-nes::apu-pulse-duty (cl-nes::apu-pulse-1 apu)) :to-be 3)
      (expect (cl-nes::apu-pulse-timer-period
               (cl-nes::apu-pulse-1 apu))
              :to-be #x534)
      (expect (cl-nes::apu-envelope-volume
               (cl-nes::apu-pulse-envelope (cl-nes::apu-pulse-1 apu)))
              :to-be 15)))

  (it "clocks a length counter on the delayed five-step reset"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4015 1)
      (apu-write-register! apu #x4003 #xA0)
      (apu-write-register! apu #x4017 #x80)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-pulse-length-counter
               (cl-nes::apu-pulse-1 apu))
              :to-be 47))))
