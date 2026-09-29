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

(defmacro define-all-opcode-contract ()
  `(it-each ,(loop for opcode below 256 collect (list opcode))
       "executes opcode #x~2,'0X through the unified dispatch"
       (opcode)
     (with-fixture-cpu-system (cpu bus :program (list opcode 0 0))
       (let ((cycles (cpu-step! cpu bus)))
         (expect (plusp cycles) :to-be t)
         (when (cpu-stopped-p cpu)
           (expect (cpu-step! cpu bus) :to-be 0))))))

(describe "CPU complete opcode dispatch"
  (define-all-opcode-contract))

(describe "CPU ALU reference properties"
  (it-property "ADC matches the binary reference model"
      ((a (gen-integer :min 0 :max #xFF))
       (value (gen-integer :min 0 :max #xFF))
       (carry (gen-integer :min 0 :max 1)))
    (let ((cpu (make-cpu)))
      (setf (cpu-a cpu) a
            (cpu-p cpu) (if (= carry 1) cl-nes::+flag-carry+ 0))
      (cl-nes::%adc! cpu value)
      (expect (cpu-a cpu) :to-be (logand (+ a value carry) #xFF))
      (expect (not (zerop (logand cl-nes::+flag-carry+ (cpu-p cpu))))
              :to-be (> (+ a value carry) #xFF))))

  (it-property "SBC matches the binary reference model"
      ((a (gen-integer :min 0 :max #xFF))
       (value (gen-integer :min 0 :max #xFF))
       (carry (gen-integer :min 0 :max 1)))
    (let* ((cpu (make-cpu))
           (borrow (- 1 carry))
           (difference (- a value borrow)))
      (setf (cpu-a cpu) a
            (cpu-p cpu) (if (= carry 1) cl-nes::+flag-carry+ 0))
      (cl-nes::%sbc! cpu value)
      (expect (cpu-a cpu) :to-be (logand difference #xFF))
      (expect (not (zerop (logand cl-nes::+flag-carry+ (cpu-p cpu))))
              :to-be (>= difference 0)))))
