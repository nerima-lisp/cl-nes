(in-package #:cl-nes/test)

(describe "Save-state contracts"
  (it "round-trips the complete machine deterministically"
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (first (nes-save-state nes)))
      (nes-run-frames/k nes 1 (lambda (framebuffer)
                                (declare (ignore framebuffer))
                                nil))
      (nes-load-state nes first)
      (expect (equalp (nes-save-state nes) first) :to-be t)))

  (it "continues with identical CPU and framebuffer results after restore"
    (dolist (frames '(0 1 2))
      (let ((left (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
            (right (make-nes :cartridge (make-fixture-cartridge :program '(#xEA)))))
        (dotimes (index frames)
          (declare (ignore index))
          (nes-run-frame/k left (lambda (framebuffer)
                                  (declare (ignore framebuffer))
                                  nil)))
        (nes-load-state right (nes-save-state left))
        (nes-run-frame/k left (lambda (framebuffer)
                                (declare (ignore framebuffer))
                                nil))
        (nes-run-frame/k right (lambda (framebuffer)
                                 (declare (ignore framebuffer))
                                 nil))
        (expect (equalp (ppu-framebuffer (nes-ppu left))
                        (ppu-framebuffer (nes-ppu right)))
                :to-be t)
        (expect (cpu-cycles (nes-cpu left))
                :to-be (cpu-cycles (nes-cpu right))))))

  (it "continues with identical audio sample buffers after restore"
    (let* ((left (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (right (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (state (progn
                    (nes-run-frame/k left (lambda (framebuffer)
                                            (declare (ignore framebuffer))
                                            nil))
                    (nes-save-state left)))
           (left-samples nil)
           (right-samples nil))
      (nes-load-state right state)
      (flet ((collect (target)
               (lambda (buffer)
                 (declare (ignore buffer))
                 (setf (symbol-value target)
                       (append (symbol-value target)
                               (coerce (nes-audio-buffer-samples buffer)
                                       'list))))))
        (let ((left-target (gensym))
              (right-target (gensym)))
          (progv (list left-target right-target) (list nil nil)
            (nes-run-frames/k
             left 1 (lambda (framebuffer) (declare (ignore framebuffer)) nil)
             :audio-buffer (make-nes-audio-buffer :size 64)
             :audio-continuation (collect left-target))
            (nes-run-frames/k
             right 1 (lambda (framebuffer) (declare (ignore framebuffer)) nil)
             :audio-buffer (make-nes-audio-buffer :size 64)
             :audio-continuation (collect right-target))
            (setf left-samples (symbol-value left-target)
                  right-samples (symbol-value right-target)))))
      (expect (equalp left-samples right-samples) :to-be t))))

  (it "signals a dedicated condition for malformed headers and truncation"
    (let* ((nes (make-nes))
           (state (nes-save-state nes))
           (short (subseq state 0 (1- (length state))))
           (bad-magic (copy-seq state))
           (bad-version (copy-seq state)))
      (setf (aref bad-magic 0) 0
            (aref bad-version 4) 2)
      (dolist (input (list short bad-magic bad-version))
        (expect (typep (captured-condition
                        (lambda () (nes-load-state nes input)))
                'invalid-savestate)
                :to-be t))))

  (it "rejects collection lengths beyond the remaining input"
    (let ((invalid-string (vector 3 #xff #xff #xff #xff))
          (invalid-vector (vector 4 #xff #xff #xff #xff)))
      (dolist (input (list invalid-string invalid-vector))
        (expect (typep (captured-condition
                        (lambda ()
                          (cl-nes::%state-read-value input 0)))
                       'invalid-savestate)
                :to-be t))
      (expect (typep (captured-condition
                      (lambda ()
                        (cl-nes::%state-check-collection-length
                         (1+ cl-nes::+max-state-collection-length+)
                         #(0) 0 1)))
                     'invalid-savestate)
              :to-be t)))

  (it "keeps generated state slots symmetric"
    (dolist (state (list (make-apu) (make-cpu) (make-controller)
                         (make-ppu) (make-bus) (make-nes)))
      (let* ((name (type-of state))
             (save (symbol-function
                    (intern (format nil "~A-STATE-SAVE" name)
                            (symbol-package name))))
             (load (symbol-function
                    (intern (format nil "~A-STATE-LOAD" name)
                            (symbol-package name))))
             (octets (funcall save state)))
        (funcall load state octets)
        (expect (equalp (funcall save state) octets) :to-be t))))

  (it "round-trips mapper state for the supported mapper fixtures"
    (dolist (spec '((0 2 8) (1 4 8) (4 8 8) (5 8 8)))
      (destructuring-bind (mapper prg-banks chr-banks) spec
        (let* ((cartridge (make-patterned-cartridge
                           :mapper mapper :prg-banks prg-banks
                           :chr-banks chr-banks))
               (nes (make-nes :cartridge cartridge))
               (state (nes-save-state nes)))
          (nes-load-state nes state)
          (expect (equalp state (nes-save-state nes)) :to-be t)))))
