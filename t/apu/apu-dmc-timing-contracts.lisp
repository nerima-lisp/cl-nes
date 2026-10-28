(in-package #:cl-nes/test)

(describe "APU DMC timing contracts"
          (it "clocks DMC bits and treats negative cycles as a no-op"
              (with-fixture-apu (apu nil nil nil nil dmc)
                                (seed-apu-dmc-channel! dmc
                                                       :enabled-p t
                                                       :timer-period 1
                                                       :timer 0
                                                       :sample-buffer 1
                                                       :sample-buffer-empty-p nil
                                                       :bits-remaining 0
                                                       :silence-p t
                                                       :output 0)
                                (apu-tick! apu 1)
                                (expect (cl-nes::apu-dmc-output dmc) :to-be 2)
                                (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 7)
                                (seed-apu-dmc-channel! dmc
                                                       :timer 0
                                                       :shift-register 0
                                                       :bits-remaining 1
                                                       :silence-p nil)
                                (apu-tick! apu 1)
                                (expect (cl-nes::apu-dmc-output dmc) :to-be 0)
                                (seed-apu-dmc-channel! dmc :timer 2)
                                (apu-tick! apu 1)
                                (expect (cl-nes::apu-dmc-timer dmc) :to-be 1)
                                (let ((frame-cycle (cl-nes::apu-frame-cycle apu)))
                                  (apu-tick! apu -3)
                                  (expect (cl-nes::apu-frame-cycle apu) :to-be frame-cycle))))
          (it "requests a DMC byte at the bit boundary during disable delay"
              (let* ((requested-address nil)
                     (apu (make-apu
                           :memory-reader
                           (lambda (address)
                             (setf requested-address address)
                             #x5A)))
                     (dmc (cl-nes::apu-dmc apu)))
                (setf (cl-nes::apu-dmc-enabled-p dmc) nil
                      (cl-nes::apu-dmc-status-write-pending-p dmc) t
                      (cl-nes::apu-dmc-status-write-enabled-p dmc) nil
                      (cl-nes::apu-dmc-status-write-phase dmc) 0
                      (cl-nes::apu-dmc-status-write-origin-cycle dmc) 0
                      (cl-nes::apu-dmc-current-address dmc) #xC000
                      (cl-nes::apu-dmc-sample-buffer dmc) #xA5
                      (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
                      (cl-nes::apu-dmc-shift-register dmc) 0
                      (cl-nes::apu-dmc-bits-remaining dmc) 1
                      (cl-nes::apu-dmc-silence-p dmc) nil
                      (cl-nes::apu-dmc-timer-period dmc) 3
                      (cl-nes::apu-dmc-timer dmc) 1
                      (cl-nes::apu-dmc-bytes-remaining dmc) 2)
                (apu-tick! apu 1)
                (expect requested-address :to-be nil)
                (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 1)
                (apu-tick! apu 1)
                (expect requested-address :to-be #xC000)
                (expect (cl-nes::apu-dmc-status-write-pending-p dmc) :to-be t)
                (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 8)
                (expect (cl-nes::apu-dmc-shift-register dmc) :to-be #xA5)
                (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x5A)
                (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
                (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)))
          (it "restarts a terminal single-byte fetch for the implicit abort window"
              (let* ((apu (make-apu
                           :memory-reader
                           (lambda (address)
                             (declare (ignore address))
                             :pending)))
                     (dmc (cl-nes::apu-dmc apu)))
                (setf (cl-nes::apu-dmc-enabled-p dmc) t
                      (cl-nes::apu-dmc-loop-p dmc) nil
                      (cl-nes::apu-dmc-sample-length dmc) 1
                      (cl-nes::apu-dmc-sample-address dmc) #xC000
                      (cl-nes::apu-dmc-current-address dmc) #xC000
                      (cl-nes::apu-dmc-bytes-remaining dmc) 1
                      (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
                      (cl-nes::apu-dmc-bits-remaining dmc) 1
                      (cl-nes::apu-dmc-timer dmc) 1
                      (cl-nes::apu-cpu-cycle-index apu) 20)
                (cl-nes::%apu-dmc-fetch-complete! apu #xA5)
                (expect (cl-nes::apu-dmc-shift-register dmc) :to-be #xA5)
                (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
                (expect (cl-nes::apu-dmc-current-address dmc) :to-be #xC000)
                (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
                (expect (cl-nes::apu-dmc-status-write-pending-p dmc) :to-be t)
                (expect (cl-nes::apu-dmc-status-write-enabled-p dmc) :to-be nil)
                (expect (cl-nes::apu-dmc-status-write-phase dmc) :to-be 0)
                (expect (cl-nes::apu-dmc-status-write-origin-cycle dmc) :to-be 20)
                (expect (cl-nes::apu-dmc-enabled-p dmc) :to-be t)
                (apu-tick! apu 2)
                (expect (cl-nes::apu-dmc-status-write-pending-p dmc) :to-be t)
                (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
                (apu-tick! apu 1)
                (expect (cl-nes::apu-dmc-status-write-pending-p dmc) :to-be nil)
                (expect (cl-nes::apu-dmc-status-update-event dmc)
                        :to-be
                        :implicit-disabled)
                (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
                (expect (cl-nes::apu-dmc-enabled-p dmc) :to-be t))))
