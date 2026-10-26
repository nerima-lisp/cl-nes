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
