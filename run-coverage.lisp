(in-package #:cl-user)

(defparameter *coverage-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *load-pathname*
                               *default-pathname-defaults*)))

(defparameter *coverage-output-directory*
  (merge-pathnames "coverage/" *coverage-root*))

(defparameter *coverage-target* 1.0d0)

(defparameter *coverage-structural-expression-patterns*
  '("(in-package #:cl-nes)"
    "(defconstant +ppu-decay-period+ 1000000)"))

(defun %coverage-source-file-names ()
  (sort (mapcar (lambda (pathname)
                  (enough-namestring pathname *coverage-root*))
                (directory (merge-pathnames "src/*.lisp"
                                            *coverage-root*)))
        #'string<))

(defparameter *coverage-excluded-source-file-names*
  '("src/package.lisp"
    "src/conditions.lisp"
    "src/macros.lisp"
    "src/apu-data.lisp"
    "src/apu-lifecycle-data.lisp"
    "src/apu-lifecycle-helpers.lisp"
    "src/apu-register-write-helper-macros.lisp"
    "src/apu-register-write-data.lisp"
    "src/apu-register-write-macros.lisp"
    "src/apu-state.lisp"
    "src/cartridge-state.lisp"
    "src/cartridge-construction-data.lisp"
    "src/cartridge-construction-validation-helper-macros.lisp"
    "src/cartridge-layout-data.lisp"
    "src/cartridge-memory-helper-macros.lisp"
    "src/cartridge-mapper5-control-data.lisp"
    "src/controller-state.lisp"
    "src/bus-state.lisp"
    "src/cpu-control-data.lisp"
    "src/cpu-control-helper-macros.lisp"
    "src/cpu-macros.lisp"
    "src/cpu-state.lisp"
    "src/cpu-addressing-macros.lisp"
    "src/cpu-alu-macros.lisp"
    "src/cpu-opcode-helpers.lisp"
    "src/cpu-opcodes-00-7f.lisp"
    "src/cpu-opcodes-00-7f-data.lisp"
    "src/cpu-opcodes-80-ff.lisp"
    "src/cpu-opcodes-80-ff-data.lisp"
    "src/ppu-register-read-data.lisp"
    "src/ppu-register-read-macros.lisp"
    "src/ppu-state.lisp"
    "src/ppu-register-write-data.lisp"
    "src/ppu-register-write-macros.lisp"
    "src/ppu-rendering.lisp"
    "src/nes-state.lisp"))

(defun %coverage-ratio (covered total)
  (if (plusp total)
      (/ (float covered 1.0d0)
         (float total 1.0d0))
      0.0d0))

(defun %assert-coverage-minimum (kind covered total minimum)
  (let ((ratio (%coverage-ratio covered total)))
    (format t "Coverage: ~A ~,2F% (~D/~D), minimum ~,2F%~%"
            kind
            (* 100.0d0 ratio)
            covered
            total
            (* 100.0d0 minimum))
    (unless (>= ratio minimum)
      (error "~A coverage ~,2F% is below the minimum ~,2F%."
             kind
             (* 100.0d0 ratio)
             (* 100.0d0 minimum)))
    ratio))

(defun %ensure-unique-file-list (label names)
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (name names)
      (when (gethash name seen)
        (error "~A contains duplicate entry: ~A" label name))
      (setf (gethash name seen) t)))
  names)

(defun %sorted-string-list (strings)
  (sort (copy-list strings) #'string<))

(defun %assert-coverage-source-manifest ()
  (let* ((actual (%ensure-unique-file-list
                  "Coverage source manifest"
                  (%coverage-source-file-names)))
         (excluded (%ensure-unique-file-list
                    "Coverage excluded manifest"
                    *coverage-excluded-source-file-names*))
         (unknown-exclusions
           (set-difference excluded actual :test #'equal)))
    (unless actual
      (error "Coverage manifest check found no src/*.lisp files."))
    (when unknown-exclusions
      (error "Coverage exclusions mention files absent from src/*.lisp: ~{~A~^, ~}"
             (%sorted-string-list unknown-exclusions)))))

(defun %coverage-structural-expression-count (source-files)
  "Count load-time forms that are not runtime behavior.

ASDF requires each source file to establish its package independently, and
SBCL evaluates DEFCONSTANT while loading the system.  SB-COVER records those
forms as expressions but they cannot be covered by a runtime test.  Keep the
forms in the instrumented source set and normalize only these exact,
manifested declarations out of the aggregate runtime metric."
  (loop for pathname in source-files
        sum (with-open-file (stream pathname)
             (loop for line = (read-line stream nil nil)
                   while line
                   count (member (string-trim '(#\Space #\Tab) line)
                                 *coverage-structural-expression-patterns*
                                 :test #'string=)))))

(require :asdf)
(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))
(load (merge-pathnames "cl-nes.asd" *coverage-root*))
(asdf:oos 'asdf:load-op "cl-nes" :force t)
(asdf:oos 'asdf:load-op "cl-nes/test" :force t)

(%assert-coverage-source-manifest)

(let ((source-files
        (mapcar (lambda (name)
                  (merge-pathnames name *coverage-root*))
                (%coverage-source-file-names)))
      ;; These files contain package/data declarations, compile-time macros,
      ;; state layouts, or condition declarations. Their runtime behavior is
      ;; exercised through the constructors and device functions kept in the
      ;; measured files.
      (excluded-source-files
        (mapcar (lambda (name)
                  (merge-pathnames name *coverage-root*))
                *coverage-excluded-source-file-names*))
      (report-directory (merge-pathnames "html/" *coverage-output-directory*))
      (data-pathname (merge-pathnames "sb-cover.data" *coverage-output-directory*)))
  ;; sb-cover leaves reports for source files removed between runs.
  (dolist (pathname (directory (merge-pathnames "*.html" report-directory)))
    (delete-file pathname))
  (when (probe-file data-pathname)
    (delete-file data-pathname))
  (ensure-directories-exist data-pathname)
  (let ((passed (uiop:symbol-call :cl-weave :run-all
                                  :reporter :spec
                                  :pass-with-no-tests nil
                                  :coverage t
                                  :coverage-output data-pathname
                                  :coverage-report-directory report-directory
                                  :coverage-include-pathnames source-files
                                  :coverage-exclude-pathnames excluded-source-files)))
    (unless passed
        (error "cl-nes coverage suite failed."))
    (let ((statistics (uiop:symbol-call :cl-weave :coverage-statistics
                                         :include-pathnames source-files
                                         :exclude-pathnames excluded-source-files)))
      (let* ((expression-covered (getf statistics :expression-covered))
             (raw-expression-total (getf statistics :expression-total))
            (measured-source-files
              (set-difference source-files excluded-source-files :test #'equal))
            (structural-expression-count
              (%coverage-structural-expression-count measured-source-files))
            (expression-total
              (- raw-expression-total structural-expression-count))
            (branch-covered (getf statistics :branch-covered))
            (branch-total (getf statistics :branch-total)))
        (unless (and (plusp expression-total)
                     (plusp branch-total))
          (error "Coverage collected no executable expressions or branches."))
        (format t "Coverage: structural load-time expressions ~D (raw total ~D)~%"
                structural-expression-count
                raw-expression-total)
        (%assert-coverage-minimum :expression
                                  expression-covered
                                  expression-total
                                  *coverage-target*)
        (%assert-coverage-minimum :branch
                                  branch-covered
                                  branch-total
                                  *coverage-target*)
        (format t "Coverage target: expression ~,2F%, branch ~,2F%~%"
                (* 100.0d0 *coverage-target*)
                (* 100.0d0 *coverage-target*))))))
