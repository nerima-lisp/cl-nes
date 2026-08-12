(in-package #:cl-nes)

(defun %execute-opcode (cpu bus opcode address &optional nmi-poll)
  (if (<= opcode #x7F)
      (%execute-opcode-00-7f cpu bus opcode address nmi-poll)
      (%execute-opcode-80-ff cpu bus opcode address)))

(defun cpu-step! (cpu bus &optional nmi-poll)
  (if (cpu-stopped-p cpu)
      0
      (let* ((address (cpu-pc cpu))
             (opcode (%fetch-byte cpu bus))
             (_ (setf (cpu-irq-poll-delay cpu) nil))
             (cycles (progn _ (%execute-opcode cpu bus opcode address nmi-poll))))
        (incf (cpu-cycles cpu) cycles)
        cycles)))
