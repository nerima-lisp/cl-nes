(in-package #:cl-nes/test)

(describe "controller boundaries"
  (it "reads live button state while strobe is high"
    (let ((controller (make-controller)))
      (controller-set-buttons! controller +button-a+)
      (controller-write! controller 1)
      (expect (controller-read controller) :to-be 1)
      (controller-set-buttons! controller 0)
      (expect (controller-read controller) :to-be 0)
      (controller-write! controller 0)))

  (it "returns one after the serialized button stream"
    (let ((controller (make-controller)))
      (controller-set-buttons!
       controller
       (logior +button-a+ +button-right+))
      (controller-write! controller 1)
      (controller-write! controller 0)
      (loop for expected in '(1 0 0 0 0 0 0 1)
            do (expect (controller-read controller) :to-be expected))
      (expect (controller-read controller) :to-be 1))))
