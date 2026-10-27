(in-package #:cl-nes)
(defvar *nes-step-dma-cycles* nil)
(defvar *dma-trace-cycle-index* 0)

(defun make-bus (&key cartridge ppu controller-1 controller-2 apu)
  (let* ((ppu (or ppu (make-ppu cartridge)))
         (controller-1 (or controller-1 (make-controller)))
         (controller-2 (or controller-2 (make-controller)))
         (apu (or apu (make-apu)))
         (bus nil))
    (ppu-load-cartridge! ppu cartridge)
    (setf bus (%make-bus :cartridge cartridge :ppu ppu
                         :controller-1 controller-1 :controller-2 controller-2
                         :apu apu))
    (apu-set-memory-reader!
     apu
     (lambda (address)
       (let* ((nes-owned-p (and (bus-cpu-access-active-p bus)
                                (bus-cpu-access-nes bus)))
              (dma-owned-p (or (bus-oam-dma-active-p bus)
                               (not (eq (bus-dmc-dma-stage bus) :idle)))))
         (with-bus-cpu-access-hook (bus nil)
           (if (or (apu-dmc-status-write-pending-p (apu-dmc apu))
                 nes-owned-p
                 dma-owned-p)
               (progn
                 (when (and (not (apu-dmc-status-write-pending-p (apu-dmc apu)))
                            (eq (bus-dmc-dma-stage bus) :idle))
                   (setf (bus-dmc-dma-kind bus)
                         (if (apu-dmc-load-pending-p (apu-dmc apu))
                             :load
                             :reload)
                         (bus-dmc-dma-wait bus)
                         (case (bus-dmc-dma-kind bus)
                           (:load
                            (let* ((dmc (apu-dmc apu))
                                   (event (apu-dmc-status-update-event dmc)))
                              (if (eq event :enabled)
                                  (let ((elapsed
                                          (- (apu-cpu-cycle-index apu)
                                             (apu-dmc-status-write-origin-cycle dmc))))
                                    (max 0
                                         (- (if (= (mod (apu-dmc-status-write-phase dmc) 2)
                                                   1)
                                                2
                                                3)
                                            elapsed 1)))
                                  (if (= (bus-cpu-cycle-phase bus) 1) 2 3))))
                           (:reload
                            (if (= (bus-cpu-cycle-phase bus) 0) 0 1)))
                         (bus-dmc-dma-stage bus) :new)
                   (%dma-trace-event! bus :dmc-request
                                      (* 12 (1+ *dma-trace-cycle-index*))
                                      :dmc-request-reason :memory-reader-request
                                      :dmc-request-origin-cycle
                                      (when (eq (apu-dmc-status-update-event
                                                 (apu-dmc apu))
                                                :enabled)
                                        (apu-dmc-status-write-origin-cycle
                                         (apu-dmc apu)))
                                      :dmc-request-cycle
                                      (apu-cpu-cycle-index apu)
                                      :dmc-request-elapsed-cycles
                                      (when (eq (apu-dmc-status-update-event
                                                 (apu-dmc apu))
                                                :enabled)
                                        (- (apu-cpu-cycle-index apu)
                                           (apu-dmc-status-write-origin-cycle
                                            (apu-dmc apu))))
                                      :dmc-request-wait
                                      (bus-dmc-dma-wait bus)))
                 :pending)
               (let* ((write-p (eq (bus-last-cpu-access-kind bus) :write))
                      (stall (if (and write-p
                                      (oddp (bus-cpu-cycle-phase bus)))
                                 3
                                 4)))
                 (incf (bus-dma-stall-cycles bus) stall)
                 (loop repeat (if write-p
                                  (1- stall)
                                  (if (zerop (bus-cpu-cycle-phase bus)) 1 2))
                       do (%bus-read-device
                           bus (bus-last-cpu-access-address bus)))
                 (logand (or (%bus-read-device bus address)
                             (bus-open-bus bus))
                         #xFF)))))))
    bus))


(defun %bus-read-device (bus address)
  (cond
    ((< address #x2000)
     (aref (bus-ram bus) (mod address #x800)))
    ((< address #x4000)
     (ppu-read-register (bus-ppu bus) (logand address 7) t))
    ((and (<= #x4000 address #x4015)
          (not (= address #x4014)))
     (apu-read-register (bus-apu bus) address))
    ((= address #x4016)
     (controller-read (bus-controller-1 bus)))
    ((= address #x4017)
     (controller-read (bus-controller-2 bus)))
    ((bus-cartridge bus)
     (cartridge-cpu-read (bus-cartridge bus) address))
    (t nil)))
(defun %bus-read-dma-source (bus address
                                 &key
                                 internal-address-predicate
                                 internal-value-when-source-unmapped-p)
  (flet ((read-internal-address (internal-address)
           (if (or (<= #x4000 internal-address #x4013)
                   (= internal-address #x4015)
                   (= internal-address #x4016)
                   (= internal-address #x4017))
               (%bus-read-value bus internal-address)
               (bus-open-bus bus))))
    (let* ((cpu-address (bus-last-cpu-access-address bus))
           (internal-io-read-p (= (logand cpu-address #xFFE0) #x4000))
           (source-io-address-p (<= #x4000 address #x401F))
           (held-io-suppresses-source-p
            (and source-io-address-p (not internal-io-read-p)))
           (source-device-value
            (unless held-io-suppresses-source-p
              (%bus-read-device bus address)))
           (source-value
            (if held-io-suppresses-source-p
                (bus-open-bus bus)
                (%bus-read-value-from-device bus address source-device-value)))
           (internal-address
            (when (and internal-io-read-p (not source-io-address-p))
              (logior #x4000 (logand address #x001F))))
           (internal-value
            (when
                (and internal-address
                     (or (null internal-address-predicate)
                         (funcall internal-address-predicate internal-address)))
              (read-internal-address internal-address)))
           (dma-source-value
            (if (and internal-value-when-source-unmapped-p
                     (null source-device-value)
                     internal-address
                     internal-value)
                (progn
                  (setf (bus-open-bus bus) internal-value)
                  internal-value)
                source-value)))
      (values dma-source-value internal-value))))
(defun %bus-read-dmc-sample (bus address)
  (flet ((conflict-address-p (conflict-address)
           (or (<= #x2000 conflict-address #x3FFF)
               (and (<= #x4000 conflict-address #x4017)
                    (/= conflict-address #x4014)))))
    (multiple-value-bind (sample-value internal-value)
        (%bus-read-dma-source bus
                              address
                              :internal-address-predicate
                              (function conflict-address-p))
      (let* ((cpu-address (bus-last-cpu-access-address bus))
             (conflict-address
              (logior (logand cpu-address #xFFE0) (logand address #x001F))))
        (if (conflict-address-p conflict-address)
            (let ((conflict-value
                   (or internal-value (%bus-read-value bus conflict-address))))
              (if (= conflict-address #x4015)
                  conflict-value
                  (logand sample-value conflict-value)))
            sample-value)))))

(defun %bus-read (bus address update-internal-data-bus-p)
  (declare (optimize (speed 3) (safety 1) (debug 1)))
  (let ((address (logand address #xFFFF)))
    (setf (bus-last-cpu-access-kind bus) :read
          (bus-last-cpu-access-address bus) address
          (bus-dmc-read-replay-p bus) nil)
    (%bus-run-dmc-dma-on-read! bus address)
    ;; A CPU read observes PPU status late in its cycle. Advance the PPU to
    ;; the final two dots before the device read and charge the last dot below.
    (let ((ppu-ticks 3))
      (when (and (bus-cpu-access-active-p bus)
                 (< address #x4000)
                 (or (= (logand address 7) 2) (= (logand address 7) 4)))
        (ppu-tick! (bus-ppu bus) 2)
        (setf ppu-ticks 1))
      (let ((value (%bus-read-value bus address)))
        (%bus-cpu-access-before-cycle! bus)
        (%bus-cpu-access! bus ppu-ticks)
        (when update-internal-data-bus-p
          (setf (bus-internal-data-bus bus) value))
        value))))

(defun bus-read (bus address) (%bus-read bus address t))

(defun %perform-oam-dma! (bus page)
  (if (bus-cpu-access-active-p bus)
      (progn
        ;; RMW writes arrive before DMA can halt on a read; the last page wins.
        (unless (bus-oam-dma-active-p bus)
          (incf (bus-dma-stall-cycles bus)
                (+ 513 (bus-cpu-cycle-phase bus))))
        (setf (bus-oam-dma-active-p bus) t
              (bus-oam-dma-page bus) (logand page #xFF)
              (bus-oam-dma-index bus) 0
              (bus-oam-dma-stage bus) :halt
              (bus-oam-dma-alignment-p bus)
              (= (bus-cpu-cycle-phase bus) 1)))
      (let ((base (ash (logand page #xFF) 8)))
        ;; Direct bus fixtures have no NES clock owner.  Preserve their
        ;; synchronous transfer semantics; CPU execution uses the state path.
        (with-bus-cpu-access-hook (bus nil)
          (loop for offset below 256 do
            (ppu-write-register! (bus-ppu bus) 4
                                 (%bus-read bus (+ base offset) nil))))
        (setf (bus-dma-stall-cycles bus)
              (+ (bus-dma-stall-cycles bus)
                 513
                 (bus-cpu-cycle-phase bus))))))

(defun %bus-dma-dummy-read! (bus)
  (%bus-read-device bus (bus-last-cpu-access-address bus)))


(defun bus-take-dma-stall-cycles! (bus)
  (prog1 (bus-dma-stall-cycles bus)
    (setf (bus-dma-stall-cycles bus) 0)))

(defun bus-write! (bus address value)
  (declare (optimize (speed 3) (safety 1) (debug 1)))
  (let ((address (logand address #xFFFF))
        (value (logand value #xFF))
        (ppu-ticks 3)
        (previous-address (bus-last-cpu-access-address bus)))
    (setf (bus-last-cpu-access-kind bus) :write
          (bus-last-cpu-access-address bus) address)
    (setf (bus-open-bus bus) value
          (bus-internal-data-bus bus) value)
    (when (and (bus-cpu-access-active-p bus)
               (< address #x4000)
               (= (logand address 7) 0)
               (not (logbitp 7 value)))
      (ppu-tick! (bus-ppu bus) 3)
      (setf ppu-ticks 0))
    (cond
      ((< address #x2000)
       (setf (aref (bus-ram bus) (mod address #x800)) value))
      ((< address #x4000)
       (ppu-write-register! (bus-ppu bus) (logand address 7) value t))
      ((and (<= #x4000 address #x4013))
       (apu-write-register! (bus-apu bus) address value))
      ((= address #x4014)
       (%perform-oam-dma! bus value))
      ((= address #x4015)
       (apu-write-register! (bus-apu bus) address value))
      ((= address #x4016)
       (let ((strobe-p (or (not (logbitp 0 value))
                           (not (= previous-address #x4016))
                           (= (bus-cpu-cycle-phase bus) 0))))
         (controller-write! (bus-controller-1 bus) value :strobe-p strobe-p)
         (controller-write! (bus-controller-2 bus) value :strobe-p strobe-p)))
      ((= address #x4017)
       (apu-write-register! (bus-apu bus) address value))
      ((bus-cartridge bus)
       (cartridge-cpu-write!
        (bus-cartridge bus) address value
        (when (bus-cpu-access-active-p bus)
          (+ (cpu-cycles (nes-cpu (bus-cpu-access-nes bus)))
             (bus-cpu-access-count bus)))))
      (t nil))
    (%bus-cpu-access-before-cycle! bus)
    (%bus-cpu-access! bus ppu-ticks)
    value))

(defun %bus-read-value-from-device (bus address device-value)
  (let* ((open-bus (bus-open-bus bus))
         (value
          (cond
            ((= address #x4015)
             (logior (logand (or device-value 0) #xDF)
                     (logand (bus-internal-data-bus bus) #x20)))
            ((or (= address #x4016) (= address #x4017))
             (logior (logand (or device-value 0) #x1F) (logand open-bus #xE0)))
            (t (logand (or device-value open-bus) #xFF)))))
    (unless (= address #x4015)
      (setf (bus-open-bus bus) value))
    value))

(defun %bus-read-value (bus address)
  (%bus-read-value-from-device bus address (%bus-read-device bus address)))

(defun %bus-cpu-access-before-cycle! (bus)
  (when (and (bus-cpu-access-active-p bus)
             (bus-cpu-access-pre-cycle-hook bus))
    (funcall (bus-cpu-access-pre-cycle-hook bus))))

(defun %bus-cpu-access! (bus &optional (ppu-ticks 3))
  (if (bus-cpu-access-active-p bus)
      (progn
        (incf (bus-cpu-access-count bus))
        (%nes-clock-cpu-cycle! (bus-cpu-access-nes bus)
                               bus
                               (bus-cpu-access-cycle-hook bus)
                               nil
                               ppu-ticks))
      (let ((hook (bus-cpu-access-hook bus)))
        (when hook
          (funcall hook)))))
(defun %bus-run-dmc-dma-on-read! (bus address)
  (let* ((phase (bus-cpu-cycle-phase bus))
         (stage (bus-dmc-dma-stage bus))
         (kind (bus-dmc-dma-kind bus))
         (eligible-p
           (or (eq stage :retry)
               (and (eq stage :ready)
                    (case kind
                      (:load (zerop phase))
                      (:reload (= phase 1)))))))
    (when (and eligible-p
               (bus-cpu-access-active-p bus)
               (not (bus-oam-dma-active-p bus)))
      (setf (bus-dmc-dma-stage bus) :active-halt
            (bus-dmc-dma-remaining bus) (if (zerop phase) 3 4))
      (loop while (member (bus-dmc-dma-stage bus)
                          '(:active-halt :dummy :alignment :get :abort))
            do (let ((ppu-ticks 3))
                 (unless (eq (bus-dmc-dma-stage bus) :get)
                   (when (and (< address #x4000)
                              (= (logand address 7) 2))
                     (ppu-tick! (bus-ppu bus) 2)
                     (setf ppu-ticks 1))
                   (%bus-read-value bus address))
                 (%bus-cpu-access-before-cycle! bus)
                 (%bus-cpu-access! bus ppu-ticks)
                 (when *nes-step-dma-cycles*
                   (incf *nes-step-dma-cycles*)))))))
