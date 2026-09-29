(in-package #:cl-nes)

(defmacro with-bus-cpu-access-hook ((bus-form hook-form) &body body)
  "Run BODY with a temporary CPU access hook installed on BUS-FORM."
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
  "Clock a CPU operation while preserving bus-access timing."
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
                      (%nes-clock-cpu-cycle! ,nes ,bus
                                             ,cycle-hook
                                             ,pre-cycle-hook)))
                 (progn ,@body))))
         (%nes-complete-cpu-operation!
          ,nes ,bus ,cycles ,accesses
          ,cycle-hook ,pre-cycle-hook)))))
