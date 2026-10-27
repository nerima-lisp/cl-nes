(in-package #:cl-nes/test)
(describe "OAM DMA requests"
  (it "uses the last RMW write as one OAM DMA request"
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (ppu (nes-ppu nes)))
      (dotimes (offset 256)
        (setf (aref (cl-nes::bus-ram bus) (+ #x500 offset)) #x55
              (aref (cl-nes::bus-ram bus) (+ #x600 offset)) #x66))
      (setf (ppu-oam-address ppu) 0
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 0)
      (bus-write! bus #x4014 #x05)
      (bus-write! bus #x4014 #x06)
      (expect (cl-nes::bus-oam-dma-page bus) :to-be #x06)
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be t)
      (expect (cl-nes::bus-dma-stall-cycles bus) :to-be 513)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes)))
      (let ((stall-cycles (cl-nes::bus-take-dma-stall-cycles! bus)))
        (expect stall-cycles :to-be 513)
        (expect (cl-nes::%nes-run-dma-stalls! nes stall-cycles) :to-be 514))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)
      (expect (aref (ppu-oam ppu) 0) :to-be #x66)
      (expect (aref (ppu-oam ppu) #xFF) :to-be #x66))))
(describe "OAM DMA protocol"
  (it "retries a DMA halt across CPU writes and consumes alignment before its first get"
    (let ((bus (make-bus :cartridge (make-fixture-cartridge))))
      (setf (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x12
            (cl-nes::bus-oam-dma-index bus) 0
            (cl-nes::bus-oam-dma-stage bus) :halt
            (cl-nes::bus-oam-dma-alignment-p bus) t
            (cl-nes::bus-last-cpu-access-kind bus) :write
            (cl-nes::bus-last-cpu-access-address bus) 0
            (cl-nes::bus-cpu-cycle-phase bus) 0)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :halt)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 0)
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :alignment)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 0)))
  (it "records the CPU held address separately from the OAM source address"
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (event nil))
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x8123
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x45
            (cl-nes::bus-oam-dma-index bus) #x67)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (trace-event)
                (setf event trace-event))))
        (cl-nes::%dma-trace-cycle! bus 42 :test))
      (expect (getf event :cpu-held-address) :to-be #x8123)
      (expect (getf event :oam-source-address) :to-be #x4567)))
  (it "gates OAM DMA GETs by the held CPU address"
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (apu (cl-nes::bus-apu bus)))
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #xBD1A
            (cl-nes::bus-open-bus bus) #xA5
            (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x40
            (cl-nes::bus-oam-dma-index bus) #x15
            (cl-nes::bus-oam-dma-stage bus) :get
            (cl-nes::bus-cpu-cycle-phase bus) 0)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-data bus) :to-be #xA5)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t))
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (apu (cl-nes::bus-apu bus)))
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x4001
            (cl-nes::bus-open-bus bus) #x00
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x02
            (cl-nes::bus-oam-dma-index bus) #x15
            (cl-nes::bus-oam-dma-stage bus) :get
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (aref (cl-nes::bus-ram bus) #x0215) #xA5
            (cl-nes::apu-frame-irq-pending-p apu) t)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-data bus) :to-be #x40)
      (expect (cl-nes::apu-frame-irq-clear-pending-p apu) :to-be t)
      (expect (cl-nes::bus-open-bus bus) :to-be #xA5))
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (apu (cl-nes::bus-apu bus)))
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x4001
            (cl-nes::bus-open-bus bus) #xFF
            (cl-nes::bus-internal-data-bus bus) #x02
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x02
            (cl-nes::bus-oam-dma-index bus) #x15
            (cl-nes::bus-oam-dma-stage bus) :get
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (aref (cl-nes::bus-ram bus) #x0215) #xFF
            (cl-nes::apu-triangle-length-counter (cl-nes::apu-triangle apu)) 1)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-data bus) :to-be #x24)
      (expect (cl-nes::bus-open-bus bus) :to-be #xFF))
    (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
           (bus (nes-bus nes))
           (apu (cl-nes::bus-apu bus)))
      (setf (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x4001
            (cl-nes::bus-open-bus bus) #x50
            (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x50
            (cl-nes::bus-oam-dma-index bus) #x15
            (cl-nes::bus-oam-dma-stage bus) :get
            (cl-nes::bus-cpu-cycle-phase bus) 0)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-oam-dma-data bus) :to-be #x40)
      (expect (cl-nes::bus-open-bus bus) :to-be #x40)
      (expect (cl-nes::apu-frame-irq-clear-pending-p apu) :to-be t)))
  (it "keeps DMC mirrored reads within its conflict range"
    (let* ((cartridge
            (make-fixture-cartridge :program (list #x5A) :start #xC018))
           (bus (make-bus :cartridge cartridge))
           (dmc-conflict-address-p
            (lambda (address)
              (or (<= #x2000 address #x3FFF)
                  (and (<= #x4000 address #x4017) (/= address #x4014)))))
           (original-cartridge-cpu-read
            (symbol-function 'cl-nes::cartridge-cpu-read))
           (cartridge-read-count 0))
      (setf (cl-nes::bus-last-cpu-access-address bus) #x4000
            (cl-nes::bus-open-bus bus) #xA5)
      (unwind-protect
          (progn
            (setf (symbol-function 'cl-nes::cartridge-cpu-read) (lambda
                                                                    (read-cartridge
                                                                     address)
                                                                  (when
                                                                      (eq
                                                                       read-cartridge
                                                                       cartridge)
                                                                    (incf
                                                                     cartridge-read-count))
                                                                  (funcall
                                                                   original-cartridge-cpu-read
                                                                   read-cartridge
                                                                   address)))
            (multiple-value-bind (sample-value internal-value)
                (cl-nes::%bus-read-dma-source bus
                                              #xC018
                                              :internal-address-predicate
                                              dmc-conflict-address-p)
              (expect sample-value :to-be #x5A)
              (expect internal-value :to-be nil))
            (expect (cl-nes::%bus-read-dmc-sample bus #xC018) :to-be #x5A)
            (expect cartridge-read-count :to-be 2)
            (expect (cl-nes::bus-open-bus bus) :to-be #x5A))
        (setf (symbol-function 'cl-nes::cartridge-cpu-read) original-cartridge-cpu-read))))
  (it "executes OAM DMA from its source after an aligned CPU halt"
    (let* ((nes (make-nes
                 :cartridge
                 (make-fixture-cartridge
                  :program '(#x8D #x14 #x40 #x5A))))
           (bus (nes-bus nes))
           (cpu (nes-cpu nes))
           (ppu (nes-ppu nes))
           (held-address #x8003)
           (source-address #x0700)
           (event-order nil)
           (get-event nil)
           (get-data nil))
      (setf (cpu-pc cpu) #x8000
            (cpu-a cpu) #x07
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (aref (cl-nes::bus-ram bus) source-address) #xA5
            (ppu-oam-address ppu) 0)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (trace-event)
                (when (eq (getf trace-event :phase) :after-arbiter)
                  (cond
                    ((and (eq (getf trace-event :cpu-access-kind) :write)
                          (eq (getf trace-event :oam-stage) :halt))
                     (push :halt event-order))
                    ((eq (getf trace-event :oam-stage) :alignment)
                     (push :alignment event-order))
                    ((and (eq (getf trace-event :oam-stage) :put)
                          (= (getf trace-event :oam-index) 0))
                     (push :get event-order)
                     (setf get-event trace-event
                           get-data (cl-nes::bus-oam-dma-data bus))))))))
        (expect (cl-nes::nes-step/k nes (lambda (cycles) cycles))
                :to-be 518))
      (expect (reverse event-order) :to-equal '(:halt :alignment :get))
      (expect (getf get-event :oam-stage) :to-be :put)
      (expect (getf get-event :oam-index) :to-be 0)
      (expect (getf get-event :cpu-held-address) :to-be held-address)
      (expect (getf get-event :oam-source-address) :to-be source-address)
      (expect get-data :to-be #xA5)
      (expect (aref (ppu-oam ppu) 0) :to-be #xA5)
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256))))

(describe "Bus memory transitions"
  (it "captures status bit 7 at S+5 and bits 5-6 at S+12"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (ppu (nes-ppu nes))
           (start-clock (cl-nes::nes-master-clock nes))
           (capture-clock nil)
           (capture-status nil)
           (capture-write-toggle t))
      (setf (cl-nes::ppu-dot ppu) 10
            (ppu-status ppu) #x80
            (cl-nes::ppu-write-toggle ppu) t
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-access-pre-cycle-hook bus)
            (lambda ()
              (setf capture-clock (cl-nes::nes-master-clock nes)
                    capture-status (ppu-status ppu)
                    capture-write-toggle (cl-nes::ppu-write-toggle ppu)
                    (ppu-status ppu) #x40)))
      (expect (bus-read bus #x2002) :to-be #xC0)
      (expect capture-clock :to-be (+ start-clock 5))
      (expect capture-status :to-be 0)
      (expect capture-write-toggle :to-be nil)
      (expect (cl-nes::nes-master-clock nes) :to-be (+ start-clock 12))
      (expect (ppu-status ppu) :to-be #x40)
      (expect (cl-nes::ppu-dot ppu) :to-be 13)
      (expect (cl-nes::bus-cpu-access-count bus) :to-be 1)))
  (it "samples OAMDATA during sprite evaluation at the end of an active CPU access"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (ppu (nes-ppu nes)))
      (setf (cl-nes::ppu-scanline ppu) 128
            (cl-nes::ppu-dot ppu) 66
            (ppu-mask ppu) #x18
            (cl-nes::ppu-oam-address ppu) 4
            (aref (ppu-oam ppu) 4) #xFB
            (cl-nes::ppu-sprite-evaluation-n ppu) 1
            (cl-nes::ppu-sprite-evaluation-m ppu) 0
            (cl-nes::ppu-sprite-evaluation-latch ppu) #xFF
            (cl-nes::ppu-sprite-evaluation-done-p ppu) nil
            (cl-nes::ppu-secondary-oam-count ppu) 0
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (expect (bus-read bus #x2004) :to-be #xFB)
      (expect (cl-nes::ppu-dot ppu) :to-be 69)
      (expect (cl-nes::bus-cpu-access-count bus) :to-be 1)))

  (it "queues a DMC load request during an NES-owned open-bus read"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::bus-open-bus bus) #xA7
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x5000) :to-be #xA7)
      (expect (cl-nes::bus-dmc-read-replay-p bus) :to-be nil)
      (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :load)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :wait)
      (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 2)
      (expect (cl-nes::bus-dma-stall-cycles bus) :to-be 0)))
  (it "requests a DMC reload after the output unit consumes its prefetched byte"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (dmc (cl-nes::apu-dmc (nes-apu nes))))
      (setf (aref (cl-nes::bus-ram bus) #x20) #x5A
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) nil
            (cl-nes::apu-dmc-current-address dmc) #x0020
            (cl-nes::apu-dmc-sample-buffer dmc) #xA5
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-bits-remaining dmc) 0
            (cl-nes::apu-dmc-silence-p dmc) t
            (cl-nes::apu-dmc-output dmc) 0
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer-period dmc) 16
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x0000) :to-be 0)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be t)
      (expect (cl-nes::apu-dmc-shift-register dmc) :to-be #x52)
      (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 7)
      (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :reload)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready)
      (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 0)
      (expect (bus-read bus #x0001) :to-be 0)
      (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x5A)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
      (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x0021)
      (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
      (expect (cl-nes::apu-dmc-load-pending-p dmc) :to-be nil)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil)))
  (it "retries a DMC halt after a CPU write before the next read"
    (dolist (write-phase (list 0 1))
      (let* ((nes (make-nes))
             (bus (nes-bus nes))
             (apu (nes-apu nes))
             (dmc (cl-nes::apu-dmc apu))
             (pulse (cl-nes::apu-pulse-1 apu))
             (expected-stages
               (if (zerop write-phase)
                   (list :retry :active-halt :dummy :alignment :get)
                   (list :retry :active-halt :dummy :get)))
             (observed-stages nil))
        (setf (aref (cl-nes::bus-ram bus) #x20) #x5A
              (cl-nes::bus-cpu-access-active-p bus) t
              (cl-nes::bus-cpu-access-nes bus) nes)
        (bus-write! bus #x4015 #x01)
        (bus-write! bus #x4003 #x00)
        (bus-write! bus #x4017 #x80)
        (loop repeat (1- (cl-nes::apu-frame-reset-delay apu))
              do (bus-read bus #x0001))
        (expect (cl-nes::apu-frame-reset-delay apu) :to-be 1)
        (expect (cl-nes::apu-frame-reset-five-step-p apu) :to-be t)
        (expect (cl-nes::apu-pulse-enabled-p pulse) :to-be t)
        (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 10)
        (setf
              (cl-nes::bus-cpu-cycle-phase bus) write-phase
              (cl-nes::apu-cycle-parity apu) write-phase
              (cl-nes::bus-dmc-dma-stage bus) :ready
              (cl-nes::bus-dmc-dma-kind bus) :load
              (cl-nes::bus-dmc-dma-remaining bus) 0
              (cl-nes::apu-dmc-enabled-p dmc) t
              (cl-nes::apu-dmc-load-pending-p dmc) t
              (cl-nes::apu-dmc-current-address dmc) #x0020
              (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
              (cl-nes::apu-dmc-bytes-remaining dmc) 1
              (cl-nes::apu-dmc-timer dmc) 100)
        (let ((cl-nes::*dma-trace-hook*
                (lambda (event)
                  (let ((phase (getf event :phase))
                        (stage (getf event :dmc-stage)))
                    (cond
                      ((and (eq phase :after-arbiter)
                            (eq stage :retry))
                       (push :retry observed-stages))
                      ((and (eq phase :before-arbiter)
                            (member stage
                                    (list :active-halt :dummy :alignment :get)))
                       (push stage observed-stages)))))))
          (bus-write! bus #x4003 #x00)
          (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 9)
          (expect (cl-nes::apu-frame-reset-delay apu) :to-be 0)
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :retry)
          (expect (bus-read bus #x0001) :to-be 0))
        (expect (reverse observed-stages) :to-equal expected-stages)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
        (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :load)
        (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x5A)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x0021)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
        (setf (cl-nes::bus-cpu-access-active-p bus) nil))))

  (it "anchors delayed DMC load wait to the $4015 write cycle"
    (dolist (write-phase (list 0 1))
      (let* ((nes (make-nes :cartridge
                            (make-fixture-cartridge :program (list #x5A)
                                                    :start #xC000)))
             (bus (nes-bus nes))
             (apu (nes-apu nes))
             (dmc (cl-nes::apu-dmc apu))
             (request-event nil)
             (request-tick nil)
             (request-count 0)
             (request-origin-cycle nil)
             (request-cycle nil)
             (request-elapsed nil)
             (request-phase nil)
             (request-wait nil)
             (write-origin-cycle nil)
             (halt-cycle nil)
             (get-seen-p nil)
             (apu-ticks nil))
        (setf (cl-nes::bus-cpu-access-active-p bus) t
              (cl-nes::bus-cpu-access-nes bus) nes)
        (bus-write! bus #x4012 #x00)
        (bus-write! bus #x4013 #x00)
        (setf (cl-nes::bus-cpu-cycle-phase bus) write-phase
              (cl-nes::apu-cycle-parity apu) write-phase)
        (let ((cl-nes::*dma-trace-hook*
                (lambda (event)
                  (cond
                    ((eq (getf event :event) :dmc-request)
                     (incf request-count)
                     (setf request-event event
                           request-origin-cycle
                           (getf event :dmc-request-origin-cycle)
                           request-cycle
                           (getf event :dmc-request-cycle)
                           request-elapsed
                           (getf event :dmc-request-elapsed-cycles)
                           request-phase
                           (getf event :apu-parity)
                           request-wait
                           (getf event :dmc-request-wait)))
                    ((eq (getf event :event) :apu-tick)
                     (push event apu-ticks))
                    ((eq (getf event :phase) :before-arbiter)
                     (when (eq (getf event :dmc-stage) :active-halt)
                       (setf halt-cycle
                             (cl-nes::apu-cpu-cycle-index apu))))
                    ((eq (getf event :event) :dmc-get)
                     (setf get-seen-p t))))))
          (bus-write! bus #x4015 #x10)
          (setf write-origin-cycle
                (cl-nes::apu-dmc-status-write-origin-cycle dmc))
          (expect (cl-nes::apu-cpu-cycle-index apu)
                  :to-be write-origin-cycle)
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 1)
          (expect (bus-read bus #x0000) :to-be 0)
          (setf request-tick
                (find-if
                 (lambda (event)
                   (and request-event
                        (= (getf event :master-clock)
                           (getf request-event :master-clock))))
                 apu-ticks))
          (expect request-count :to-be 1)
          (expect request-tick :to-be-truthy)
          (expect (getf request-event :event) :to-be :dmc-request)
          (expect (getf request-event :cpu-access-kind) :to-be :read)
          (expect request-origin-cycle :to-be write-origin-cycle)
          (expect request-elapsed :to-be 1)
          (expect (= request-cycle (1+ request-origin-cycle)) :to-be t)
          (expect request-phase :to-be write-phase)
          (expect (getf request-tick :apu-parity) :to-be write-phase)
          (expect request-wait
                  :to-be (max 0 (- (if (= write-phase 1) 2 3) 2)))
          (expect halt-cycle :to-be nil)
          (expect get-seen-p :to-be nil)
          (if (= write-phase 0)
              (progn
                (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :wait)
                (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 0)
                (expect (bus-read bus #x0000) :to-be 0)
                (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready))
              (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready))
          (expect (cl-nes::bus-cpu-cycle-phase bus) :to-be 1)
          (expect (bus-read bus #x0000) :to-be 0)
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready)
          (expect halt-cycle :to-be nil)
          (expect (cl-nes::bus-cpu-cycle-phase bus) :to-be 0)
          (expect (bus-read bus #x0000) :to-be 0)
          (expect (not (null halt-cycle)) :to-be t)
          (expect get-seen-p :to-be t)
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x5A)
          (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
          (expect (cl-nes::apu-dmc-current-address dmc) :to-be #xC001)
          (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0))
        (setf (cl-nes::bus-cpu-access-active-p bus) nil))))
  (it "aligns an APU-origin DMC reload to its activation phase"
    (let* ((cartridge (make-fixture-cartridge :program (list #x5A)
                                             :start #xC000))
           (nes (make-nes :cartridge cartridge))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu))
           (events nil)
           (halt-remaining nil))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 1
            (cl-nes::apu-cycle-parity apu) 1
            (cl-nes::apu-dmc-current-address dmc) #xC000
            (cl-nes::apu-dmc-enabled-p dmc) nil
            (cl-nes::apu-dmc-sample-buffer dmc) #xA5
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-bits-remaining dmc) 0
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer-period dmc) 16
            (cl-nes::apu-dmc-timer dmc) 1)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (event)
                (push event events)
                (when (and (eq (getf event :phase) :before-arbiter)
                           (eq (getf event :dmc-stage) :active-halt))
                  (setf halt-remaining
                        (cl-nes::bus-dmc-dma-remaining bus)))))
            (cl-nes::*dma-trace-cycle-index* 0))
        (bus-write! bus #x4015 #x10)
        (expect (cl-nes::apu-dmc-status-write-phase dmc) :to-be 1)
        (expect (bus-read bus #x0000) :to-be 0)
        (let ((request-event
                (find :dmc-request events
                      :key (lambda (event) (getf event :event)))))
          (expect (getf request-event :dmc-request-kind) :to-be :reload)
          (expect (getf request-event :dmc-request-elapsed-cycles) :to-be 1)
          (expect (getf request-event :dmc-request-wait) :to-be 1)
          (expect (getf request-event :cpu-parity) :to-be 0)
          (expect (getf request-event :apu-parity) :to-be 1))
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :wait)
        (bus-read bus #x0000)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready)
        (bus-read bus #x0000)
        (let* ((halt-event
                 (find-if
                  (lambda (event)
                    (and (eq (getf event :phase) :before-arbiter)
                         (eq (getf event :dmc-stage) :active-halt)))
                  events))
               (get-event
                 (find :dmc-get events
                       :key (lambda (event) (getf event :event))))
               (dmc-stages
                 (mapcar
                  (lambda (event) (getf event :dmc-stage))
                  (reverse
                   (remove-if-not
                    (lambda (event)
                      (and (eq (getf event :phase) :before-arbiter)
                           (or (eq (getf event :dmc-stage) :active-halt)
                               (eq (getf event :dmc-stage) :dummy)
                               (eq (getf event :dmc-stage) :get))))
                    events)))))
          (expect halt-event :to-be-truthy)
          (expect (getf halt-event :cpu-parity) :to-be 0)
          (expect (getf halt-event :apu-parity) :to-be 1)
          (expect halt-remaining :to-be 3)
          (expect (getf get-event :master-clock)
                  :to-be (+ (getf halt-event :master-clock) 24))
          (expect dmc-stages :to-equal (list :active-halt :dummy :get))
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #x5A)
          (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
          (expect (cl-nes::apu-dmc-current-address dmc) :to-be #xC001)
          (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0))
        (setf (cl-nes::bus-cpu-access-active-p bus) nil))))
  (it "uses open bus data when an OAM DMA source is unmapped"
    (let ((bus (make-bus)))
      (setf (cl-nes::bus-open-bus bus) #x5A
            (cl-nes::bus-oam-dma-active-p bus) t
            (cl-nes::bus-oam-dma-page bus) #x50
            (cl-nes::bus-oam-dma-index bus) 0
            (cl-nes::bus-oam-dma-stage bus) :get)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-open-bus bus) :to-be #x5A)
      (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 0) :to-be #x5A)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 1)))

  (it "uses cycle phase when repeated controller strobe writes are high"
    (let ((bus (make-bus))
          (controller (make-controller)))
      (setf (cl-nes::bus-controller-1 bus) controller
            (cl-nes::bus-last-cpu-access-address bus) #x4016
            (cl-nes::bus-cpu-cycle-phase bus) 1)
      (expect (bus-write! bus #x4016 1) :to-be 1)
      (expect (cl-nes::controller-strobe controller) :to-be nil)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 0)
      (expect (bus-write! bus #x4016 1) :to-be 1)
      (expect (cl-nes::controller-strobe controller) :to-be t)))

  (it "mirrors internal RAM and retains the open-bus value"
    (let ((bus (make-bus :cartridge (make-fixture-cartridge))))
      (bus-write! bus #x0000 #xA5)
      (expect (bus-read bus #x0800) :to-be #xA5)
      (bus-write! bus #x4018 #x5A)
      (expect (bus-read bus #x4018) :to-be #x5A)))

  (it "transfers a page through OAM DMA and consumes its stall once"
    (let ((bus (make-bus :cartridge (make-fixture-cartridge))))
      (dotimes (offset 256)
        (bus-write! bus offset offset))
      (bus-write! bus #x2003 0)
      (bus-write! bus #x4014 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) 0) :to-be 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #xFF) :to-be #xFF)
      (expect (ppu-oam-address (cl-nes::bus-ppu bus)) :to-be 0)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 513)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 0)
      (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
      (bus-write! bus #x4014 0)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 514)))

  (it "charges a DMC fetch as a CPU DMA stall"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 4)
      (setf (cl-nes::bus-last-cpu-access-kind bus) :write
            (cl-nes::bus-cpu-cycle-phase bus) 1)
      (funcall (cl-nes::apu-memory-reader apu) #x8000)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 3)))
  (it "lets DMC register conflicts clock both controllers"
    (let* ((controller-1 (make-controller))
           (controller-2 (make-controller))
           (cartridge (make-fixture-cartridge
                       :program (list #x00 #x00)
                       :start #xC016))
           (apu (make-apu))
           (bus (make-bus :cartridge cartridge
                          :controller-1 controller-1
                          :controller-2 controller-2
                          :apu apu))
           (dmc (cl-nes::apu-dmc apu)))
      (dolist (controller (list controller-1 controller-2))
        (controller-set-buttons! controller 1)
        (controller-write! controller 1)
        (controller-write! controller 0))
      (setf
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-current-address dmc) #xC016
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 2
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) #x4000
            (cl-nes::bus-dmc-dma-stage bus) :get
            (cl-nes::bus-dmc-dma-remaining bus) 4
            (cl-nes::apu-cycle-parity apu) 1)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-open-bus bus) :to-be 1)
      (expect (cl-nes::controller-read-count controller-1) :to-be 1)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be 0)
      (setf (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::bus-dmc-dma-stage bus) :get
            (cl-nes::bus-dmc-dma-remaining bus) 4)
      (cl-nes::%dma-arbitrate-cycle! bus)
      (expect (cl-nes::bus-open-bus bus) :to-be 1)
      (expect (cl-nes::controller-read-count controller-2) :to-be 1)
      (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be 0)))

  ;; DMC dummy reads must not re-enter the active CPU operation and recursively
  ;; clock the APU while the fetch is already in progress.
  (it "keeps DMC dummy reads outside an active CPU access"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::bus-cpu-access-active-p bus) t)
      (cl-nes::%apu-dmc-fetch! apu)
      (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
      (expect (cl-nes::bus-take-dma-stall-cycles! bus) :to-be 4)))

  (it "replays a CPU PPU read after DMC dummy reads"
    (let* ((nes (make-nes))
           (bus (cl-nes::nes-bus nes))
           (ppu (cl-nes::nes-ppu nes))
           (dmc (cl-nes::apu-dmc (cl-nes::nes-apu nes))))
      (setf (aref (cl-nes::ppu-nametable ppu) 0) #x22
            (aref (cl-nes::ppu-nametable ppu) 1) #x33
            (aref (cl-nes::ppu-nametable ppu) 2) #x44
            (cl-nes::ppu-vram-address ppu) #x2000
            (cl-nes::ppu-read-buffer ppu) #x11
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-dmc-dma-stage bus) :ready
            (cl-nes::bus-dmc-dma-kind bus) :load
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (expect (bus-read bus #x2007) :to-be #x33)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be #x44)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x2003)
      (expect (cl-nes::bus-cpu-access-count bus) :to-be 4)
      (expect (cl-nes::bus-dmc-read-replay-p bus) :to-be nil)))

  (it "advances OAM DMA as get/put cycles"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (bus (cl-nes::nes-bus nes)))
      (dotimes (offset 256)
        (setf (aref (cl-nes::bus-ram bus) (+ #x700 offset)) offset))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (bus-write! bus #x4014 7)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes)))
      (cl-nes::%nes-run-dma-stalls! nes
                                    (cl-nes::bus-take-dma-stall-cycles! bus))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #x00) :to-be 0)
      (expect (aref (ppu-oam (cl-nes::bus-ppu bus)) #xFF) :to-be #xFF)))

  (it "lets DMC phases preempt OAM gets while OAM puts continue"
    (let* ((cartridge (make-fixture-cartridge))
           (nes (make-nes :cartridge cartridge))
           (bus (cl-nes::nes-bus nes))
           (dmc (cl-nes::apu-dmc (cl-nes::nes-apu nes)))
           (clock-count 0))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes)
      (bus-write! bus #x4014 7)
      (setf (cl-nes::bus-cpu-access-active-p bus) nil
            (cl-nes::bus-last-cpu-access-kind bus) :read
            (cl-nes::bus-last-cpu-access-address bus) (cpu-pc (nes-cpu nes))
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0)
      (cl-nes::%nes-run-dma-stalls! nes
                                    (cl-nes::bus-take-dma-stall-cycles! bus)
                                    (lambda ()
                                      (incf clock-count)))
      (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
      (expect (cl-nes::bus-dmc-dma-remaining bus) :to-be 0)
      (expect clock-count :to-be 516))))

  (it "charges DMC and OAM DMA competition at the CPU instruction boundary"
    (let* ((cartridge (make-fixture-cartridge
                       :program (list #xA9 #x07 #x8D #x14 #x40)))
           (nes (make-nes :cartridge cartridge))
           (bus (nes-bus nes))
           (apu (nes-apu nes))
           (dmc (cl-nes::apu-dmc apu)))
      (dotimes (offset 256)
        (setf (aref (cl-nes::bus-ram bus) offset) offset))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) nil
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-sample-buffer dmc) #xA5
            (cl-nes::apu-dmc-bits-remaining dmc) 0
            (cl-nes::apu-dmc-bytes-remaining dmc) 1
            (cl-nes::apu-dmc-timer dmc) 5)
      ;; The nonempty buffer prevents a request during LDA. Its sixth APU
      ;; clock empties it on STA write, after OAM DMA has started.
      (let ((instruction-cycles (nes-step/k nes (function identity))))
        (expect instruction-cycles :to-be 2)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-timer dmc) :to-be 3)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle))
      (let* ((sta-cycles 4)
             (oam-halt-cycles 1)
             (oam-get-put-cycles (* 256 2))
             ;; DMC reload halt is on put. Its dummy overlaps OAM get,
             ;; alignment overlaps OAM put, then DMC get takes the next OAM
             ;; get. The odd-phase get retry is the second delayed cycle.
             (dmc-oam-delay-cycles 2)
             (oam-write-phase (logxor (cl-nes::bus-cpu-cycle-phase bus) 1))
             (oam-alignment-cycles (if (= oam-write-phase 1) 1 0))
             (expected-cycles (+ sta-cycles
                                 oam-halt-cycles
                                 oam-get-put-cycles
                                 oam-alignment-cycles
                                 dmc-oam-delay-cycles))
             (cycles (nes-step/k nes (function identity))))
        (expect cycles :to-be expected-cycles)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8005)
        (expect (cl-nes::bus-oam-dma-active-p bus) :to-be nil)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be 256)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
        (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :reload)
        (expect (cl-nes::bus-dmc-dma-remaining bus) :to-be 0))))
  (it "arbitrates DMC halts and no-op reads against OAM DMA"
  (let* ((load-bus (make-bus))
         (load-ppu (cl-nes::bus-ppu load-bus))
         (reload-bus (make-bus))
         (bus (make-bus))
         (ppu (cl-nes::bus-ppu bus)))
    (setf (cl-nes::bus-oam-dma-active-p load-bus) t
          (cl-nes::bus-oam-dma-stage load-bus) :put
          (cl-nes::bus-oam-dma-data load-bus) #x5A
          (cl-nes::bus-cpu-cycle-phase load-bus) 1
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu load-bus)) 0
          (cl-nes::bus-last-cpu-access-kind load-bus) :read
          (cl-nes::bus-dmc-dma-stage load-bus) :ready
          (cl-nes::bus-dmc-dma-kind load-bus) :load)
    (cl-nes::%dma-arbitrate-cycle! load-bus)
    (expect (cl-nes::bus-dmc-dma-stage load-bus) :to-be :ready)
    (expect (cl-nes::bus-oam-dma-index load-bus) :to-be 1)
    (expect (aref (ppu-oam load-ppu) 0) :to-be #x5A)
    (setf (cl-nes::bus-cpu-cycle-phase load-bus) 0
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu load-bus)) 1
          (cl-nes::bus-oam-dma-stage load-bus) :get)
    (cl-nes::%dma-arbitrate-cycle! load-bus)
    (expect (cl-nes::bus-dmc-dma-stage load-bus) :to-be :dummy)
    (expect (cl-nes::bus-dmc-dma-remaining load-bus) :to-be 2)
    (expect (cl-nes::bus-oam-dma-stage load-bus) :to-be :put)

    (setf (cl-nes::bus-oam-dma-active-p reload-bus) t
          (cl-nes::bus-oam-dma-stage reload-bus) :get
          (cl-nes::bus-cpu-cycle-phase reload-bus) 0
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu reload-bus)) 1
          (cl-nes::bus-last-cpu-access-kind reload-bus) :read
          (cl-nes::bus-dmc-dma-stage reload-bus) :ready
          (cl-nes::bus-dmc-dma-kind reload-bus) :reload)
    (cl-nes::%dma-arbitrate-cycle! reload-bus)
    (expect (cl-nes::bus-dmc-dma-stage reload-bus) :to-be :ready)
    (expect (cl-nes::bus-oam-dma-stage reload-bus) :to-be :put)
    (setf (cl-nes::bus-cpu-cycle-phase reload-bus) 1
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu reload-bus)) 0)
    (cl-nes::%dma-arbitrate-cycle! reload-bus)
    (expect (cl-nes::bus-dmc-dma-stage reload-bus) :to-be :dummy)
    (expect (cl-nes::bus-dmc-dma-remaining reload-bus) :to-be 3)
    (expect (cl-nes::bus-oam-dma-index reload-bus) :to-be 1)

    (setf (aref (cl-nes::ppu-nametable ppu) 0) #x22
          (aref (cl-nes::ppu-nametable ppu) 1) #x33
          (cl-nes::ppu-vram-address ppu) #x2000
          (cl-nes::ppu-read-buffer ppu) #x11
          (cl-nes::bus-oam-dma-active-p bus) t
          (cl-nes::bus-oam-dma-page bus) #x20
          (cl-nes::bus-oam-dma-index bus) 7
          (cl-nes::bus-oam-dma-stage bus) :get
          (cl-nes::bus-dmc-dma-stage bus) :dummy
          (cl-nes::bus-dmc-dma-remaining bus) 3
          (cl-nes::bus-last-cpu-access-kind bus) :read
          (cl-nes::bus-last-cpu-access-address bus) #x2007
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 1)
    (cl-nes::%dma-arbitrate-cycle! bus)
    (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :alignment)
    (expect (cl-nes::bus-oam-dma-data bus) :to-be #x11)
    (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
    (setf (cl-nes::bus-cpu-cycle-phase bus) 1
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 0)
    (cl-nes::%dma-arbitrate-cycle! bus)
    (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :get)
    (expect (cl-nes::bus-oam-dma-index bus) :to-be 8)
    (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
    (setf (cl-nes::bus-cpu-cycle-phase bus) 0
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 1)
    (cl-nes::%dma-arbitrate-cycle! bus)
    (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
    (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
    (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
    (expect (cl-nes::ppu-vram-address ppu) :to-be #x2001)
    (setf (cl-nes::bus-cpu-cycle-phase bus) 1
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 0)
    (cl-nes::%dma-arbitrate-cycle! bus)
    (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
    (expect (cl-nes::bus-oam-dma-index bus) :to-be 8)
    (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
    (expect (cl-nes::ppu-vram-address ppu) :to-be #x2002)
    (setf (cl-nes::bus-cpu-cycle-phase bus) 0
          (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 1)
    (cl-nes::%dma-arbitrate-cycle! bus)
    (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)))
  (describe "DMA state transitions"
    (it "counts down a DMC request through positive and zero waits before it becomes ready"
      (let ((bus (make-bus)))
        (setf (cl-nes::bus-dmc-dma-stage bus) :new
              (cl-nes::bus-dmc-dma-wait bus) 2)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :wait)
        (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 1)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready)
        (expect (cl-nes::bus-dmc-dma-wait bus) :to-be 0)
        (let ((zero-wait-bus (make-bus)))
          (setf (cl-nes::bus-dmc-dma-stage zero-wait-bus) :new
                (cl-nes::bus-dmc-dma-wait zero-wait-bus) 1)
          (cl-nes::%dma-arbitrate-cycle! zero-wait-bus)
          (expect (cl-nes::bus-dmc-dma-stage zero-wait-bus) :to-be :wait)
          (expect (cl-nes::bus-dmc-dma-wait zero-wait-bus) :to-be 0)
          (cl-nes::%dma-arbitrate-cycle! zero-wait-bus)
          (expect (cl-nes::bus-dmc-dma-stage zero-wait-bus) :to-be :ready)
          (expect (cl-nes::bus-dmc-dma-wait zero-wait-bus) :to-be 0))))

    (it "preempts an OAM put on phase zero and transfers it on phase one"
      (let* ((bus (make-bus))
             (ppu (cl-nes::bus-ppu bus)))
        (setf (cl-nes::bus-oam-dma-active-p bus) t
              (cl-nes::bus-oam-dma-stage bus) :put
              (cl-nes::bus-oam-dma-data bus) #x5A
              (cl-nes::bus-oam-dma-index bus) 0
              (cl-nes::bus-cpu-cycle-phase bus) 0
              (cl-nes::bus-last-cpu-access-kind bus) :read
              (aref (ppu-oam ppu) 0) #xA5)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be 0)
        (expect (aref (ppu-oam ppu) 0) :to-be #xA5)
        (setf (cl-nes::bus-cpu-cycle-phase bus) 1)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be nil)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be 1)
        (expect (aref (ppu-oam ppu) 0) :to-be #x5A)))
    (it "holds a DMC alignment cycle until phase one"
      (let ((bus (make-bus)))
        (setf
              (cl-nes::bus-dmc-dma-stage bus) :alignment
              (cl-nes::bus-dmc-dma-kind bus) :load
              (cl-nes::bus-cpu-cycle-phase bus) 0
              (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 1)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :alignment)
        (setf
              (cl-nes::bus-cpu-cycle-phase bus) 1
              (cl-nes::apu-cycle-parity (cl-nes::bus-apu bus)) 0)
        (cl-nes::%dma-arbitrate-cycle! bus)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :get)))

    (it "runs reload DMA before the CPU reads PPU status"
      (let* ((nes (make-nes :cartridge (make-fixture-cartridge)))
             (bus (nes-bus nes))
             (ppu (nes-ppu nes))
             (dmc (cl-nes::apu-dmc (nes-apu nes))))
        (setf (cl-nes::ppu-dot ppu) 10
              (ppu-status ppu) #x80
              (cl-nes::bus-cpu-cycle-phase bus) 1
              (cl-nes::bus-cpu-access-active-p bus) t
              (cl-nes::bus-cpu-access-nes bus) nes
              (cl-nes::bus-dmc-dma-stage bus) :ready
              (cl-nes::bus-dmc-dma-kind bus) :reload
              (cl-nes::apu-dmc-enabled-p dmc) t
              (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
              (cl-nes::apu-dmc-bytes-remaining dmc) 1
              (cl-nes::apu-dmc-timer dmc) 0)
        (let ((value (bus-read bus #x2002)))
          (expect (logbitp 7 value) :to-be nil))
        (expect (logbitp 7 (ppu-status ppu)) :to-be nil)
        (expect (cl-nes::bus-cpu-access-count bus) :to-be 5)
        (expect (cl-nes::ppu-dot ppu) :to-be 25)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)))

    (it "performs the implied instruction read at the next program counter"
      (let* ((nes (make-nes
                   :cartridge (make-fixture-cartridge :program (list #xEA))))
             (bus (nes-bus nes))
             (dummy-read-observed nil))
        (nes-step/k
         nes
         #'identity
         :cycle-hook
         (lambda ()
           (when (and (= (cl-nes::bus-cpu-access-count bus) 2)
                      (= (cl-nes::bus-last-cpu-access-address bus) #x8001))
             (setf dummy-read-observed t))))
        (expect dummy-read-observed :to-be t)
        (expect (cpu-pc (nes-cpu nes)) :to-be #x8001)))

    (it "stores raw SHX data when DMC cycles overlap its dummy read"
      (let* ((nes (make-nes
                   :cartridge (make-fixture-cartridge
                               :program (list #x9E #x10 #x1D))))
             (bus (nes-bus nes))
             (cpu (nes-cpu nes))
             (dmc (cl-nes::apu-dmc (nes-apu nes))))
        (setf (cpu-x cpu) #xF0
              (cpu-y cpu) #xF0
              (cl-nes::bus-cpu-cycle-phase bus) 1
              (cl-nes::bus-dmc-dma-stage bus) :new
              (cl-nes::bus-dmc-dma-kind bus) :load
              (cl-nes::bus-dmc-dma-wait bus) 2
              (cl-nes::apu-dmc-enabled-p dmc) t
              (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
              (cl-nes::apu-dmc-bytes-remaining dmc) 1
              (cl-nes::apu-dmc-timer dmc) 0)
        (nes-step/k nes #'identity)
        (expect (aref (cl-nes::bus-ram bus) 0) :to-be #xF0)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
        (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be nil)
        (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0))))
(describe "DMC explicit disable abort window"
  (it "cancels a real queued DMC retry before halt on delayed status disable"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (dmc (cl-nes::apu-dmc (nes-apu nes)))
           (events nil))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (cl-nes::apu-cycle-parity (nes-apu nes)) 0
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) t
            (cl-nes::apu-dmc-current-address dmc) #x0020
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (event)
                (push event events)))
            (cl-nes::*dma-trace-cycle-index* 0))
        (dotimes (i 3)
          (declare (ignore i))
          (bus-write! bus #x0000 #xA5))
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :retry)
        (bus-write! bus #x4015 #x00)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :retry)
        (progn
          (bus-write! bus #x0001 #x5A)
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (bus-read bus #x0000))
        (let* ((disable-event
                 (find :dmc-explicit-disable events
                       :key (lambda (event) (getf event :event))))
               (stop-event
                 (find :dmc-stop events
                       :key (lambda (event) (getf event :event))))
               (tick-events
                 (nreverse
                  (remove-if-not
                   (lambda (event)
                     (eq (getf event :event) :apu-tick))
                   events)))
               (write-cycle
                 (find-if
                  (lambda (event)
                    (and (eq (getf event :phase) :before-arbiter)
                         (= (getf event :master-clock) 48)))
                  events)))
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
          (expect (cl-nes::bus-cpu-access-count bus) :to-be 6)
          (expect (count :dmc-request events
                         :key (lambda (event) (getf event :event)))
                  :to-be 1)
          (expect (getf disable-event :dmc-stage-before) :to-be :retry)
          (progn
            (expect (getf disable-event :dmc-disable-reason)
                    :to-be :cancelled-before-halt)
            (expect (getf disable-event :cpu-access-kind) :to-be :write)
            (expect (getf disable-event :cpu-held-address) :to-be #x0001)
            (expect (getf disable-event :cpu-write-data) :to-be #x5A))
          (expect (getf stop-event :dmc-stop-reason)
                  :to-be :cancelled-before-halt)
          (expect (getf write-cycle :cpu-access-kind) :to-be :write)
          (expect (getf write-cycle :cpu-held-address) :to-be #x4015)
          (expect (getf write-cycle :cpu-write-data) :to-be #x00)
          (expect (mapcar (lambda (event) (getf event :master-clock))
                          tick-events)
                  :to-equal (list 12 24 36 48 60 72))
          (expect (mapcar (lambda (event) (getf event :apu-parity))
                          tick-events)
                  :to-equal (list 1 0 1 0 1 0))
          (expect (find :dmc-get events
                        :key (lambda (event) (getf event :event)))
                  :to-be nil)
          (setf (cl-nes::bus-cpu-access-active-p bus) nil)))))
  (it "consumes one abort cycle after the halt without a sample GET"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (dmc (cl-nes::apu-dmc (nes-apu nes)))
           (events nil))
      (setf (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (cl-nes::bus-dmc-dma-stage bus) :retry
            (cl-nes::bus-dmc-dma-kind bus) :load
            (cl-nes::bus-dmc-dma-wait bus) 0
            (cl-nes::bus-dmc-dma-remaining bus) 0
            (cl-nes::apu-cycle-parity (nes-apu nes)) 0
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) t
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (event)
                (push event events)))
            (cl-nes::*dma-trace-cycle-index* 0))
        (bus-write! bus #x4015 #x00)
        (bus-read bus #x0000)
        (let* ((disable-event
                 (find :dmc-explicit-disable events
                       :key (lambda (event) (getf event :event))))
               (stop-event
                 (find :dmc-stop events
                       :key (lambda (event) (getf event :event))))
               (tick-events
                 (nreverse
                  (remove-if-not
                   (lambda (event)
                     (eq (getf event :event) :apu-tick))
                   events))))
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (cl-nes::bus-cpu-access-count bus) :to-be 4)
          (expect (getf disable-event :dmc-stage-before) :to-be :active-halt)
          (expect (getf disable-event :dmc-disable-reason) :to-be :abort-window)
          (expect (getf stop-event :dmc-stop-reason)
                  :to-be :abort-cycle-consumed)
          (expect (find :dmc-get events
                        :key (lambda (event) (getf event :event)))
                  :to-be nil)))))
  (it "completes an alignment that has passed the abort window"
    (let* ((nes (make-nes))
           (bus (nes-bus nes))
           (dmc (cl-nes::apu-dmc (nes-apu nes)))
           (events nil))
      (setf (aref (cl-nes::bus-ram bus) #x0020) #x5A
            (cl-nes::bus-cpu-access-active-p bus) t
            (cl-nes::bus-cpu-access-nes bus) nes
            (cl-nes::bus-cpu-cycle-phase bus) 0
            (cl-nes::bus-dmc-dma-stage bus) :alignment
            (cl-nes::bus-dmc-dma-kind bus) :load
            (cl-nes::bus-dmc-dma-remaining bus) 1
            (cl-nes::apu-cycle-parity (nes-apu nes)) 0
            (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-load-pending-p dmc) t
            (cl-nes::apu-dmc-current-address dmc) #x0020
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
            (cl-nes::apu-dmc-bytes-remaining dmc) 1)
      (let ((cl-nes::*dma-trace-hook*
              (lambda (event)
                (push event events)))
            (cl-nes::*dma-trace-cycle-index* 0))
        (bus-write! bus #x4015 #x00)
        (bus-read bus #x0000)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :get)
        (bus-read bus #x0000)
        (let* ((disable-event
                 (find :dmc-explicit-disable events
                       :key (lambda (event) (getf event :event))))
               (get-event
                 (find :dmc-get events
                       :key (lambda (event) (getf event :event))))
               (stop-event
                 (find :dmc-stop events
                       :key (lambda (event) (getf event :event))))
               (tick-events
                 (nreverse
                  (remove-if-not
                   (lambda (event)
                     (eq (getf event :event) :apu-tick))
                   events))))
          (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
          (expect (getf disable-event :dmc-stage-before) :to-be :alignment)
          (expect (getf disable-event :dmc-disable-reason)
                  :to-be :after-abort-window)
          (expect (getf get-event :dmc-get-address) :to-be #x0020)
          (expect (getf get-event :dmc-get-value) :to-be #x5A)
          (expect (cl-nes::apu-dmc-sample-buffer-empty-p dmc) :to-be t)
          (expect (cl-nes::apu-dmc-current-address dmc) :to-be #x0020)
          (expect (cl-nes::apu-dmc-bytes-remaining dmc) :to-be 0)
          (expect (mapcar (lambda (event) (getf event :master-clock))
                          tick-events)
                  :to-equal (list 12 24 36)))))))
(describe "DMC/OAM bus arbitration"
  (it "preempts and realigns OAM while holding the CPU address through a bus conflict"
    (let* ((controller (make-controller))
           (cartridge (make-fixture-cartridge
                       :program (append (make-list #x16 :initial-element 0)
                                        (list #xFF))
                       :start #xC000))
           (nes (make-nes :cartridge cartridge
                          :controller-1 controller))
           (bus (nes-bus nes))
           (dmc (cl-nes::apu-dmc (nes-apu nes)))
           (get-event nil)
           (oam-latch nil))
      (controller-set-buttons! controller 1)
      (controller-write! controller 1)
      (controller-write! controller 0)
      (setf (cl-nes::bus-cpu-access-active-p bus) t
      (cl-nes::bus-cpu-access-nes bus) nes
      (cl-nes::bus-cpu-cycle-phase bus) 0
      (cl-nes::apu-cycle-parity (nes-apu nes)) 1
      (cl-nes::bus-dmc-dma-apu-phase-offset bus) 0
      (cl-nes::bus-open-bus bus) 0
      (cl-nes::bus-oam-dma-active-p bus) t
      (cl-nes::bus-oam-dma-page bus) #x40
      (cl-nes::bus-oam-dma-index bus) #x14
      (cl-nes::bus-oam-dma-stage bus) :get
      (cl-nes::bus-oam-dma-data bus) #x5A
      (cl-nes::apu-dmc-enabled-p dmc) t
      (cl-nes::apu-dmc-current-address dmc) #xC016
      (cl-nes::apu-dmc-sample-buffer-empty-p dmc) t
      (cl-nes::apu-dmc-bytes-remaining dmc) 1
      (cl-nes::apu-dmc-load-pending-p dmc) nil
      (cl-nes::apu-dmc-timer dmc) 0)
      (let ((cl-nes::*dma-trace-cycle-index* 0)
  (cl-nes::*dma-trace-hook*
   (lambda (event)
     (when (eq (getf event :event) :dmc-get)
       (setf get-event event)))))
        (bus-read bus #x4000)
        (expect (cl-nes::bus-dmc-dma-kind bus) :to-be :reload)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :ready)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x14)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)

        (bus-read bus #x4000)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :dummy)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x15)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)

        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :alignment)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x15)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)

        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x16)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)
        (setf oam-latch (cl-nes::bus-oam-dma-data bus))

        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (getf get-event :dmc-get-address) :to-be #xC016)
        (expect (getf get-event :dmc-get-value) :to-be #xE1)
        (expect (getf get-event :cpu-held-address) :to-be #x4000)
        (expect (cl-nes::bus-dmc-dma-stage bus) :to-be :idle)
        (expect (cl-nes::apu-dmc-sample-buffer dmc) :to-be #xE1)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x16)
        (expect (cl-nes::bus-oam-dma-data bus) :to-be oam-latch)
        (expect (cl-nes::bus-dma-cycle-preempted-p bus) :to-be t)
        (expect (cl-nes::controller-read-count controller) :to-be 1)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)

        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :get)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x16)
        (expect (cl-nes::bus-oam-dma-data bus) :to-be oam-latch)
        (expect (cl-nes::controller-read-count controller) :to-be 1)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)

        (cl-nes::%nes-clock-cpu-cycle! nes bus nil nil)
        (expect (cl-nes::bus-oam-dma-stage bus) :to-be :put)
        (expect (cl-nes::bus-oam-dma-index bus) :to-be #x16)
        (expect (cl-nes::bus-oam-dma-data bus) :to-be #xE0)
        (expect (cl-nes::controller-read-count controller) :to-be 2)
        (expect (cl-nes::bus-last-cpu-access-address bus) :to-be #x4000)))))
