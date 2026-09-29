(in-package #:cl-nes/test)

(defmacro expect-opcode-dispatch (opcode expected-cycles)
  `(with-fixture-cpu-system (cpu bus :program (list ,opcode 0 0))
     (expect-cpu-step-cycles cpu bus ,expected-cycles)
     (expect (<= 0 (cpu-pc cpu) #xFFFF)
             :to-be t)))

(defmacro define-opcode-dispatch-spec (description cases)
  `(it-each ,cases
      ,description
      (opcode expected-cycles)
    (expect-opcode-dispatch opcode expected-cycles)))
