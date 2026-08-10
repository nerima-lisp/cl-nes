(in-package #:cl-nes/test)

(describe "Bus hook scopes"
  (it "restores the previous hook after normal execution"
    (let* ((bus (make-bus))
           (calls 0)
           (previous-hook (lambda () (incf calls))))
      (setf (cl-nes::bus-cpu-access-hook bus) previous-hook)
      (cl-nes::with-bus-cpu-access-hook
          (bus (lambda () (incf calls 10)))
        (funcall (cl-nes::bus-cpu-access-hook bus)))
      (expect calls :to-be 10)
      (expect (eq (cl-nes::bus-cpu-access-hook bus) previous-hook)
              :to-be t)))

  (it "restores the previous hook when the body signals"
    (let* ((bus (make-bus))
           (previous-hook (lambda () nil))
           (signaled nil))
      (setf (cl-nes::bus-cpu-access-hook bus) previous-hook)
      (handler-case
          (cl-nes::with-bus-cpu-access-hook (bus nil)
            (error "expected hook-scope failure"))
        (error () (setf signaled t)))
      (expect signaled :to-be t)
      (expect (eq (cl-nes::bus-cpu-access-hook bus) previous-hook)
              :to-be t))))
