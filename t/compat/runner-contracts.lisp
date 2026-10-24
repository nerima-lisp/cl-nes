(in-package #:cl-nes/compat)

(cl-weave:describe "compatibility runner input"
                   (cl-weave:it
                    "holds Start for memory frames 1 through 180, then releases"
                    (let* ((controller (cl-nes:make-controller))
                           (input
                            (%compat-input-continuation "memory" controller)))
                      (funcall input nil)
                      (cl-weave:expect (cl-nes:controller-buttons controller)
                                       :to-be
                                       cl-nes:+button-start+)
                      (loop repeat 178
                            do (funcall input nil))
                      (funcall input nil)
                      (cl-weave:expect (cl-nes:controller-buttons controller)
                                       :to-be
                                       cl-nes:+button-start+)
                      (funcall input nil)
                      (cl-weave:expect (cl-nes:controller-buttons controller)
                                       :to-be
                                       0)))
                   (cl-weave:it "maps ROM IDs to frame-indexed input sequences"
                                (cl-weave:expect
                                 (cdr
                                  (assoc "memory"
                                         *compat-input-sequences*
                                         :test
                                         (function string=)))
                                 :to-equal
                                 (list (cons 1 cl-nes:+button-start+)
                                       (cons 181 0))))
                   (cl-weave:it "does not inject input for other ROMs"
                                (let ((controller (cl-nes:make-controller)))
                                  (cl-weave:expect
                                   (%compat-input-continuation "other"
                                                               controller)
                                   :to-be
                                   nil)
                                  (cl-weave:expect
                                   (cl-nes:controller-buttons controller)
                                   :to-be
                                   0)))
                   (cl-weave:it
                    "marks ready flat output silent after visual and deterministic gates"
                    (let* ((first
                            (list :first-hash
                                  1
                                  :last-hash
                                  2
                                  :unique-pixels
                                  2
                                  :audio-samples
                                  0
                                  :audio-ready-p
                                  t
                                  :audio-spread
                                  0.0f0
                                  :pc-count
                                  2))
                           (second (list :last-hash 2)))
                      (cl-weave:expect (%classify first second) :to-be :silent)
                      (setf (getf first :audio-spread) 0.25f0)
                      (cl-weave:expect (%classify first second) :to-be :pass)))
                   (cl-weave:it
                    "does not mark a never-ready flat ROM silent"
                    (let* ((first
                            (list :first-hash 1 :last-hash 2
                                  :unique-pixels 2 :audio-ready-p nil
                                  :audio-spread 0.0f0 :pc-count 2))
                           (second (list :last-hash 2)))
                      (cl-weave:expect (%classify first second) :to-be :pass))))
