(in-package #:cl-user)

(defparameter *coverage-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *load-pathname*
                               *default-pathname-defaults*)))

(defparameter *coverage-output-directory*
  (merge-pathnames "coverage/" *coverage-root*))

(defparameter *minimum-expression-coverage* 0.96d0)
(defparameter *minimum-branch-coverage* 0.86d0)
(defparameter *coverage-target* 1.0d0)

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

(require :asdf)
(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))
(load (merge-pathnames "cl-nes.asd" *coverage-root*))
(asdf:oos 'asdf:load-op "cl-nes" :force t)
(asdf:oos 'asdf:load-op "cl-nes/test" :force t)

(let ((source-files
        (mapcar (lambda (name)
                  (merge-pathnames name *coverage-root*))
                '("src/package.lisp"
                  "src/conditions.lisp"
                  "src/macros.lisp"
                  "src/apu-data.lisp"
                  "src/apu-state.lisp"
                  "src/apu-construction.lisp"
                  "src/cartridge-state.lisp"
                  "src/cartridge-data.lisp"
                  "src/cartridge-format.lisp"
                  "src/cartridge-mapper1.lisp"
                  "src/cartridge-mapper22-28.lisp"
                  "src/cartridge-mapper4.lisp"
                  "src/cartridge-mapper5.lisp"
                  "src/cartridge-memory.lisp"
                  "src/controller-state.lisp"
                  "src/controller.lisp"
                  "src/apu.lisp"
                  "src/apu-lifecycle.lisp"
                  "src/apu-envelopes.lisp"
                  "src/apu-timers.lisp"
                  "src/apu-frame.lisp"
                  "src/apu-timing.lisp"
                  "src/apu-registers.lisp"
                  "src/ppu-state.lisp"
                  "src/ppu.lisp"
                  "src/ppu-rendering.lisp"
                  "src/ppu-timing.lisp"
                  "src/bus-state.lisp"
                  "src/bus.lisp"
                  "src/cpu-state.lisp"
                  "src/cpu.lisp"
                  "src/cpu-alu.lisp"
                  "src/cpu-control.lisp"
                  "src/cpu-instructions.lisp"
                  "src/nes-state.lisp"
                  "src/nes.lisp"
                  "src/nes-timing.lisp"
                  "src/nes-execution.lisp")))
      ;; These files contain package/data declarations, compile-time macros,
      ;; state layouts, or condition declarations. Their runtime behavior is
      ;; exercised through the constructors and device functions kept in the
      ;; measured files.
      (excluded-source-files
        (mapcar (lambda (name)
                  (merge-pathnames name *coverage-root*))
                '("src/package.lisp"
                  "src/conditions.lisp"
                  "src/macros.lisp"
                  "src/apu-data.lisp"
                  "src/apu-state.lisp"
                  "src/cartridge-state.lisp"
                  "src/controller-state.lisp"
                  "src/bus-state.lisp"
                  "src/cpu-state.lisp"
                  "src/ppu-state.lisp"
                  "src/nes-state.lisp")))
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
      (let ((expression-covered (getf statistics :expression-covered))
            (expression-total (getf statistics :expression-total))
            (branch-covered (getf statistics :branch-covered))
            (branch-total (getf statistics :branch-total)))
        (unless (and (plusp expression-total)
                     (plusp branch-total))
          (error "Coverage collected no executable expressions or branches."))
        (%assert-coverage-minimum :expression
                                  expression-covered
                                  expression-total
                                  *minimum-expression-coverage*)
        (%assert-coverage-minimum :branch
                                  branch-covered
                                  branch-total
                                  *minimum-branch-coverage*)
        (format t "Coverage target (future gate): expression ~,2F%, branch ~,2F%~%"
                (* 100.0d0 *coverage-target*)
                (* 100.0d0 *coverage-target*))))))
