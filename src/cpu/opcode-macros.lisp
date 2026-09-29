(in-package #:cl-nes)

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
  "Expand the declarative 6502 opcode table into a CASE dispatch."
  `(case ,opcode
     ,@(mapcar (lambda (clause) (%expand-cpu-opcode-clause cpu bus clause))
               clauses)))
