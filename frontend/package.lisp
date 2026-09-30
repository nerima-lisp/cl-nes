(defpackage #:cl-nes/frontend
  (:use #:cl)
  (:import-from #:cl-nes
                #:+nes-frame-height+ #:+nes-frame-width+
                #:bus-read #:load-cartridge #:make-nes #:nes-bus #:nes-ppu
                #:nes-run-frame/k #:nes-write-ppm #:ppu-framebuffer
                #:run-blargg-protocol)
  (:import-from #:cl-cli
                #:application-argv #:make-app #:make-command #:make-option
                #:make-positional #:option-value #:positional-value #:run-app)
  (:export
   #:*frontend-version*
   #:nes-button-mask
   #:keyboard-button-mask
   #:gamepad-button-mask
   #:glfw-gamepad-mask
   #:make-rate-controller
   #:rate-controller
   #:rate-controller-update!
   #:rate-controller-delay
   #:make-audio-queue
   #:audio-queue
   #:audio-queue-open!
   #:audio-queue-close!
   #:audio-queue-push!
   #:audio-queue-size
   #:audio-queue-underruns
   #:audio-queue-overruns
   #:atomic-save-octets
   #:restore-octets
   #:frontend-data-directory
   #:rom-identity
   #:rom-state-directory
   #:savestate-path
   #:savestate-select-key
   #:savestate-save-key
   #:savestate-load-key
   #:save-state-slot
   #:load-state-slot
   #:make-gl-framebuffer
   #:gl-framebuffer-upload!
   #:run-play
   #:run-render #:run-rom-test #:run-blargg-protocol
   #:make-cli-app
   #:main #:image-entry-point))

(in-package #:cl-nes/frontend)

(defparameter *frontend-version* "0.2.0")
