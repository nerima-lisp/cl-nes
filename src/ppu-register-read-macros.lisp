(in-package #:cl-nes)

(defmacro %ppu-read-decay-result ((ppu value &optional (mask '#xFF)) &body body)
  `(progn
     (%ppu-drive-decay! ,ppu ,value ,mask)
     ,@body))

(defmacro %ppu-read-register-dispatch (register)
  `(case (logand ,register 7)
     ,@(loop for (index . forms)
               in +ppu-register-read-dispatch-forms+
             collect `((,index) ,@forms))
     (otherwise
      (%ppu-read-open-bus ppu bus-access-p))))
