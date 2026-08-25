(in-package #:cl-nes)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %expand-with-bus-cpu-access-hook (bus-form hook-form body)
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
  (defun %expand-with-nes-cpu-operation
      (nes-form cycle-hook-form pre-cycle-hook-form body)
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
  )

(defmacro with-bus-cpu-access-hook ((bus-form hook-form) &body body)
  "Run BODY with a temporary CPU access hook installed on BUS-FORM.

The previous hook is restored even when BODY signals, so device-internal
reads and writes can suspend CPU-side timing without leaking that state to
the next operation."
  (%expand-with-bus-cpu-access-hook bus-form hook-form body))

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
  (%expand-with-nes-cpu-operation nes-form cycle-hook-form
                                  pre-cycle-hook-form body))

(defmacro define-state-class-with-constructor (name slots)
  "Define a small state class with a constructor and predicate.

SLOTS is a list of (slot-name initform accessor-name) triples."
  (labels ((slot-definition (slot)
             (destructuring-bind (slot-name initform accessor-name) slot
               `(,slot-name :initarg ,(intern (symbol-name slot-name) :keyword)
                            :initform ,initform
                            :accessor ,accessor-name)))
           (constructor-argument (slot)
             (destructuring-bind (slot-name initform accessor-name) slot
               (declare (ignore accessor-name))
               `(,slot-name ,initform)))
           (constructor-initarg (slot)
             (destructuring-bind (slot-name initform accessor-name) slot
               (declare (ignore initform accessor-name))
               (list (intern (symbol-name slot-name) :keyword) slot-name))))
    (let ((constructor-name (intern (format nil "%MAKE-~A" name)
                                    (symbol-package name)))
          (predicate-name (intern (format nil "~A-P" name)
                                  (symbol-package name))))
      `(progn
         (defclass ,name ()
           ,(mapcar #'slot-definition slots))
         (defun ,constructor-name (&key ,@(mapcar #'constructor-argument slots))
           (make-instance ',name
                          ,@(mapcan #'constructor-initarg slots)))
         (defun ,predicate-name (object)
           (typep object ',name))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %expand-cpu-opcode-clause (cpu bus clause)
    (let ((tag (first clause))
          (rest (rest clause)))
      (case tag
        (:read
         (destructuring-bind (opcodes mode operation page-cycle-p) rest
           `(,opcodes (%read-op! ,cpu ,bus ,mode ,operation ,page-cycle-p))))
        (:write
         (destructuring-bind (opcodes mode value-form) rest
           `(,opcodes (%write-op! ,cpu ,bus ,mode ,value-form))))
        (:rmw
         (destructuring-bind (opcodes mode operation cycles) rest
           `(,opcodes (%rmw-op! ,cpu ,bus ,mode ,operation ,cycles))))
        (:nop
         (destructuring-bind (opcodes mode cycles) rest
           `(,opcodes (%nop-op! ,cpu ,bus ,mode ,cycles))))
        (:branch
         (destructuring-bind (opcode condition-form) rest
           `(,opcode (%branch! ,cpu ,bus ,condition-form))))
        (otherwise clause)))))

(defmacro define-cpu-opcodes ((cpu bus opcode) &body clauses)
  "Expand CLAUSES, a declarative 6502 opcode table, into a CASE dispatch on
OPCODE.

Each clause is either a tagged table row -- :READ, :WRITE, :RMW, :NOP, or
:BRANCH, naming the addressing mode and operation -- or a literal CASE
clause for an opcode whose real-hardware behavior (stack frames, dummy
reads, interrupt-flag delay) does not reduce to an addressing-mode table.
Keeping the table declarative lets it be read, and audited against a 6502
reference, as data rather than as control flow."
  `(case ,opcode
     ,@(mapcar (lambda (clause) (%expand-cpu-opcode-clause cpu bus clause))
               clauses)))
