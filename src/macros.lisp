(in-package #:cl-nes)

(defmacro with-bus-cpu-access-hook ((bus-form hook-form) &body body)
  "Run BODY with a temporary CPU access hook installed on BUS-FORM.

The previous hook is restored even when BODY signals, so device-internal
reads and writes can suspend CPU-side timing without leaking that state to
the next operation."
  (let ((bus (gensym "BUS"))
        (previous-hook (gensym "PREVIOUS-HOOK"))
        (hook (gensym "HOOK")))
    `(let* ((,bus ,bus-form)
            (,previous-hook (bus-cpu-access-hook ,bus))
            (,hook ,hook-form))
       (unwind-protect
            (progn
              (setf (bus-cpu-access-hook ,bus) ,hook)
              ,@body)
         (setf (bus-cpu-access-hook ,bus) ,previous-hook)))))

(defmacro with-nes-cpu-operation ((nes-form &optional cycle-hook-form
                                             pre-cycle-hook-form)
                                  &body body)
  "Clock a CPU operation while preserving bus-access timing.

  The CPU instruction implementations report total cycles.  Device-visible
  cycles are clocked immediately by the bus hook; this macro clocks the
  remaining internal cycles and restores the hook even when BODY signals.

  When CYCLE-HOOK-FORM is supplied, call it after every CPU clock.  When
  PRE-CYCLE-HOOK-FORM is supplied, call it immediately before every clock.
  The two hooks are separate because an IRQ line sampled at the boundary of
  a clock is not equivalent to an IRQ source which becomes pending after that
  clock has already elapsed."
  (let ((nes (gensym "NES"))
        (bus (gensym "BUS"))
        (accesses (gensym "ACCESSES"))
        (cycles (gensym "CYCLES"))
        (cycle-hook (gensym "CYCLE-HOOK"))
        (pre-cycle-hook (gensym "PRE-CYCLE-HOOK")))
    `(let* ((,nes ,nes-form)
            (,bus (nes-bus ,nes))
            (,accesses 0)
            (,cycle-hook ,cycle-hook-form)
            (,pre-cycle-hook ,pre-cycle-hook-form))
       (let ((,cycles
               (with-bus-cpu-access-hook
                   (,bus
                    (lambda ()
                      (incf ,accesses)
                      (when ,pre-cycle-hook
                        (funcall ,pre-cycle-hook))
                      (%nes-tick! ,nes 1)
                      (setf (bus-cpu-cycle-phase ,bus)
                            (logxor (bus-cpu-cycle-phase ,bus) 1))
                      (when ,cycle-hook
                        (funcall ,cycle-hook))))
                 (progn ,@body))))
         (when ,cycles
           (loop repeat (max 0 (- ,cycles ,accesses)) do
             (when ,pre-cycle-hook
               (funcall ,pre-cycle-hook))
             (%nes-tick! ,nes 1)
             (setf (bus-cpu-cycle-phase ,bus)
                   (logxor (bus-cpu-cycle-phase ,bus) 1))
             (when ,cycle-hook
               (funcall ,cycle-hook))))
         ,cycles))))
