(in-package #:cl-nes)

(defmacro %define-octet-allocator (name size)
  `(defun ,name ()
     (%make-zeroed-octet-vector ,size)))

(defmacro %invalid-rom-unless (test reason)
  `(unless ,test
     (error 'invalid-rom :reason ,reason)))
