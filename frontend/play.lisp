(in-package #:cl-nes/frontend)

(defun %restore-battery-file (cartridge battery-path)
  (handler-case
      (when (probe-file battery-path)
        (cl-nes:cartridge-restore-battery! cartridge
                                           (restore-octets battery-path)))
    (error (condition)
      (format *error-output*
              "Could not load battery file ~A: ~A~%"
              battery-path condition))))

(defun run-play (rom-path &key state-directory (scale 3))
  "Run a ROM in a GLFW window and pace emulation from the SDL queue."
  (let* ((cartridge (cl-nes:load-cartridge rom-path))
         (controller-1 (cl-nes:make-controller))
         (controller-2 (cl-nes:make-controller))
         (nes (cl-nes:make-nes :cartridge cartridge
                               :controller-1 controller-1
                               :controller-2 controller-2))
         (paused nil) (reset-requested nil) (previous-p nil) (previous-r nil)
         (previous-save nil) (previous-load nil) (selected-slot 0)
         (battery-path (merge-pathnames
                        (make-pathname :name "battery" :type "sav")
                        (rom-state-directory rom-path :state-directory state-directory)))
         (audio (make-audio-queue :sample-rate cl-nes:+nes-default-audio-sample-rate+
                                  :capacity 16384))
         (audio-buffer (cl-nes:make-nes-audio-buffer :size 512))
         (last-battery-save (get-internal-real-time))
         (battery-save-interval (* 3 internal-time-units-per-second)))
    (when (cl-nes:cartridge-battery-backed-p cartridge)
      (%restore-battery-file cartridge battery-path))
    (unwind-protect
         (cl-glfw3-kit:with-glfw ()
           (cl-glfw3-kit:with-glfw-window
               (window :width (* 256 scale) :height (* 240 scale) :title "cl-nes")
             (cl-glfw3-kit:make-context-current window)
             (let ((framebuffer (make-gl-framebuffer))
                   (rate (make-rate-controller)))
               (unwind-protect
                    (progn
                      (audio-queue-open! audio)
                      (unwind-protect
                           (labels ((save-battery-if-dirty ()
                               (when (and (cl-nes:cartridge-battery-backed-p cartridge)
                                          (cl-nes:cartridge-battery-dirty-p cartridge)
                                          (>= (- (get-internal-real-time)
                                                 last-battery-save)
                                              battery-save-interval))
                                 (atomic-save-octets battery-path
                                                      (cl-nes:cartridge-save-battery cartridge))
                                 (cl-nes:cartridge-clear-battery-dirty! cartridge)
                                 (setf last-battery-save (get-internal-real-time))))
                             (frame-continuation (pixels)
                               (gl-framebuffer-upload! framebuffer pixels))
                             (audio-continuation (buffer)
                               (audio-queue-push!
                                audio (cl-nes:nes-audio-buffer-samples buffer))))
                             (cl-nes:nes-run-frames/k
                              nes 8 #'frame-continuation
                              :audio-buffer audio-buffer
                              :audio-continuation #'audio-continuation)
                             (cl-glfw3-kit:for-each-frame (frame window)
                        (declare (ignore frame))
                          (let ((p (cl-glfw3-kit:key-pressed-p window :p))
                              (r (cl-glfw3-kit:key-pressed-p window :r))
                              (save (cl-glfw3-kit:key-pressed-p window (savestate-save-key)))
                              (load (cl-glfw3-kit:key-pressed-p window (savestate-load-key))))
                          (when (and p (not previous-p))
                            (setf paused (not paused)))
                          (when (and r (not previous-r))
                            (setf reset-requested t))
                          (loop for slot from 0 below +savestate-slot-count+
                                for key = (savestate-select-key slot)
                                when (cl-glfw3-kit:key-pressed-p window key)
                                  do (setf selected-slot slot))
                          (when (and save (not previous-save))
                            (save-state-slot nes rom-path selected-slot
                                             :state-directory state-directory)
                            (format t "Saved state slot ~D.~%" selected-slot))
                          (when (and load (not previous-load))
                            (handler-case
                                (progn
                                  (load-state-slot nes rom-path selected-slot
                                                    :state-directory state-directory)
                                  (format t "Loaded state slot ~D.~%" selected-slot))
                              (cl-nes:invalid-savestate (condition)
                                (format *error-output*
                                        "Could not load state slot ~D: ~A~%"
                                        selected-slot condition))
                              (file-error (condition)
                                (format *error-output*
                                        "Could not load state slot ~D: ~A~%"
                                        selected-slot condition))))
                          (setf previous-p p previous-r r
                                previous-save save previous-load load))
                        (when reset-requested
                          (cl-nes:nes-reset! nes)
                          (setf reset-requested nil))
                        (unless paused
                          (cl-nes:controller-set-buttons!
                           controller-1 (logior (keyboard-button-mask window)
                                                (glfw-gamepad-mask 0)))
                          (cl-nes:controller-set-buttons!
                           controller-2 (glfw-gamepad-mask 1))
                          (cl-nes:nes-run-frames/k
                           nes 1 #'frame-continuation
                           :audio-buffer audio-buffer
                           :audio-continuation #'audio-continuation))
                        (rate-controller-update! rate (audio-queue-size audio))
                        (when (plusp (rate-controller-delay rate))
                          (sleep (rate-controller-delay rate)))
                               (save-battery-if-dirty)))
                        (audio-queue-close! audio)))
                 (destroy-gl-framebuffer framebuffer)))))
      (when (and (cl-nes:cartridge-battery-backed-p cartridge)
                 (cl-nes:cartridge-battery-dirty-p cartridge))
        (atomic-save-octets battery-path
                            (cl-nes:cartridge-save-battery cartridge))
        (cl-nes:cartridge-clear-battery-dirty! cartridge)))
    nes))
