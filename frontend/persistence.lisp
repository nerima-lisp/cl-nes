(in-package #:cl-nes/frontend)

(defun atomic-save-octets (pathname octets)
  "Write OCTETS to PATHNAME through a same-directory temporary file and rename."
  (let* ((target (pathname pathname))
         (temporary (make-pathname :name (format nil ".~A.~D"
                                                  (or (pathname-name target) "save")
                                                  (random most-positive-fixnum))
                                   :type (pathname-type target)
                                   :defaults target)))
    (unwind-protect
         (progn
           (with-open-file (stream temporary :direction :output
                                    :if-exists :supersede :if-does-not-exist :create
                                    :element-type '(unsigned-byte 8))
             (write-sequence octets stream)
             (finish-output stream))
           (uiop:rename-file-overwriting-target temporary target)
           target)
      (when (probe-file temporary) (delete-file temporary)))))

(defun restore-octets (pathname)
  (with-open-file (stream pathname :direction :input
                          :element-type '(unsigned-byte 8))
    (let ((octets (make-array (file-length stream)
                              :element-type '(unsigned-byte 8))))
      (read-sequence octets stream)
      octets)))
