(in-package #:cl-nes)

(defmacro with-bus-cpu-access-hook ((bus-form hook-form) &body body)
  "Run BODY with a temporary CPU access hook installed on BUS-FORM."
  (let ((bus (gensym "BUS"))
        (previous-hook (gensym "PREVIOUS-HOOK"))
        (hook (gensym "HOOK"))
        (previous-active (gensym "PREVIOUS-ACTIVE")))
    `(let* ((,bus ,bus-form)
            (,previous-hook (bus-cpu-access-hook ,bus))
            (,hook ,hook-form)
            (,previous-active (bus-cpu-access-active-p ,bus)))
       (unwind-protect
            (progn
              (setf (bus-cpu-access-hook ,bus) ,hook
                    (bus-cpu-access-active-p ,bus) nil)
              ,@body)
         (setf (bus-cpu-access-hook ,bus) ,previous-hook
               (bus-cpu-access-active-p ,bus) ,previous-active)))))

(defmacro with-nes-cpu-operation ((nes-form &optional cycle-hook-form
                                             pre-cycle-hook-form)
                                  &body body)
  "Clock a CPU operation while preserving bus-access timing."
  (let ((nes (gensym "NES"))
        (bus (gensym "BUS"))
        (accesses (gensym "ACCESSES"))
        (cycles (gensym "CYCLES"))
        (cycle-hook (gensym "CYCLE-HOOK"))
        (pre-cycle-hook (gensym "PRE-CYCLE-HOOK"))
        (previous-active (gensym "PREVIOUS-ACTIVE"))
        (previous-nes (gensym "PREVIOUS-NES"))
        (previous-cycle-hook (gensym "PREVIOUS-CYCLE-HOOK"))
        (previous-pre-cycle-hook (gensym "PREVIOUS-PRE-CYCLE-HOOK")))
    `(let* ((,nes ,nes-form)
            (,bus (nes-bus ,nes))
            (,accesses (bus-cpu-access-count ,bus))
            (,cycle-hook ,cycle-hook-form)
            (,pre-cycle-hook ,pre-cycle-hook-form)
            (,previous-active (bus-cpu-access-active-p ,bus))
            (,previous-nes (bus-cpu-access-nes ,bus))
            (,previous-cycle-hook (bus-cpu-access-cycle-hook ,bus))
            (,previous-pre-cycle-hook (bus-cpu-access-pre-cycle-hook ,bus)))
       (unwind-protect
            (progn
              (setf (bus-cpu-access-active-p ,bus) t
                    (bus-cpu-access-nes ,bus) ,nes
                    (bus-cpu-access-cycle-hook ,bus) ,cycle-hook
                    (bus-cpu-access-pre-cycle-hook ,bus) ,pre-cycle-hook
                    (bus-cpu-access-count ,bus) 0)
              (let ((,cycles (progn ,@body)))
                (setf (bus-cpu-access-active-p ,bus) nil)
                (%nes-complete-cpu-operation!
                 ,nes ,bus ,cycles (bus-cpu-access-count ,bus)
                 ,cycle-hook ,pre-cycle-hook)))
         (setf (bus-cpu-access-active-p ,bus) ,previous-active
               (bus-cpu-access-nes ,bus) ,previous-nes
               (bus-cpu-access-cycle-hook ,bus) ,previous-cycle-hook
               (bus-cpu-access-pre-cycle-hook ,bus) ,previous-pre-cycle-hook
               (bus-cpu-access-count ,bus) ,accesses)))))
