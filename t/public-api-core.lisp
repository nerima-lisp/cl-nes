(in-package #:cl-nes/test)

(describe "cartridge construction"
  (it "preserves mapper and CHR-RAM metadata"
    (let ((cartridge (make-fixture-cartridge)))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-chr-writable-p cartridge) :to-be t)
      (expect (length (cartridge-prg-rom cartridge)) :to-be #x8000))))

(describe "controller input"
  (it "serializes the pressed button bits"
    (let ((controller (make-controller)))
      (controller-set-buttons! controller
                                (logior +button-a+ +button-right+))
      (controller-write! controller 1)
      (controller-write! controller 0)
      (expect (controller-read controller) :to-be 1)
      (dotimes (index 6)
        (controller-read controller))
      (expect (controller-read controller) :to-be 1))))

(describe "cartridge-free console lifecycle"
  (it "resets a console before a cartridge is loaded"
    (let ((nes (make-nes)))
      (expect (nes-reset! nes) :to-be nes)
      (expect (cpu-pc (nes-cpu nes)) :to-be 0))))

(describe "NES continuations"
  (it "passes a step result to the continuation"
    (let* ((nes (make-nes :cartridge
                          (make-fixture-cartridge
                           :program '(#xEA #x4C #x00 #x80))))
           (observed nil)
           (result (nes-step/k nes
                               (lambda (cycles)
                                 (setf observed cycles)
                                 :continued))))
      (expect result :to-be :continued)
      (expect observed :to-be 2)))
  (it-each (((#xEA) 2)
            ((#xA9 #x01) 2)
            ((#xE8) 2))
      "passes CPU cycle count for ~S (~D cycles)"
      (program cycles)
    (let ((nes (make-nes :cartridge
                         (make-fixture-cartridge :program program))))
      (expect (nes-step/k nes #'identity) :to-be cycles)))
  (it "passes a complete framebuffer to the continuation"
    (let ((nes (make-nes :cartridge (make-fixture-cartridge)))
          (observed nil))
      (expect (nes-run-frame/k nes
                               (lambda (framebuffer)
                                 (setf observed framebuffer)
                                 :continued))
              :to-be :continued)
      (expect (length observed) :to-be (* 256 240))
      (expect (ppu-frame-ready-p (nes-ppu nes)) :to-be t))))

(describe "APU defaults"
  (it "starts silent"
    (expect (apu-sample (make-apu)) :to-be 0)))

(describe "ROM validation"
  (it "signals invalid-rom for an incomplete image"
    (expect (handler-case
                (progn (load-cartridge #(0)) nil)
              (invalid-rom () t))
            :to-be t)))
