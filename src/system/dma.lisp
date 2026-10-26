(in-package #:cl-nes)

(defvar *dma-trace-hook* nil)
(defvar *dma-trace-cycle-index* 0)

(defun %dma-trace-cycle! (bus master-clock phase)
  (when *dma-trace-hook*
    (funcall
     *dma-trace-hook*
     (list :phase phase
           :master-clock master-clock
           :cpu-parity (bus-cpu-cycle-phase bus)
           :apu-parity (apu-cycle-parity (bus-apu bus))
           :cpu-access-kind (bus-last-cpu-access-kind bus)
           :cpu-held-address (bus-last-cpu-access-address bus)
           :dmc-request-kind (bus-dmc-dma-kind bus)
           :dmc-stage (bus-dmc-dma-stage bus)
           :dmc-source-address
           (apu-dmc-current-address (apu-dmc (bus-apu bus)))
           :dmc-bytes-remaining
           (apu-dmc-bytes-remaining (apu-dmc (bus-apu bus)))
           :oam-stage (bus-oam-dma-stage bus)
           :oam-page (bus-oam-dma-page bus)
           :oam-index (bus-oam-dma-index bus)
           :oam-source-address
           (when (bus-oam-dma-active-p bus)
             (+ (ash (bus-oam-dma-page bus) 8)
                (bus-oam-dma-index bus)))
           :open-bus (bus-open-bus bus)
           :internal-data-bus (bus-internal-data-bus bus))))
  nil)

(defun %dma-arbitrate-cycle! (bus)
  (setf (bus-dma-cycle-preempted-p bus) nil)
  (unless (and (not (bus-oam-dma-active-p bus))
               (eq (bus-dmc-dma-stage bus) :idle)
               (zerop (bus-dmc-dma-remaining bus)))
    (let* ((oam-active-p (bus-oam-dma-active-p bus))
           (dmc-stage-this-cycle nil)
           (dmc-active-p nil)
           (dmc-get-p nil)
           (oam-access-p nil))
      (case (bus-dmc-dma-stage bus)
        (:new
         (if (plusp (bus-dmc-dma-wait bus))
             (progn
               (setf (bus-dmc-dma-stage bus) :wait)
               (decf (bus-dmc-dma-wait bus)))
             (setf (bus-dmc-dma-stage bus) :ready)))
        (:wait
         (when (plusp (bus-dmc-dma-wait bus))
           (decf (bus-dmc-dma-wait bus)))
         (when (zerop (bus-dmc-dma-wait bus))
           (setf (bus-dmc-dma-stage bus) :ready))))
      (when (and (eq (bus-dmc-dma-stage bus) :ready)
                 (eq (bus-last-cpu-access-kind bus) :write))
        (setf (bus-dmc-dma-stage bus) :retry))
      (when (and oam-active-p
                 (or (eq (bus-dmc-dma-stage bus) :retry)
                     (and (eq (bus-dmc-dma-stage bus) :ready)
                          (case (bus-dmc-dma-kind bus)
                            (:load (zerop (bus-cpu-cycle-phase bus)))
                            (:reload (= (bus-cpu-cycle-phase bus) 1)))))
                 (not (eq (bus-last-cpu-access-kind bus) :write)))
        (setf (bus-dmc-dma-stage bus) :active-halt
              (bus-dmc-dma-remaining bus)
              (if (zerop (bus-cpu-cycle-phase bus)) 3 4)))
      (setf dmc-stage-this-cycle (bus-dmc-dma-stage bus)
            dmc-active-p
            (or (eq dmc-stage-this-cycle :active-halt)
                (eq dmc-stage-this-cycle :dummy)
                (eq dmc-stage-this-cycle :alignment)
                (eq dmc-stage-this-cycle :get))
            dmc-get-p
            (and (eq dmc-stage-this-cycle :get)
                 (zerop (bus-cpu-cycle-phase bus))))
      (when dmc-active-p
        (case dmc-stage-this-cycle
          (:active-halt
           (setf (bus-dmc-dma-stage bus) :dummy))
          (:dummy
           (setf (bus-dmc-dma-stage bus)
                 (if (= (bus-cpu-cycle-phase bus) 1)
                     :get
                     :alignment)))
          (:alignment
           (when (= (bus-cpu-cycle-phase bus) 1)
             (setf (bus-dmc-dma-stage bus) :get)))
          (:get
           (when dmc-get-p
             (let* ((apu (bus-apu bus))
                    (dmc (apu-dmc apu))
                    (address (apu-dmc-current-address dmc))
                    (value (%bus-read-dmc-sample bus address)))
               (%apu-dmc-fetch-complete! apu value)
               (setf (bus-dmc-dma-stage bus) :idle))))))
      (when (and dmc-active-p
                 (or (not (eq dmc-stage-this-cycle :get))
                     dmc-get-p)
                 (plusp (bus-dmc-dma-remaining bus)))
        (decf (bus-dmc-dma-remaining bus)))
      (when (eq (bus-dmc-dma-stage bus) :idle)
        (setf (bus-dmc-dma-remaining bus) 0))
      (when oam-active-p
        (case (bus-oam-dma-stage bus)
          (:halt
           (unless (eq (bus-last-cpu-access-kind bus) :write)
             (setf (bus-oam-dma-stage bus)
                   (if (bus-oam-dma-alignment-p bus) :alignment :get))))
          (:alignment
           (setf (bus-oam-dma-stage bus) :get))
          (:get
           (if (or dmc-get-p (not (zerop (bus-cpu-cycle-phase bus))))
               (setf (bus-dma-cycle-preempted-p bus) t)
               (let ((address (+ (ash (bus-oam-dma-page bus) 8)
                                 (bus-oam-dma-index bus))))
                 (setf (bus-oam-dma-data bus)
                       (logand (%bus-read-value bus address) #xFF)
                       (bus-oam-dma-stage bus) :put
                       oam-access-p t))))
          (:put
           (if (= (bus-cpu-cycle-phase bus) 1)
               (progn
                 (ppu-write-register! (bus-ppu bus) 4 (bus-oam-dma-data bus))
                 (incf (bus-oam-dma-index bus))
                 (setf oam-access-p t)
                 (if (= (bus-oam-dma-index bus) 256)
                     (setf (bus-oam-dma-active-p bus) nil)
                     (setf (bus-oam-dma-stage bus) :get)))
               (setf (bus-dma-cycle-preempted-p bus) t)))))
      (when (and oam-active-p
                 (not dmc-get-p)
                 (not oam-access-p)
                 (not (eq (bus-last-cpu-access-kind bus) :write)))
        (%bus-dma-dummy-read! bus))))
  nil)
