(in-package #:cl-nes)

(defmacro with-nes-cpu-operation ((nes-form) &body body)
  "Clock a CPU operation while preserving bus-access timing.

The CPU instruction implementations report total cycles.  Device-visible
cycles are clocked immediately by the bus hook; this macro clocks the
remaining internal cycles and restores the hook even when BODY signals."
  (let ((nes (gensym "NES"))
        (bus (gensym "BUS"))
        (accesses (gensym "ACCESSES"))
        (previous-hook (gensym "PREVIOUS-HOOK"))
        (cycles (gensym "CYCLES")))
    `(let* ((,nes ,nes-form)
            (,bus (nes-bus ,nes))
            (,accesses 0)
            (,previous-hook (bus-cpu-access-hook ,bus)))
       (setf (bus-cpu-access-hook ,bus)
             (lambda ()
               (incf ,accesses)
               (%nes-tick! ,nes 1)))
       (unwind-protect
            (let ((,cycles (progn ,@body)))
              (setf (bus-cpu-access-hook ,bus) ,previous-hook)
              (when ,cycles
                (%nes-tick! ,nes (max 0 (- ,cycles ,accesses))))
              ,cycles)
         (setf (bus-cpu-access-hook ,bus) ,previous-hook)))))
