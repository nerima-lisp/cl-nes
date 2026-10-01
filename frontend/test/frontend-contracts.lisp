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

(defun delete-test-path (pathname)
  (when (probe-file pathname)
    (if (uiop:directory-pathname-p pathname)
        (uiop:delete-directory-tree pathname :validate t)
        (delete-file pathname))))

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
  (it "keeps an unconnected GLFW gamepad on the safe zero-mask path"
    (expect (glfw-gamepad-mask 0) :to-be 0))
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
                     :to-be t)
             (handler-case
                 (atomic-save-octets pathname #(999))
               (type-error () nil))
             (expect (equalp (restore-octets pathname) new) :to-be t))
        (when (probe-file pathname) (delete-file pathname))))))

(describe "frontend save-state slots"
  (it "assigns number keys to slots and function keys to save/load"
    (expect (equal (list (savestate-select-key 0)
                         (savestate-select-key 9)
                         (savestate-save-key)
                         (savestate-load-key))
                   '(:0 :9 :f5 :f7))
            :to-be t))
  (it "derives a stable ROM-identity directory and slot pathname"
    (let* ((directory (make-pathname :name (format nil "cl-nes-rom-~D"
                                                   (random most-positive-fixnum))
                                     :defaults (uiop:temporary-directory)))
           (rom-path (merge-pathnames "game.nes" directory))
           (rom-octets #(1 2 3 4))
           (state-directory (merge-pathnames "state/" directory)))
      (unwind-protect
           (progn
             (atomic-save-octets rom-path rom-octets)
             (expect (string= (rom-identity rom-path)
                              "9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a")
                     :to-be t)
             (let ((slot-path (savestate-path
                               rom-path 3 :state-directory state-directory)))
               (expect (pathname-name slot-path) :to-equal "slot-3")
               (expect (pathname-type slot-path) :to-equal "state")
               (expect (equal (last (pathname-directory slot-path) 2)
                              (list "cl-nes" (rom-identity rom-path)))
                       :to-be t)))
        (delete-test-path directory))))
  (it "round-trips a real core state through a slot file"
    (let* ((directory (make-pathname :name (format nil "cl-nes-state-~D"
                                                   (random most-positive-fixnum))
                                     :defaults (uiop:temporary-directory)))
           (rom-path (merge-pathnames "game.nes" directory))
           (state-directory (merge-pathnames "state/" directory))
           (nes (make-nes)))
      (unwind-protect
           (progn
             (atomic-save-octets rom-path #(1 2 3))
             (let ((expected (nes-save-state nes)))
               (save-state-slot nes rom-path 2 :state-directory state-directory)
               (expect (not (null (probe-file (savestate-path
                                               rom-path 2 :state-directory state-directory))))
                       :to-be t)
               (nes-run-frame/k nes (lambda (framebuffer)
                                      (declare (ignore framebuffer))))
               (load-state-slot
                nes rom-path 2 :state-directory state-directory)
               (expect (equalp (nes-save-state nes) expected) :to-be t)))
        (delete-test-path directory))))
  (it "rejects a truncated slot file as invalid save state"
    (let* ((directory (make-pathname :name (format nil "cl-nes-broken-~D"
                                                   (random most-positive-fixnum))
                                     :defaults (uiop:temporary-directory)))
           (rom-path (merge-pathnames "game.nes" directory))
           (state-directory (merge-pathnames "state/" directory))
           (nes (make-nes)))
      (unwind-protect
           (progn
             (atomic-save-octets rom-path #(1 2 3))
             (atomic-save-octets
              (savestate-path
               rom-path 0 :state-directory state-directory)
              #(67 76 78))
             (let ((condition
                     (handler-case
                         (progn
                           (load-state-slot
                            nes rom-path 0 :state-directory state-directory)
                           nil)
                       (condition (condition) condition))))
               (expect (typep condition 'invalid-savestate) :to-be t)))
        (delete-test-path directory)))))
