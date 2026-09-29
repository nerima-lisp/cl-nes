(in-package #:cl-nes)

(defmacro define-hardware-state
    (name slots &key constructor reset reset-preserve console-reset
                              console-preserve console-reset-values)
  "Define a typed hardware state and its generated reset operations.

Each slot is (NAME DEFAULT TYPE ACCESSOR). The declaration is also the
ordered source for future serialization."
  (let ((constructor (or constructor
                         (intern (format nil "%MAKE-~A" name)
                                 (symbol-package name))))
        (reset (or reset
                   (intern (format nil "~A-RESET!" name)
                           (symbol-package name))))
        (console-reset (or console-reset
                           (intern (format nil "~A-CONSOLE-RESET!" name)
                                   (symbol-package name))))
        (predicate (intern (format nil "~A-P" name)
                           (symbol-package name))))
    (labels ((slot-name (slot) (first slot))
             (slot-default (slot) (second slot))
             (slot-type (slot) (third slot))
             (slot-accessor (slot)
               (or (fourth slot)
                   (intern (format nil "~A-~A" name (first slot))
                           (symbol-package name))))
             (slot-definition (slot)
               `(,(slot-name slot) ,(slot-default slot)
                 ,@(when (slot-type slot) `(:type ,(slot-type slot)))))
             (constructor-key (slot)
               `(,(slot-name slot) ,(slot-default slot)))
             (path-form (path)
               (let* ((root-name (first path))
                      (root (find root-name slots :key #'slot-name)))
                 (unless root
                   (error "Unknown hardware-state slot ~S in path ~S"
                          root-name path))
                 (reduce (lambda (form accessor) `(,accessor ,form))
                         (rest path)
                         :initial-value `(,(slot-accessor root) state)))))
      (let* ((preserve (or reset-preserve '()))
             (bindings (mapcar (lambda (path)
                                 (list (gensym "VALUE") (path-form path)))
                               console-preserve)))
        `(progn
           (defstruct (,name
                        (:constructor ,constructor
                            (&key ,@(mapcar #'constructor-key slots)))
                        (:predicate ,predicate))
             ,@(mapcar #'slot-definition slots))
           (defun ,reset (state)
             ,@(mapcar (lambda (slot)
                         (unless (member (slot-name slot) preserve)
                           `(setf (,(slot-accessor slot) state)
                                  ,(slot-default slot))))
                       slots)
             state)
           (defun ,console-reset (state)
             (let ,bindings
               (,reset state)
               ,@(mapcar (lambda (binding path)
                           `(setf ,(path-form path) ,(first binding)))
                         bindings
                         console-preserve)
               ,@(mapcar (lambda (path-value)
                           `(setf ,(path-form (first path-value))
                                  ,(second path-value)))
                         console-reset-values)
               state))
           ',name)))))
