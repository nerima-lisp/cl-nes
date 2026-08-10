(in-package #:cl-nes/test-runner)

(defvar *passed* 0)
(defvar *failed* 0)

(defparameter *legacy-test-cases*
  '(("cartridge-and-ines" test-cartridge-and-ines)
    ("mapper2" test-mapper2)
    ("mapper3" test-mapper3)
    ("mapper1" test-mapper1)
    ("mapper5" test-mapper5)
    ("discrete-mappers" test-discrete-mappers)
    ("nes2-header" test-nes2-header)
    ("bus-and-controller" test-bus-and-controller)
    ("ppu-registers-and-vblank" test-ppu-registers-and-vblank)
    ("ppu-rendering" test-ppu-rendering)
    ("cpu-instructions" test-cpu-instructions)
    ("cpu-interrupts" test-cpu-interrupts)
    ("boundary-cases" test-boundary-cases)
    ("apu-and-dma" test-apu-and-dma)
    ("nes-integration" test-nes-integration)))

(defun check (condition description)
  (if condition
      (incf *passed*)
      (progn
        (incf *failed*)
        (format *error-output* "FAIL: ~A~%" description)))
  condition)

(defun check-equal (actual expected description)
  (check (equal actual expected)
         (format nil "~A (expected ~S, got ~S)"
                 description expected actual)))

(defun signals-type-p (type thunk)
  (catch 'condition-signaled
    (handler-bind ((condition
                     (lambda (condition)
                       (when (typep condition type)
                         (throw 'condition-signaled t)))))
      (funcall thunk))
    nil))

(defun run-test (name thunk)
  (let ((failed-before *failed*))
    (handler-case
        (funcall thunk)
      (error (condition)
        (incf *failed*)
        (format *error-output* "ERROR: ~A: ~A~%" name condition)))
    (if (= failed-before *failed*)
        (format t "ok ~A~%" name)
        (format t "not ok ~A~%" name))))

(defun run-legacy-tests ()
  (setf *passed* 0
        *failed* 0)
  (dolist (case *legacy-test-cases*)
    (run-test (first case)
              (symbol-function (second case))))
  (values *passed* *failed*))
