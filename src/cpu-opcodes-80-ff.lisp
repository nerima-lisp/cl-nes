(in-package #:cl-nes)

(define-opcode-dispatch %opcode-80-ff-dispatch
    ((%expand-opcode-literal-clauses
      +opcode-80-ff-literal-specs+)
     (%expand-opcode-write-clauses
      +opcode-80-ff-write-specs+)
     (%expand-opcode-adjust-register-clauses
      +opcode-80-ff-adjust-register-specs+)
     (%expand-opcode-transfer-clauses
      +opcode-80-ff-transfer-specs+)
     (%expand-opcode-branch-clauses
      +opcode-80-ff-branch-specs+)
     (%expand-opcode-read-clauses
      +opcode-80-ff-read-specs+)
     (%expand-opcode-rmw-clauses
      +opcode-80-ff-rmw-specs+)
     (%expand-opcode-flag-clauses
      +opcode-80-ff-flag-specs+)
     (%expand-opcode-literal-clauses
      +opcode-80-ff-zpx-nop-specs+)
     (%expand-opcode-literal-clauses
      +opcode-80-ff-absx-nop-specs+))
  (#x9A
   (setf (cpu-sp cpu) (cpu-x cpu))
   2)
  (#x9C (%unstable-store-op! cpu bus (cpu-x cpu) (cpu-y cpu)))
  (#x9E (%unstable-store-op! cpu bus (cpu-y cpu) (cpu-x cpu)))
  (otherwise
   (error 'illegal-opcode
          :opcode opcode
          :address address)))

(defun %execute-opcode-80-ff (cpu bus opcode address)
  (%opcode-80-ff-dispatch))
