(in-package #:cl-nes)

(defun %apply-cpu-state-specs! (cpu specs)
  (dolist (spec specs cpu)
    (destructuring-bind (accessor value) spec
      (%set-cpu-state-slot! cpu accessor value))))
