(in-package #:cl-nes)

(defmacro %apu-console-reset! (apu-var)
  (let ((snapshot-bindings
          (loop for (state-var channel-reader places) in +apu-console-reset-register-specs+
                collect
                `(,state-var
                  (let ((channel (,channel-reader ,apu-var)))
                    (list ,@places)))))
        (restore-forms
          (loop for (state-var channel-reader places) in +apu-console-reset-register-specs+
                collect
                (let ((values (loop repeat (length places) collect (gensym "VALUE"))))
                  `(destructuring-bind ,values ,state-var
                     (let ((channel (,channel-reader ,apu-var)))
                       (setf
                        ,@(loop for place in places
                                for value in values
                                append `(,place ,value))))))))
        (frame-restore-forms
          (loop for (place value) in +apu-console-reset-frame-restore-specs+
                append `(,place ,value))))
    `(let* ((five-step (apu-frame-last-five-step-p ,apu-var))
            ,@snapshot-bindings)
       (apu-reset! ,apu-var)
       ,@restore-forms
       (setf ,@frame-restore-forms)
       ,apu-var)))
