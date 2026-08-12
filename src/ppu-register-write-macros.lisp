(in-package #:cl-nes)

(defmacro %ppu-write-decay! (ppu value &body body)
  `(progn
     (%ppu-drive-decay! ,ppu ,value)
     ,@body))

(defmacro %ppu-write-register-dispatch (register)
  `(case (logand ,register 7)
     ,@(loop for (index . forms)
               in +ppu-register-write-dispatch-forms+
             collect `((,index) ,@forms))))
