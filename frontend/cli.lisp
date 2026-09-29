(in-package #:cl-nes/frontend)

(defun %render-handler (invocation)
  (handler-case
      (progn
        (run-render (positional-value invocation :rom)
                    (option-value invocation :frames)
                    (option-value invocation :prefix)
                    (option-value invocation :format))
        0)
    (error (condition)
      (format (cl-cli:invocation-stderr invocation) "cl-nes render: ~A~%" condition)
      1)))

(defun %rom-test-handler (invocation)
  (handler-case
      (run-rom-test (positional-value invocation :rom)
                    (option-value invocation :max-frames))
    (error (condition)
      (format (cl-cli:invocation-stderr invocation) "cl-nes rom-test: ~A~%" condition)
      1)))

(defun make-cli-app ()
  (make-app
   :name "cl-nes"
   :version *frontend-version*
   :summary "Play, render, and test Nintendo Entertainment System ROMs."
   :require-command t
   :commands
   (list
    (make-command
     :name "play"
     :description "Run a ROM in the interactive frontend."
     :positionals (list (make-positional :key :rom :name "ROM" :required-p t))
     :options (list
               (make-option :key :state-directory :name "state-directory"
                                   :kind :value :type :string :default "./")
               (make-option :key :scale :name "scale"
                                   :kind :value :type :integer :min 1 :default 3))
     :handler (lambda (invocation)
                (run-play (positional-value invocation :rom)
                          :state-directory (option-value invocation :state-directory)
                          :scale (option-value invocation :scale))
                0))
    (make-command
     :name "render" :description "Render ROM frames to PPM or PNG files."
     :positionals (list (make-positional :key :rom :name "ROM" :required-p t))
     :options (list (make-option :key :frames :name "frames" :kind :value
                                 :type :integer :min 1 :default 1)
                    (make-option :key :prefix :name "prefix" :kind :value
                                 :default "frame")
                    (make-option :key :format :name "format" :kind :value
                                 :choices '("ppm" "png") :default "ppm"))
     :handler #'%render-handler)
    (make-command
     :name "rom-test" :description "Run one ROM using the $6000 test protocol."
     :positionals (list (make-positional :key :rom :required-p t))
     :options (list (make-option :key :max-frames :name "max-frames" :kind :value
                                 :type :integer :min 1 :default 360))
     :handler #'%rom-test-handler))))

(defun main (&optional argv)
  (run-app (make-cli-app) :argv (or argv (application-argv))))

(defun image-entry-point ()
  (let ((code (main)))
    #+sbcl (host-kit:quit code)
    #-sbcl (uiop:quit code)))
