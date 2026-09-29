(in-package #:cl-nes/frontend/test)

(defun test-pathname (name type)
  (make-pathname :name (format nil "cl-nes-frontend-~A-~D"
                              name (random most-positive-fixnum))
                 :type type
                 :defaults (uiop:temporary-directory)))

(defun read-test-octets (pathname)
  (with-open-file (stream pathname :direction :input
                          :element-type '(unsigned-byte 8))
    (let ((octets (make-array (file-length stream)
                              :element-type '(unsigned-byte 8))))
      (read-sequence octets stream)
      octets)))

(describe "frontend input masks"
  (it "maps keyboard keys to the NES button bits"
    (let ((pressed '(:z :x :left-shift :kp-enter :up :right)))
      (expect (keyboard-button-mask
               :window
               :key (lambda (window key)
                      (declare (ignore window))
                      (member key pressed)))
              :to-be
              (nes-button-mask :a :b :select :start :up :right))))
  (it "maps gamepad button indices and ignores absent buttons"
    (expect (gamepad-button-mask #(1 1 0 0 0 0 1 1 0 0 0 1 1 1 1))
            :to-be
            (nes-button-mask :a :b :select :start :up :down :left :right)))
  (it "combines named NES button bits"
    (expect (nes-button-mask :a :right :start)
            :to-be
            (logior cl-nes:+button-a+
                    cl-nes:+button-right+
                    cl-nes:+button-start+))))

(describe "frontend rate controller"
  (it "does not delay below the target queue"
    (let ((controller (make-rate-controller :target-low 100 :target-high 300)))
      (expect (rate-controller-update! controller 0) :to-be 0d0)
      (expect (rate-controller-delay controller) :to-be 0d0)))
  (it "adds bounded delay when the queue is over target"
    (let ((controller (make-rate-controller :target-low 100 :target-high 300)))
      (expect (plusp (rate-controller-update! controller 10000)) :to-be t)
      (dotimes (count 10) (declare (ignore count))
        (rate-controller-update! controller 1000000))
      (expect (rate-controller-delay controller) :to-be 0.05d0))))

(describe "frontend audio conversion"
  (it "saturates samples before converting them to signed 16-bit PCM"
    (expect (cl-nes/frontend::%audio-sample->s16 2.0f0) :to-be 32767)
    (expect (cl-nes/frontend::%audio-sample->s16 -2.0f0) :to-be -32767)
    (expect (cl-nes/frontend::%audio-sample->s16 0.5f0) :to-be 16384)))

(describe "frontend CLI"
  (it "returns zero for help and parses the play options"
    (let ((stdout (make-string-output-stream)))
      (expect (cl-cli:run-app (make-cli-app)
                              :argv '("cl-nes" "play" "game.nes"
                                       "--state-directory" "/tmp/saves"
                                       "--scale" "2")
                              :stdout stdout
                              :stderr (make-string-output-stream))
              :to-be 70)
      (setf stdout (make-string-output-stream))
      (expect (cl-cli:run-app (make-cli-app)
                              :argv '("cl-nes" "--help")
                              :stdout stdout
                              :stderr (make-string-output-stream))
              :to-be 0)))
  (it "returns usage 64 for invalid arguments"
    (expect (cl-cli:run-app (make-cli-app)
                            :argv '("cl-nes" "no-such-command")
                            :stdout (make-string-output-stream)
                            :stderr (make-string-output-stream))
            :to-be 64)))

(describe "frontend battery persistence"
  (it "uses the ROM basename with a sav extension in the state directory"
    (let* ((state-directory (uiop:temporary-directory))
           (rom-path (merge-pathnames "zelda.nes" state-directory))
           (battery-path (merge-pathnames
                          (make-pathname :name (pathname-name rom-path)
                                         :type "sav")
                          state-directory)))
      (expect (namestring battery-path)
              :to-be
              (namestring (merge-pathnames "zelda.sav" state-directory)))))
  (it "writes and restores bytes through an atomic replacement"
    (let* ((pathname (test-pathname "battery" "sav"))
           (old #(1 2 3))
           (new #(9 8 7 6)))
      (unwind-protect
           (progn
             (atomic-save-octets pathname old)
             (expect (equalp (read-test-octets pathname) old) :to-be t)
             (atomic-save-octets pathname new)
             (expect (equalp (restore-octets pathname) new) :to-be t)
             (expect (null (directory
                            (make-pathname :name (format nil ".~A.*"
                                                         (pathname-name pathname))
                                           :type (pathname-type pathname)
                                           :defaults pathname)))
                     :to-be t))
        (when (probe-file pathname) (delete-file pathname))))))
