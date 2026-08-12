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
                      (%nes-clock-cpu-cycle! ,nes ,bus
                                             ,cycle-hook
                                             ,pre-cycle-hook)))
                 (progn ,@body))))
         (%nes-complete-cpu-operation!
          ,nes ,bus ,cycles ,accesses
          ,cycle-hook ,pre-cycle-hook)))))

(defmacro define-cartridge-prg-register-writers (&body definitions)
  "Define simple internal cartridge PRG register writer functions.

DEFINITIONS is a list of:

  (name (cartridge value) form...)

This keeps small mapper-specific writers declarative and colocated."
  `(progn
     ,@(mapcar (lambda (definition)
                 (destructuring-bind (name lambda-list &body body) definition
                   `(defun ,name ,lambda-list
                      ,@body)))
               definitions)))

(defmacro define-cartridge-prg-register-dispatch (name (cartridge address value)
                                                  &body clauses)
  "Define the mapper-dispatch entrypoint for cartridge PRG register writes.

Each clause is:

  (mapper-number guard-macro writer-form)

where GUARD-MACRO receives ADDRESS and WRITER-FORM performs the write."
  `(defun ,name (,cartridge ,address ,value)
     (case (cartridge-mapper ,cartridge)
       ,@(mapcar (lambda (clause)
                   (destructuring-bind
                       (mapper-number guard-macro writer-form) clause
                     `(,mapper-number
                       (,guard-macro (,address)
                         ,writer-form))))
                 clauses))))

(defmacro define-register-write-dispatch-from-table
    (name (object address value) table-symbol &body extra-clauses)
  "Define a write dispatcher from a compile-time register specification table.

Each entry in TABLE-SYMBOL is:

  (address accessor value-form)

EXTRA-CLAUSES are plain COND clauses evaluated after the table-driven writes."
  (let ((entries (symbol-value table-symbol)))
    `(defun ,name (,object ,address ,value)
       (cond
         ,@(mapcar (lambda (entry)
                     (destructuring-bind
                         (register-address accessor value-form) entry
                       `((= ,address ,register-address)
                         (setf (,accessor ,object) ,value-form))))
                   entries)
         ,@extra-clauses)
       ,value)))

(defmacro define-register-read-dispatch-from-table
    (name (object address) table-symbol &body extra-clauses)
  "Define a read dispatcher from a compile-time register specification table.

Each entry in TABLE-SYMBOL is:

  (address value-form)

EXTRA-CLAUSES are plain COND clauses appended after the table-driven reads."
  (let ((entries (symbol-value table-symbol)))
    `(defun ,name (,object ,address)
       (cond
         ,@(mapcar (lambda (entry)
                     (destructuring-bind (register-address value-form) entry
                       `((= ,address ,register-address)
                         ,value-form)))
                   entries)
         ,@extra-clauses))))
