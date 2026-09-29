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
        (expect (equalp (funcall save state) octets) :to-be t)))))

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
