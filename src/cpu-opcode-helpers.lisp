(in-package #:cl-nes)

(defmacro %opcode-read (mode operation page-cross-p)
  `(%read-op! cpu bus ,mode ,operation ,page-cross-p))

(defmacro %opcode-rmw (mode operation cycles)
  `(%rmw-op! cpu bus ,mode ,operation ,cycles))

(defmacro %opcode-write (mode value)
  `(%write-op! cpu bus ,mode ,value))

(defmacro %opcode-branch (condition)
  `(%branch! cpu bus ,condition))

(defmacro %opcode-flag (flag value)
  `(progn
     (%set-flag! cpu ,flag ,value)
     2))

(defmacro %opcode-transfer (place value)
  `(progn
     (setf ,place ,value)
     (%update-zn! cpu ,place)
     2))

(defmacro %opcode-adjust-register (place operator)
  `(progn
     (setf ,place (mod (,operator ,place) 256))
     (%update-zn! cpu ,place)
     2))

(defmacro %opcode-accumulator-op (operator)
  `(progn
     (setf (cpu-a cpu) (,operator cpu (cpu-a cpu)))
     2))

(defmacro define-opcode-dispatch (name groups &body clauses)
  (labels ((expand-opcode-clauses (specs expander)
             (mapcar (lambda (spec)
                       (destructuring-bind (opcode . arguments) spec
                         `(,opcode (,expander ,@arguments))))
                     specs))
           (expand-opcode-literal-clauses (specs)
             (mapcar (lambda (spec)
                       (destructuring-bind (opcode value) spec
                         `(,opcode ,value)))
                     specs))
           (expand-opcode-dispatch-group (group)
             (destructuring-bind (expander specs-name) group
               (let ((specs (symbol-value specs-name)))
                 (case expander
                   (%expand-opcode-read-clauses
                    (expand-opcode-clauses specs '%opcode-read))
                   (%expand-opcode-rmw-clauses
                    (expand-opcode-clauses specs '%opcode-rmw))
                   (%expand-opcode-write-clauses
                    (expand-opcode-clauses specs '%opcode-write))
                   (%expand-opcode-branch-clauses
                    (expand-opcode-clauses specs '%opcode-branch))
                   (%expand-opcode-flag-clauses
                    (expand-opcode-clauses specs '%opcode-flag))
                   (%expand-opcode-transfer-clauses
                    (expand-opcode-clauses specs '%opcode-transfer))
                   (%expand-opcode-adjust-register-clauses
                    (expand-opcode-clauses specs '%opcode-adjust-register))
                   (%expand-opcode-accumulator-clauses
                    (expand-opcode-clauses specs '%opcode-accumulator-op))
                   (%expand-opcode-literal-clauses
                    (expand-opcode-literal-clauses specs))
                   (otherwise
                    (error "Unknown opcode clause expander: ~S"
                           expander))))))
           (expand-opcode-dispatch-groups (dispatch-groups)
             (mapcan #'expand-opcode-dispatch-group dispatch-groups)))
    (let ((expanded-groups
            (expand-opcode-dispatch-groups groups)))
      `(defmacro ,name ()
         `(case opcode
            ,@',expanded-groups
            ,@',clauses)))))
