(in-package #:cl-nes/rom-suite)

(defun marked-hex (line marker)
  (let ((position (search marker line)))
    (and position
         (parse-integer line :start (+ position (length marker))
                              :radix 16 :junk-allowed t))))

(defun nestest-line (line)
  (let* ((pc (parse-integer line :start 0 :end 4 :radix 16))
         (a (marked-hex line "A:"))
         (x (marked-hex line "X:"))
         (y (marked-hex line "Y:"))
         (p (marked-hex line "P:"))
         (sp (marked-hex line "SP:"))
         (cyc-position (search "CYC:" line))
         (cyc (and cyc-position
                   (parse-integer line :start (+ cyc-position 4)
                                        :radix 10 :junk-allowed t))))
    (list :pc pc :a a :x x :y y :p p :sp sp :cyc cyc)))

(defun cpu-state (nes)
  (let ((cpu (cl-nes:nes-cpu nes)))
    (list :pc (cl-nes:cpu-pc cpu) :a (cl-nes:cpu-a cpu)
          :x (cl-nes:cpu-x cpu) :y (cl-nes:cpu-y cpu)
          :p (cl-nes:cpu-p cpu) :sp (cl-nes:cpu-sp cpu)
          :cyc (cl-nes:cpu-cycles cpu))))

(defun first-state-difference (expected actual line-number line)
  (dolist (key '(:pc :a :x :y :p :sp :cyc))
    (unless (= (getf expected key) (getf actual key))
      (return-from first-state-difference
        (format nil "line ~D (~A): ~A expected ~A actual ~A"
                line-number key line
                (if (eq key :cyc)
                    (format nil "~D" (getf expected key))
                    (format nil "~2,'0X" (getf expected key)))
                (if (eq key :cyc)
                    (format nil "~D" (getf actual key))
                    (format nil "~2,'0X" (getf actual key)))))))
  nil)

(defun run-nestest-trace ()
  (let ((rom (or (uiop:getenv *nestest-rom-environment*)
                 (let ((root (uiop:getenv *rom-root-environment*)))
                   (and root (merge-pathnames "other/nestest.nes" root)))))
        (log (uiop:getenv *nestest-log-environment*)))
    (unless (and rom log (probe-file rom) (probe-file log))
      (error "nestest inputs missing: ROM=~A LOG=~A" rom log))
    (let ((nes (cl-nes:make-nes :cartridge (cl-nes:load-cartridge rom))))
      ;; nestest's automation contract starts at $C000, while this ROM's
      ;; reset vector enters at $C004. The public API intentionally exposes
      ;; CPU state read access only, so this harness uses the state accessor
      ;; here to select the documented automation entry point.
      (setf (cl-nes::cpu-pc (cl-nes:nes-cpu nes)) #xc000)
      ;; PPU scanline/dot are intentionally excluded: the current public API
      ;; exposes the framebuffer and frame-ready flag, but no scanline/dot
      ;; accessors. The omitted fields are recorded here rather than silently
      ;; treating the CPU-only trace as a complete PPU golden trace.
      (with-open-file (stream log)
        (loop for line = (read-line stream nil nil)
              for line-number from 1
              while line
              for expected = (nestest-line line)
              for actual = (cpu-state nes)
              unless (zerop (getf expected :cyc))
                do (let ((difference (first-state-difference expected actual line-number line)))
                     (when difference
                       (format t "nestest first difference: ~A~%" difference)
                       (return difference)))
                   (cl-nes:nes-step/k nes #'identity))))))
