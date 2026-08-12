(in-package #:cl-nes/test)

(defmacro with-fixture-cpu
    ((cpu bus cartridge &rest cartridge-initargs) &body body)
  `(let* ((,cartridge (make-fixture-cartridge ,@cartridge-initargs))
          (,bus (make-bus :cartridge ,cartridge))
          (,cpu (make-cpu)))
     (cpu-reset! ,cpu ,bus)
     (locally
       ,@body)))

(defmacro it-with-fixture-cpu
    (description (cpu bus cartridge &rest cartridge-initargs) &body body)
  `(it ,description
     (with-fixture-cpu (,cpu ,bus ,cartridge
                             ,@cartridge-initargs)
       ,@body)))

(defmacro with-fixture-cpu-suite
    ((cpu bus cartridge &rest cartridge-initargs) &body body)
  `(progn
     ,@(loop for form in body
             collect
             (if (and (consp form)
                      (eq (first form) 'it))
                 `(it-with-fixture-cpu ,(second form)
                      (,cpu ,bus ,cartridge ,@cartridge-initargs)
                    ,@(cddr form))
                 form))))

(defmacro with-single-step-fixture-cpu
    ((cpu bus cartridge program a status &rest cartridge-initargs) &body body)
  `(with-fixture-cpu (,cpu ,bus ,cartridge
                           :program ,program
                           ,@cartridge-initargs)
     (setf (cpu-a ,cpu) ,a
           (cpu-p ,cpu) ,status)
     (expect (cpu-step! ,cpu ,bus) :to-be 2)
     (locally
       ,@body)))

(defmacro define-cpu-opcode-dispatch-spec (description cases)
  `(describe ,description
     (it-each ,cases
         "dispatches opcode #x~2,'0X in ~D cycles"
         (opcode expected-cycles)
       (let* ((bus (make-bus
                    :cartridge
                    (make-fixture-cartridge
                     :program (list opcode 0 0))))
              (cpu (make-cpu)))
         (cpu-reset! cpu bus)
         (let ((before (cpu-cycles cpu))
               (cycles (cpu-step! cpu bus)))
           (expect cycles :to-be expected-cycles)
           (expect (- (cpu-cycles cpu) before)
                   :to-be expected-cycles)
           (expect (<= 0 (cpu-pc cpu) #xFFFF)
                   :to-be t))))))

(defmacro define-cpu-interrupt-vector-spec (description cases)
  `(it-each ,cases
       ,description
       (label nmi-poll-result expected-pc)
     (declare (ignore label))
     (with-fixture-cpu (cpu bus cartridge)
       (set-fixture-vector! cartridge #xFFFA #x9000)
       (set-fixture-vector! cartridge #xFFFE #xA000)
       (setf (cpu-p cpu) #x20
             (cpu-pc cpu) #x8123)
       (let ((nmi-poll-count 0))
         (expect (cpu-interrupt! cpu bus :irq nil
                                 (lambda ()
                                   (incf nmi-poll-count)
                                   nmi-poll-result))
                 :to-be 7)
         (expect nmi-poll-count :to-be 1))
       (expect (cpu-pc cpu) :to-be expected-pc)
       (expect (cpu-sp cpu) :to-be #xFA))))

(defmacro define-cpu-alu-step-spec (description cases)
  `(it-each ,cases
       ,description
       (label program a status expected-a expected-flags)
     (declare (ignore label))
     (with-single-step-fixture-cpu
         (cpu bus cartridge program a status)
       (expect (cpu-a cpu) :to-be expected-a)
       (dolist (flag expected-flags)
         (expect (logand (cpu-p cpu) flag)
                 :to-be flag))
       (dolist (flag (list cl-nes::+flag-carry+
                           cl-nes::+flag-zero+
                           cl-nes::+flag-negative+
                           cl-nes::+flag-overflow+))
         (unless (member flag expected-flags)
           (expect (logand (cpu-p cpu) flag)
                   :to-be 0))))))

(defmacro expect-cpu-flags
    (cpu expected-flags
     &optional
       (checked-flags
        '(list cl-nes::+flag-carry+
               cl-nes::+flag-zero+
               cl-nes::+flag-negative+
               cl-nes::+flag-overflow+)))
  `(let ((expected-list ,expected-flags)
         (checked-list ,checked-flags))
     (dolist (flag checked-list)
       (expect (logand (cpu-p ,cpu) flag)
               :to-be (if (member flag expected-list) flag 0)))))

(defmacro define-cpu-value-op-spec (description cases)
  `(it-each ,cases
       ,description
       (label initial-a initial-status operator operand expected-value expected-flags)
     (declare (ignore label))
     (let ((cpu (make-cpu)))
       (setf (cpu-a cpu) initial-a
             (cpu-p cpu) initial-status)
       (expect (funcall operator cpu operand) :to-be expected-value)
       (expect-cpu-flags cpu expected-flags))))

(defmacro expect-cpu-cycle-delta ((cpu before-cycles) expected-cycles)
  `(expect (- (cpu-cycles ,cpu) ,before-cycles)
           :to-be ,expected-cycles))

(defmacro define-cpu-branch-step-spec (description cases)
  `(it-each ,cases
       ,description
       (opcode status start offset expected-pc expected-cycles)
     (with-fixture-cpu (cpu bus cartridge
                             :program (list opcode offset 0)
                             :start start)
       (setf (cpu-p cpu) status)
       (let ((before-cycles (cpu-cycles cpu)))
         (expect (cpu-step! cpu bus) :to-be expected-cycles)
         (expect (cpu-pc cpu) :to-be expected-pc)
         (expect-cpu-cycle-delta (cpu before-cycles) expected-cycles)))))

(defmacro define-cpu-branch-irq-delay-spec (description cases)
  `(it-each ,cases
       ,description
       (status start offset expected)
     (with-fixture-cpu (cpu bus cartridge
                             :program (list #x10 offset 0)
                             :start start)
       (setf (cpu-p cpu) status)
       (cpu-step! cpu bus)
       (expect (cl-nes::cpu-irq-poll-delay cpu) :to-be expected))))
