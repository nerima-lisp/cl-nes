(in-package #:cl-nes)

(define-opcode-dispatch %opcode-00-7f-dispatch
    ((%expand-opcode-read-clauses
      +opcode-00-7f-read-specs+)
     (%expand-opcode-rmw-clauses
      +opcode-00-7f-rmw-specs+)
     (%expand-opcode-branch-clauses
      +opcode-00-7f-branch-specs+)
     (%expand-opcode-flag-clauses
      +opcode-00-7f-flag-specs+)
     (%expand-opcode-accumulator-clauses
      +opcode-00-7f-accumulator-specs+)
     (%expand-opcode-literal-clauses
      +opcode-00-7f-literal-specs+))
  (#x00
   ;; BRK reads and discards its padding byte before pushing
   ;; the return address.
   (bus-read bus (cpu-pc cpu))
   (setf (cpu-pc cpu) (logand (1+ (cpu-pc cpu)) #xFFFF))
   (%push-word! cpu bus (cpu-pc cpu))
   (%push-byte! cpu bus (%status-for-stack cpu t))
   (%set-flag! cpu +flag-interrupt-disable+ t)
   ;; A pending NMI can hijack BRK after its stack writes but
   ;; before the interrupt vector is fetched.  The pushed
   ;; status still has BRK set, as on the 6502.
   (let ((vector-type
           (if (and nmi-poll (funcall nmi-poll))
               :nmi
               :irq)))
     (setf (cpu-pc cpu)
           (if (eq vector-type :nmi)
               (logior (bus-read bus #xFFFA)
                       (ash (bus-read bus #xFFFB) 8))
               (logior (bus-read bus #xFFFE)
                       (ash (bus-read bus #xFFFF) 8)))))
   7)
  (#x08
   ;; PHP has an internal/dummy read before the stack write.
   (bus-read bus (cpu-pc cpu))
   (%push-byte! cpu bus (%status-for-stack cpu t))
   3)
  (#x20
   ;; JSR fetches the low target byte, performs a dummy stack
   ;; read, pushes the return address, and fetches the high
   ;; target byte last.
   (let* ((low (%fetch-byte cpu bus))
          (return-address (cpu-pc cpu)))
     (bus-read bus (+ #x100 (cpu-sp cpu)))
     (%push-byte! cpu bus (ldb (byte 8 8) return-address))
     (%push-byte! cpu bus (ldb (byte 8 0) return-address))
     (setf (cpu-pc cpu)
           (logior low (ash (%fetch-byte cpu bus) 8)))
     6))
  (#x24
   (multiple-value-bind (operand ignored)
       (%address-for-mode cpu bus :zp)
     (declare (ignore ignored))
     (%bit! cpu (bus-read bus operand))
     3))
  (#x28
   ;; PLP has a dummy read from the next instruction byte and
   ;; a second dummy read from the current stack location.
   (bus-read bus (cpu-pc cpu))
   (bus-read bus (+ #x100 (cpu-sp cpu)))
   (%restore-status! cpu (%pop-byte! cpu bus))
   4)
  (#x2C
   (%bit! cpu (bus-read bus (%fetch-word cpu bus)))
   4)
  (#x40
   ;; RTI's two cycles before pulling the status are dummy
   ;; reads, one from the next instruction and one from the
   ;; current stack location.
   (bus-read bus (cpu-pc cpu))
   (bus-read bus (+ #x100 (cpu-sp cpu)))
   (%restore-status! cpu (%pop-byte! cpu bus) nil)
   (setf (cpu-pc cpu) (%pop-word! cpu bus))
   6)
  (#x48
   ;; PHA has an internal/dummy read before the stack write.
   (bus-read bus (cpu-pc cpu))
   (%push-byte! cpu bus (cpu-a cpu))
   3)
  (#x4C
   (setf (cpu-pc cpu) (%fetch-word cpu bus))
   3)
  (#x58
   (let ((was-disabled
           (%flag-set-p cpu +flag-interrupt-disable+)))
     (%set-flag! cpu +flag-interrupt-disable+ nil)
     (when was-disabled
       (setf (cpu-irq-delay cpu) 1))
     2))
  (#x60
   ;; RTS performs a next-PC dummy read, a stack dummy read,
   ;; pulls the return address, then reads from the resumed PC.
   (bus-read bus (cpu-pc cpu))
   (bus-read bus (+ #x100 (cpu-sp cpu)))
   (setf (cpu-pc cpu)
         (logand (1+ (%pop-word! cpu bus)) #xFFFF))
   (bus-read bus (cpu-pc cpu))
   6)
  (#x68
   ;; PLA has the same two dummy reads as PLP.
   (bus-read bus (cpu-pc cpu))
   (bus-read bus (+ #x100 (cpu-sp cpu)))
   (setf (cpu-a cpu) (%pop-byte! cpu bus))
   (%update-zn! cpu (cpu-a cpu))
   4)
  (#x6C (%jump-indirect cpu bus))
  (#x78
   (let ((was-disabled
           (%flag-set-p cpu +flag-interrupt-disable+)))
     (%set-flag! cpu +flag-interrupt-disable+ t)
     (unless was-disabled
       (setf (cpu-irq-delay cpu) 1))
     2))
  (otherwise
   (error 'illegal-opcode
          :opcode opcode
          :address address)))

(defun %execute-opcode-00-7f (cpu bus opcode address &optional nmi-poll)
  (%opcode-00-7f-dispatch))
