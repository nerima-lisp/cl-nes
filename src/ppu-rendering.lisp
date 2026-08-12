(in-package #:cl-nes)

(defmacro with-ppu-frame-index ((index x y) &body body)
  `(let ((,index (+ ,x (* ,y +ppu-width+))))
     ,@body))
