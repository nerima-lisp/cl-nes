(in-package #:cl-nes)

(defmacro define-address-for-mode-cases ()
  `(ecase mode
     ,@(loop for (mode form)
               in '((:zp
                      (values (%fetch-byte cpu bus) nil nil))
                    (:zpx
                      (let ((address (%fetch-byte cpu bus)))
                        (bus-read bus address)
                        (values (mod (+ address (cpu-x cpu)) 256) nil nil)))
                    (:zpy
                      (let ((address (%fetch-byte cpu bus)))
                        (bus-read bus address)
                        (values (mod (+ address (cpu-y cpu)) 256) nil nil)))
                    (:abs
                      (values (%fetch-word cpu bus) nil nil))
                    (:absx
                      (let* ((base (%fetch-word cpu bus))
                             (address (logand (+ base (cpu-x cpu)) #xFFFF)))
                        (values address
                                (%addressing-page-crossed-p base address)
                                base)))
                    (:absy
                      (let* ((base (%fetch-word cpu bus))
                             (address (logand (+ base (cpu-y cpu)) #xFFFF)))
                        (values address
                                (%addressing-page-crossed-p base address)
                                base)))
                    (:indx
                      (let* ((address (%fetch-byte cpu bus))
                             (pointer (mod (+ address (cpu-x cpu)) 256)))
                        (bus-read bus address)
                        (values (%read-word-zero-page bus pointer) nil nil)))
                    (:indy
                      (let* ((pointer (%fetch-byte cpu bus))
                             (base (%read-word-zero-page bus pointer))
                             (address (logand (+ base (cpu-y cpu)) #xFFFF)))
                        (values address
                                (%addressing-page-crossed-p base address)
                                base))))
             collect `(,mode ,form))))
