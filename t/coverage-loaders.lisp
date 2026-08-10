(in-package #:cl-nes/test)

(describe "Coverage: loader contracts"
  (it "loads iNES images from pathname designators"
    (let* ((pathname (merge-pathnames
                      (make-pathname
                       :name (format nil "cl-nes-contract-~D"
                                     (get-internal-real-time))
                       :type "nes")
                      (uiop:temporary-directory)))
           (image (make-ines-image)))
      (unwind-protect
           (progn
             (with-open-file
                 (stream pathname
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create
                         :element-type '(unsigned-byte 8))
               (write-sequence image stream))
             (expect (cartridge-mapper (load-cartridge pathname)) :to-be 0)
             (expect (cartridge-mapper
                      (load-cartridge (namestring pathname)))
                     :to-be 0))
        (when (probe-file pathname)
          (delete-file pathname))))))
