(in-package #:cl-nes/test)

(describe "Save-state contracts"
  (it "round-trips the complete machine deterministically"
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (first (progn
                    (setf (cl-nes::nes-irq-line-sample-p nes) t
                          (cl-nes::nes-master-clock nes) #x123456
                          (cl-nes::nes-ppu-phase-offset nes) 3
                          (cl-nes::bus-dmc-dma-apu-phase-offset (nes-bus nes)) 0
                          (cl-nes::bus-dmc-dma-start-apu-phase (nes-bus nes)) 1
                          (cl-nes::bus-dmc-dma-apu-phase-pending-p (nes-bus nes)) t)
                    (nes-save-state nes))))
      (expect (aref first 4) :to-be 3)
      (nes-run-frames/k nes 1 (lambda (framebuffer)
                                (declare (ignore framebuffer))
                                nil))
      (progn
        (setf (cl-nes::bus-dmc-dma-apu-phase-offset (nes-bus nes)) 1
              (cl-nes::bus-dmc-dma-start-apu-phase (nes-bus nes)) 0
              (cl-nes::bus-dmc-dma-apu-phase-pending-p (nes-bus nes)) nil)
        (nes-load-state nes first))
      (expect (cl-nes::nes-master-clock nes) :to-be #x123456)
      (progn
        (expect (cl-nes::nes-ppu-phase-offset nes) :to-be 3)
        (expect (cl-nes::bus-dmc-dma-apu-phase-offset (nes-bus nes)) :to-be 0)
        (expect (cl-nes::bus-dmc-dma-start-apu-phase (nes-bus nes)) :to-be 1)
        (expect (cl-nes::bus-dmc-dma-apu-phase-pending-p (nes-bus nes)) :to-be t)
        (expect (equalp (nes-save-state nes) first) :to-be t))))

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
      (expect (equalp left-samples right-samples) :to-be t)))

  (it "round-trips in-progress sprite evaluation state"
    (let* ((source (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (target (make-nes :cartridge (make-fixture-cartridge :program '(#xEA))))
           (source-ppu (nes-ppu source))
           (target-ppu (nes-ppu target))
           (state nil))
      (setf (cl-nes::ppu-secondary-oam-count source-ppu) 1
            (cl-nes::ppu-sprite-evaluation-index source-ppu) 4
            (cl-nes::ppu-sprite-evaluation-n source-ppu) 8
            (cl-nes::ppu-sprite-evaluation-m source-ppu) 2
            (cl-nes::ppu-sprite-evaluation-overflow-counter source-ppu) 2
            (cl-nes::ppu-sprite-evaluation-latch source-ppu) #xFD
            (cl-nes::ppu-sprite-evaluation-done-p source-ppu) t
            (cl-nes::ppu-sprite-render-count source-ppu) 2
            (aref (cl-nes::ppu-secondary-oam source-ppu) 0) #xFD
            (aref (cl-nes::ppu-sprite-indexes source-ppu) 0) 4
            (aref (cl-nes::ppu-sprite-evaluated-indexes source-ppu) 0) 7)
      (setf (cl-nes::ppu-sprite-evaluation-active-p source-ppu) t)
      (setf state (nes-save-state source))
      (nes-load-state target state)
      (expect (cl-nes::ppu-secondary-oam-count target-ppu) :to-be 1)
      (expect (cl-nes::ppu-sprite-evaluation-index target-ppu) :to-be 4)
      (expect (cl-nes::ppu-sprite-evaluation-n target-ppu) :to-be 8)
      (expect (cl-nes::ppu-sprite-evaluation-m target-ppu) :to-be 2)
      (expect (cl-nes::ppu-sprite-evaluation-overflow-counter target-ppu) :to-be 2)
      (expect (cl-nes::ppu-sprite-evaluation-latch target-ppu) :to-be #xFD)
      (expect (cl-nes::ppu-sprite-evaluation-done-p target-ppu) :to-be t)
      (expect (cl-nes::ppu-sprite-evaluation-active-p target-ppu) :to-be t)
      (expect (cl-nes::ppu-sprite-render-count target-ppu) :to-be 2)
      (expect (aref (cl-nes::ppu-secondary-oam target-ppu) 0) :to-be #xFD)
      (expect (aref (cl-nes::ppu-sprite-indexes target-ppu) 0) :to-be 4)
      (expect (aref (cl-nes::ppu-sprite-evaluated-indexes target-ppu) 0) :to-be 7))))

  (it "signals a dedicated condition for malformed headers and truncation"
    (let* ((nes (make-nes))
           (state (nes-save-state nes))
           (short (subseq state 0 (1- (length state))))
           (bad-magic (copy-seq state))
           (old-version (copy-seq state)))
      (setf (aref bad-magic 0) 0 (aref old-version 4) 2)
      (dolist (input (list short bad-magic))
        (expect (typep (captured-condition
                        (lambda () (nes-load-state nes input)))
                'invalid-savestate)
                :to-be t))
      (let ((condition (captured-condition
                        (lambda () (nes-load-state nes old-version)))))
        (expect (typep condition 'invalid-savestate) :to-be t)
        (expect (invalid-savestate-reason condition)
                :to-be :unsupported-version))))

  (it "does not partially apply a state when a later section is invalid"
    (let* ((nes (make-nes))
           (before (nes-save-state nes))
           (machine-state (cl-nes::nes-state-save nes))
           (machine-section-length-offset
             (- (length before) (length machine-state) 4))
           (broken (copy-seq before)))
      ;; The final section length is a 32-bit value immediately before its body.
      (setf (aref broken (+ machine-section-length-offset 3)) #xff)
      (expect (typep (captured-condition
                      (lambda () (nes-load-state nes broken)))
                     (quote invalid-savestate))
              :to-be t)
      (expect (equalp (nes-save-state nes) before) :to-be t)))

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

  (it "does not let a section reader consume later section bytes"
    (let ((input #(1 0 0 0 42 99)))
      (expect (typep (captured-condition
                      (lambda ()
                        (cl-nes::%savestate-read-section
                         (lambda (section position)
                           (cl-nes::%state-read-byte
                            section
                            (nth-value 1
                                       (cl-nes::%state-read-byte section position)))
                           (values :state 5))
                         input 0)))
                     'invalid-savestate)
              :to-be t)))

  (it "rejects a shortened section without changing the machine"
    (let* ((nes (make-nes))
           (before (nes-save-state nes))
           (broken (copy-seq before)))
      (decf (aref broken 8) 1)
      (expect (typep (captured-condition
                      (lambda () (nes-load-state nes broken)))
                     'invalid-savestate)
              :to-be t)
      (expect (equalp (nes-save-state nes) before) :to-be t)))

  (it "rejects invalid Unicode scalar values in symbols"
    (dolist (code '(#xD800 #x110000))
      (let ((input (vector 3 1 0 0 0
                           (ldb (byte 8 0) code)
                           (ldb (byte 8 8) code)
                           (ldb (byte 8 16) code)
                           (ldb (byte 8 24) code))))
        (expect (typep (captured-condition
                        (lambda ()
                          (cl-nes::%state-read-value input 0)))
                       'invalid-savestate)
                :to-be t))))

  (it "accepts zero and maximum collection lengths"
    (expect (cl-nes::%state-check-collection-length 0 #(0) 0 1)
            :to-be 0)
    (let ((input (make-array cl-nes::+max-state-collection-length+
                             :element-type '(unsigned-byte 8)
                             :initial-element 0)))
      (expect (cl-nes::%state-check-collection-length
               cl-nes::+max-state-collection-length+ input 0 1)
              :to-be cl-nes::+max-state-collection-length+)))

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
  (it "round-trips a latched background V high byte"
    (let* ((source (make-nes :cartridge (make-fixture-cartridge :program (quote (#xEA)))))
           (target (make-nes :cartridge (make-fixture-cartridge :program (quote (#xEA)))))
           (source-ppu (nes-ppu source))
           (target-ppu (nes-ppu target)))
      (setf (cl-nes::ppu-background-fetch-phase source-ppu) 1
            (cl-nes::ppu-background-fetch-address source-ppu) #x2C19
            (cl-nes::ppu-background-fetch-v-high source-ppu) #x2C00
            (cl-nes::ppu-address-latch-low source-ppu) #x19
            (cl-nes::ppu-vram-address source-ppu) #x3C00)
      (nes-load-state target (nes-save-state source))
      (expect (cl-nes::ppu-background-fetch-v-high target-ppu) :to-be #x2C00)
      (expect (cl-nes::%ppu-background-read-address target-ppu 1)
              :to-be #x3C19)))
  (it "round-trips a phase-latched pending T-to-V address copy"
    (let* ((source (make-nes :cartridge (make-fixture-cartridge :program (quote (#xEA)))))
           (target (make-nes :cartridge (make-fixture-cartridge :program (quote (#xEA)))))
           (source-ppu (nes-ppu source))
           (target-ppu (nes-ppu target)))
      (ppu-write-vram! source-ppu #x2F19 #xCA)
      (ppu-write-vram! target-ppu #x2F19 #xCA)
      (setf (ppu-mask source-ppu) #x08
            (cl-nes::ppu-scanline source-ppu) 5
            (cl-nes::ppu-dot source-ppu) 185
            (cl-nes::ppu-background-fetch-phase source-ppu) 1
            (cl-nes::ppu-background-fetch-address source-ppu) #x2F19
            (cl-nes::ppu-background-fetch-v-high source-ppu) #x3F00
            (cl-nes::ppu-address-latch-low source-ppu) #x19
            (cl-nes::ppu-vram-address source-ppu) #x7F19
            (cl-nes::ppu-temporary-address source-ppu) #x2F00
            (cl-nes::ppu-pending-vram-address-copy-p source-ppu) t
            (cl-nes::ppu-pending-vram-address-copy-delay source-ppu) 1
            (cl-nes::ppu-pending-vram-address-copy-value source-ppu) #x2F00
            (cl-nes::ppu-pending-vram-address-copy-wait-for-phase1-p source-ppu) t
            (cl-nes::ppu-pending-vram-address-copy-phase1-seen-p source-ppu) t)
      (let ((state (nes-save-state source)))
        (expect (aref state 4) :to-be 3)
        (nes-load-state target state))
      (expect (cl-nes::ppu-pending-vram-address-copy-p target-ppu) :to-be t)
      (expect (cl-nes::ppu-pending-vram-address-copy-delay target-ppu) :to-be 1)
      (expect (cl-nes::ppu-pending-vram-address-copy-wait-for-phase1-p target-ppu)
              :to-be t)
      (expect (cl-nes::ppu-pending-vram-address-copy-phase1-seen-p target-ppu)
              :to-be t)
      (expect (cl-nes::ppu-vram-address target-ppu) :to-be #x7F19)
      (ppu-tick! target-ppu)
      (expect (cl-nes::ppu-dot target-ppu) :to-be 186)
      (expect (cl-nes::ppu-pending-vram-address-copy-p target-ppu) :to-be nil)
      (expect (cl-nes::ppu-pending-vram-address-copy-wait-for-phase1-p target-ppu)
              :to-be nil)
      (expect (cl-nes::ppu-pending-vram-address-copy-phase1-seen-p target-ppu)
              :to-be nil)
      (expect (cl-nes::ppu-vram-address target-ppu) :to-be #x2F00)
      (expect (cl-nes::ppu-address-bus target-ppu) :to-be #x2F19)
      (expect (cl-nes::ppu-next-tile target-ppu) :to-be #xCA)))
