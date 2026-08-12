(in-package #:cl-nes)

(defmacro define-cpu-alu-accumulator-ops ()
  `(progn
     ,@(loop for (name operator) in '((%ora! logior)
                                      (%and! logand)
                                      (%eor! logxor))
             collect
             `(defun ,name (cpu value)
                (%update-zn! cpu
                             (setf (cpu-a cpu)
                                   (,operator (cpu-a cpu) value)))))))

(defmacro define-cpu-alu-compare-ops ()
  `(progn
     ,@(loop for (name reader) in '((%cmp-a! cpu-a)
                                    (%cmp-x! cpu-x)
                                    (%cmp-y! cpu-y))
             collect
             `(defun ,name (cpu value)
                (%compare! cpu (,reader cpu) value)))))

(defmacro define-cpu-alu-value-ops ()
  `(progn
     ,@(loop for (name carry-form result-form)
               in '((%asl-value! (not (zerop (logand value #x80)))
                     (logand (ash value 1) #xFF))
                    (%lsr-value! (not (zerop (logand value 1)))
                     (ash value -1))
                    (%rol-value! (not (zerop (logand value #x80)))
                     (let ((carry-in (if (%flag-set-p cpu +flag-carry+) 1 0)))
                       (logand (logior (ash value 1) carry-in) #xFF)))
                    (%ror-value! (not (zerop (logand value 1)))
                     (let ((carry-in (if (%flag-set-p cpu +flag-carry+) #x80 0)))
                       (logior (ash value -1) carry-in)))
                    (%inc-value! nil
                     (mod (1+ value) 256))
                    (%dec-value! nil
                     (mod (1- value) 256)))
             collect
             `(defun ,name (cpu value)
                ,@(when carry-form
                    `((%set-flag! cpu +flag-carry+ ,carry-form)))
                (%update-zn! cpu ,result-form)))))

(defmacro define-cpu-alu-rmw-ops ()
  `(progn
     ,@(loop for (name transform accumulator)
               in '((%slo-value! %asl-value! %ora!)
                    (%rla-value! %rol-value! %and!)
                    (%sre-value! %lsr-value! %eor!)
                    (%rra-value! %ror-value! %adc!)
                    (%dcp-value! %dec-value! %cmp-a!)
                    (%isc-value! %inc-value! %sbc!))
             collect
             `(defun ,name (cpu value)
                (let ((updated (,transform cpu value)))
                  (,accumulator cpu updated)
                  updated)))))

(defmacro define-cpu-alu-derived-ops ()
  `(progn
     ,@(loop for (name . body)
               in '((%lax!
                      (setf (cpu-a cpu) value
                            (cpu-x cpu) value)
                      (%update-zn! cpu value))
                    (%aac!
                      (let ((result (%and! cpu value)))
                        (%set-flag! cpu +flag-carry+ (not (zerop (logand result #x80))))
                        result))
                    (%asr!
                      (let ((result (%lsr-value! cpu (%and! cpu value))))
                        (setf (cpu-a cpu) result)
                        result))
                    (%arr!
                      (let* ((masked (logand (cpu-a cpu) value))
                             (carry-in (if (%flag-set-p cpu +flag-carry+) #x80 0))
                             (result (logand (logior (ash masked -1) carry-in) #xFF)))
                        (setf (cpu-a cpu) result)
                        (%update-zn! cpu result)
                        (%set-flag! cpu +flag-carry+ (not (zerop (logand result #x40))))
                        (%set-flag! cpu +flag-overflow+
                                    (not (eql (logbitp 6 result)
                                              (logbitp 5 result))))
                        result))
                    (%atx!
                      (setf (cpu-a cpu) (logand (logior (cpu-a cpu) #xFF) value)
                            (cpu-x cpu) (cpu-a cpu))
                      (%update-zn! cpu (cpu-a cpu)))
                    (%axs!
                      (let* ((masked (logand (cpu-a cpu) (cpu-x cpu)))
                             (result (logand (- masked value) #xFF)))
                        (setf (cpu-x cpu) result)
                        (%set-flag! cpu +flag-carry+ (>= masked value))
                        (%update-zn! cpu result))))
             collect
             `(defun ,name (cpu value)
                ,@body))))
