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

(defun %file-size (pathname)
  (with-open-file (stream pathname
                          :direction :input
                          :element-type '(unsigned-byte 8))
    (or (file-length stream) 0)))

(defun %assert-coverage-artifacts (data-pathname report-directory)
  (let ((reports (directory (merge-pathnames "*.html" report-directory))))
    (unless (and (probe-file data-pathname)
                 (plusp (%file-size data-pathname))
                 reports
                 (every (lambda (pathname)
                          (and (probe-file pathname)
                               (plusp (%file-size pathname))))
                        reports))
      (error "Coverage artifacts are missing or empty."))
    (format t "Coverage artifacts: ~D non-empty HTML reports and ~D data bytes~%"
            (length reports)
            (%file-size data-pathname))))

(defun %package-symbol-call (package-name symbol-name &rest arguments)
  (let ((package (find-package package-name)))
    (unless package
      (error "Package ~A is not loaded." package-name))
    (apply (find-symbol symbol-name package) arguments)))

(defun %coverage-file-statistics (source-files excluded-source-files)
  "Return deterministic per-file coverage rows for the measured sources.

This uses cl-weave's SB-COVER integration directly so the report identifies
the next test seam without parsing generated HTML."
  (let* ((matcher (%package-symbol-call :cl-weave "COVERAGE-SOURCE-MATCHER"
                                        source-files excluded-source-files))
         (coverage-symbol
           (%package-symbol-call :cl-weave "COVERAGE-INTERNAL-SYMBOL"
                                 "*CODE-COVERAGE-INFO*" t))
         (compute-symbol
           (%package-symbol-call :cl-weave "COVERAGE-INTERNAL-SYMBOL"
                                 "COMPUTE-FILE-INFO" t))
         (ok-symbol
           (%package-symbol-call :cl-weave "COVERAGE-INTERNAL-SYMBOL" "OK-OF" t))
         (all-symbol
           (%package-symbol-call :cl-weave "COVERAGE-INTERNAL-SYMBOL" "ALL-OF" t))
         (refresh-symbol
           (%package-symbol-call :cl-weave "COVERAGE-INTERNAL-SYMBOL"
                                 "REFRESH-COVERAGE-BITS" t))
         (coverage-info (symbol-value coverage-symbol)))
    (funcall refresh-symbol)
    (sort
     (loop for source being the hash-keys of (car coverage-info)
           when (and (funcall matcher source) (probe-file source))
             collect
             (let* ((counts (funcall compute-symbol source :default))
                    (expression (getf counts :expression))
                    (branch (getf counts :branch)))
               (list source
                     (funcall ok-symbol expression)
                     (funcall all-symbol expression)
                     (funcall ok-symbol branch)
                     (funcall all-symbol branch))))
     #'string<
     :key #'first)))

(defun %write-coverage-summary (pathname statistics file-statistics)
  (with-open-file (summary pathname
                           :direction :output
                           :if-exists :supersede)
    (format summary "expression-covered=~D~%expression-total=~D~%branch-covered=~D~%branch-total=~D~%"
            (getf statistics :expression-covered)
            (getf statistics :expression-total)
            (getf statistics :branch-covered)
            (getf statistics :branch-total))
    (dolist (row file-statistics)
      (destructuring-bind (source expression-covered expression-total
                           branch-covered branch-total)
          row
        (format summary "file=~A expression=~D/~D branch=~D/~D~%"
                (enough-namestring source *coverage-root*)
                expression-covered expression-total
                branch-covered branch-total)))))

(require :asdf)
(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))
(load (merge-pathnames "cl-nes.asd" *coverage-root*))
;; The check phase compiles ordinary FASLs first.  Reusing those FASLs here
;; would make SB-COVER report mostly uninstrumented code, so compile again
;; after enabling coverage collection.
(asdf:oos 'asdf:compile-op "cl-nes" :force t)
(asdf:oos 'asdf:load-op "cl-nes" :force t)
(asdf:oos 'asdf:compile-op "cl-nes/test" :force t)
(asdf:oos 'asdf:load-op "cl-nes/test" :force t)

(let ((source-files
        (mapcar (lambda (name) (merge-pathnames name *coverage-root*))
                '("src/core/package.lisp" "src/core/conditions.lisp"
                  "src/core/macros.lisp"
                  "src/apu/apu-data.lisp" "src/apu/apu-state.lisp"
                  "src/apu/apu-construction.lisp" "src/apu/apu-output.lisp"
                  "src/apu/apu-status.lisp" "src/apu/apu.lisp"
                  "src/apu/apu-lifecycle.lisp" "src/apu/apu-envelopes.lisp"
                  "src/apu/apu-timers.lisp" "src/apu/apu-frame.lisp"
                  "src/apu/apu-timing.lisp" "src/apu/apu-registers.lisp"
                  "src/cartridge/cartridge-state.lisp"
                  "src/cartridge/cartridge-state-constructors.lisp"
                  "src/cartridge/cartridge-state-forwarders.lisp"
                  "src/cartridge/cartridge-data.lisp"
                  "src/cartridge/cartridge-format.lisp"
                  "src/cartridge/mappers/cartridge-mapper1.lisp"
                  "src/cartridge/mappers/cartridge-mapper22-28.lisp"
                  "src/cartridge/mappers/cartridge-mapper4.lisp"
                  "src/cartridge/mappers/cartridge-mapper4-control.lisp"
                  "src/cartridge/mappers/cartridge-mapper5.lisp"
                  "src/cartridge/mappers/cartridge-mapper5-expansion.lisp"
                  "src/cartridge/cartridge-memory.lisp"
                  "src/cartridge/cartridge-memory-accessors.lisp"
                  "src/cartridge/cartridge-memory-bus.lisp"
                  "src/cartridge/cartridge-reset.lisp"
                  "src/cartridge/cartridge-validation.lisp"
                  "src/system/controller-state.lisp" "src/system/controller.lisp"
                  "src/ppu/ppu-state.lisp" "src/ppu/ppu.lisp"
                  "src/ppu/ppu-memory.lisp" "src/ppu/ppu-registers.lisp"
                  "src/ppu/ppu-rendering.lisp" "src/ppu/ppu-timing.lisp"
                  "src/system/bus-state.lisp" "src/system/bus.lisp"
                  "src/cpu/cpu-state.lisp" "src/cpu/cpu.lisp"
                  "src/cpu/cpu-alu.lisp" "src/cpu/cpu-addressing.lisp"
                  "src/cpu/cpu-control.lisp" "src/cpu/cpu-opcodes-00-7f.lisp"
                  "src/cpu/cpu-opcodes-80-ff.lisp"
                  "src/cpu/cpu-instructions.lisp"
                  "src/system/nes-state.lisp" "src/system/nes.lisp"
                  "src/system/nes-timing.lisp"
                  "src/system/nes-execution.lisp")))
      ;; These files contain package/data declarations, compile-time macros,
      ;; state layouts, or condition declarations. Their runtime behavior is
      ;; exercised through the constructors and device functions kept in the
      ;; measured files.
      (excluded-source-files
        (mapcar (lambda (name)
                  (merge-pathnames name *coverage-root*))
                '("src/core/package.lisp" "src/core/conditions.lisp"
                  "src/core/macros.lisp" "src/apu/apu-data.lisp"
                  "src/apu/apu-state.lisp"
                  "src/cartridge/cartridge-state.lisp"
                  "src/system/controller-state.lisp"
                  "src/system/bus-state.lisp" "src/cpu/cpu-state.lisp"
                  "src/ppu/ppu-state.lisp" "src/system/nes-state.lisp")))
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
                                  :seed 20260813
                                  :pass-with-no-tests nil
                                  :coverage t
                                  :coverage-output data-pathname
                                  :coverage-report-directory report-directory
                                  :coverage-include-pathnames source-files
                                  :coverage-exclude-pathnames excluded-source-files)))
    (unless passed
        (error "cl-nes coverage suite failed."))
    (%assert-coverage-artifacts data-pathname report-directory)
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
        (%write-coverage-summary
         (merge-pathnames "coverage-summary.txt" *coverage-output-directory*)
         statistics
         (%coverage-file-statistics source-files excluded-source-files))
        (format t "Coverage target (future gate): expression ~,2F%, branch ~,2F%~%"
                (* 100.0d0 *coverage-target*)
                (* 100.0d0 *coverage-target*))))))
