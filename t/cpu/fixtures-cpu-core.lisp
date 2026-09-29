(in-package #:cl-nes/test)

(defmacro with-fixture-cpu-system
    ((cpu bus &key (program ''()) (start #x8000)) &body body)
  "Bind CPU and BUS to a fresh fixture program and reset the CPU."
  `(let* ((,bus (make-bus
                 :cartridge
                 (make-fixture-cartridge
                  :program ,program
                  :start ,start)))
          (,cpu (make-cpu)))
     (cpu-reset! ,cpu ,bus)
     ,@body))

(defmacro with-fixture-cpu-state
    ((cpu bus &key (program ''()) (start #x8000)
                (a nil a-p)
                (x nil x-p)
                (y nil y-p)
                (p nil p-p)
                (pc nil pc-p)
                (sp nil sp-p)
                (stopped-p nil stopped-p-p))
     &body body)
  "Bind CPU and BUS to a fresh fixture and apply optional register state."
  `(with-fixture-cpu-system (,cpu ,bus :program ,program :start ,start)
     ,@(when a-p
         `((setf (cpu-a ,cpu) ,a)))
     ,@(when x-p
         `((setf (cpu-x ,cpu) ,x)))
     ,@(when y-p
         `((setf (cpu-y ,cpu) ,y)))
     ,@(when p-p
         `((setf (cpu-p ,cpu) ,p)))
     ,@(when pc-p
         `((setf (cpu-pc ,cpu) ,pc)))
     ,@(when sp-p
         `((setf (cpu-sp ,cpu) ,sp)))
     ,@(when stopped-p-p
         `((setf (cpu-stopped-p ,cpu) ,stopped-p)))
     ,@body))

(defmacro expect-cpu-step-cycles (cpu bus expected-cycles)
  "Assert the return value and cycle delta of one CPU step."
  `(let ((before (cpu-cycles ,cpu))
         (cycles (cpu-step! ,cpu ,bus)))
     (expect cycles :to-be ,expected-cycles)
     (expect (- (cpu-cycles ,cpu) before)
             :to-be ,expected-cycles)))
