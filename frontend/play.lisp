(in-package #:cl-nes/frontend)

(defun run-play (rom-path &key (state-directory (uiop:getcwd)) (scale 3))
  "Run a ROM in a GLFW window and pace emulation from the SDL queue."
  (let* ((cartridge (cl-nes:load-cartridge rom-path))
         (controller-1 (cl-nes:make-controller))
         (controller-2 (cl-nes:make-controller))
         (nes (cl-nes:make-nes :cartridge cartridge
                               :controller-1 controller-1
                               :controller-2 controller-2))
         (paused nil) (reset-requested nil) (previous-p nil) (previous-r nil)
         (battery-path (merge-pathnames
                        (make-pathname :type "sav"
                                       :name (pathname-name (pathname rom-path)))
                        (pathname state-directory)))
         (audio (make-audio-queue :sample-rate cl-nes:+nes-default-audio-sample-rate+
                                  :capacity 8192)))
    (when (and (cl-nes:cartridge-battery-backed-p cartridge)
               (probe-file battery-path))
      (cl-nes:cartridge-restore-battery! cartridge (restore-octets battery-path)))
    (unwind-protect
         (cl-glfw3-kit:with-glfw ()
           (cl-glfw3-kit:with-glfw-window
               (window :width (* 256 scale) :height (* 240 scale) :title "cl-nes")
             (cl-glfw3-kit:make-context-current window)
             (let ((framebuffer (make-gl-framebuffer))
                   (rate (make-rate-controller)))
               (audio-queue-open! audio)
               (unwind-protect
                    (cl-glfw3-kit:for-each-frame (frame window)
                      (declare (ignore frame))
                      (let ((p (cl-glfw3-kit:key-pressed-p window :p))
                            (r (cl-glfw3-kit:key-pressed-p window :r)))
                        (when (and p (not previous-p))
                          (setf paused (not paused)))
                        (when (and r (not previous-r))
                          (setf reset-requested t))
                        (setf previous-p p previous-r r))
                      (when reset-requested
                        (cl-nes:nes-reset! nes)
                        (setf reset-requested nil))
                      (unless paused
                        (cl-nes:controller-set-buttons!
                         controller-1 (logior (keyboard-button-mask window)
                                              (glfw-gamepad-mask 0)))
                        (cl-nes:controller-set-buttons!
                         controller-2 (glfw-gamepad-mask 1))
                        (let ((samples (make-array 1024 :adjustable t
                                                   :fill-pointer 0))
                              (sample-phase 0))
                          (cl-nes:nes-run-frame/k
                           nes
                           (lambda (pixels)
                             (gl-framebuffer-upload! framebuffer pixels))
                           :cycle-hook
                           (lambda ()
                             (incf sample-phase cl-nes:+nes-default-audio-sample-rate+)
                             (loop while (>= sample-phase
                                              cl-nes:+nes-ntsc-cpu-frequency+)
                                   do (decf sample-phase
                                            cl-nes:+nes-ntsc-cpu-frequency+)
                                      (vector-push-extend
                                       (cl-nes:apu-mix (cl-nes:nes-apu nes))
                                       samples))))
                          (when (plusp (length samples))
                            (audio-queue-push! audio samples))))
                      (rate-controller-update! rate (audio-queue-size audio))
                      (when (plusp (rate-controller-delay rate))
                        (sleep (rate-controller-delay rate))))
                 (audio-queue-close! audio)))))
      (when (cl-nes:cartridge-battery-backed-p cartridge)
        (atomic-save-octets battery-path
                            (cl-nes:cartridge-save-battery cartridge))))
    nes))
