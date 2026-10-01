(in-package #:cl-nes/test)

(defmacro expect-opcode-dispatch-reachable (opcode)
  `(with-fixture-cpu-system (cpu bus :program (list ,opcode 0 0))
     (let ((cycles (cpu-step! cpu bus)))
       (expect (plusp cycles) :to-be t)
       (expect (<= 0 (cpu-pc cpu) #xFFFF)
               :to-be t))))

(defmacro define-opcode-dispatch-reachability-spec (description cases)
  `(progn
     ,@(mapcar
        (lambda (case)
          `(it ,(format nil description (first case))
             (expect-opcode-dispatch-reachable ,(first case))))
        cases)))

(defmacro define-opcode-dispatch-spec (description cases)
  `(define-opcode-dispatch-reachability-spec ,description ,cases))

(defmacro define-all-opcode-dispatch-reachability-contract ()
  `(progn
     ,@(loop for opcode below 256
             collect `(it
                       ,(format nil
                                "reaches opcode #x~2,'0X through the unified dispatch"
                                opcode)
                       (with-fixture-cpu-system
                           (cpu bus :program (list ,opcode 0 0))
                         (let ((cycles (cpu-step! cpu bus)))
                           (expect (plusp cycles) :to-be t)))))))

(describe "CPU opcode dispatch reachability"
  (define-all-opcode-dispatch-reachability-contract))

(defmacro expect-cpu-opcode-semantics (opcode program initial expected)
  (let ((program-form (if (and (consp program) (eq (first program) 'quote))
                          program
                          (list 'quote program))))
    `(with-fixture-cpu-state
       (cpu bus :program ,program-form
            :a ,(getf initial :a)
            :x ,(getf initial :x)
            :y ,(getf initial :y)
            :sp ,(getf initial :sp)
            :p ,(getf initial :p)
            :pc ,(getf initial :pc))
     (dolist (cell ',(getf initial :memory))
       (apply #'bus-write! bus cell))
     (expect-cpu-step-cycles cpu bus ,(getf expected :cycles))
     (expect (cpu-a cpu) :to-be ,(getf expected :a))
     (expect (cpu-x cpu) :to-be ,(getf expected :x))
     (expect (cpu-y cpu) :to-be ,(getf expected :y))
     (expect (cpu-sp cpu) :to-be ,(getf expected :sp))
     (expect (cpu-pc cpu) :to-be ,(getf expected :pc))
     (expect (cpu-p cpu) :to-be ,(getf expected :p))
     (dolist (cell ',(getf expected :memory))
       (expect (bus-read bus (first cell)) :to-be (second cell))))))

(defmacro define-cpu-semantics-spec (description cases)
  (if (keywordp (first (first cases)))
      `(progn
         ,@(mapcar
            (lambda (case)
              `(it ,(format nil description (getf case :opcode))
                 (run-cpu-semantic-case (list ,@case))))
            cases))
      `(progn
         ,@(mapcar
            (lambda (case)
              `(it ,(format nil description (first case))
                 (expect-cpu-opcode-semantics ,(first case)
                                              ,(second case)
                                              ,(third case)
                                              ,(fourth case))))
            cases))))

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
