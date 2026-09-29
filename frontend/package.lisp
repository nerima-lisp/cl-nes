(defpackage #:cl-nes/frontend
  (:use #:cl)
  (:import-from #:cl-nes
                #:+nes-frame-height+ #:+nes-frame-width+
                #:bus-read #:load-cartridge #:make-nes #:nes-bus #:nes-ppu
                #:nes-run-frame/k #:nes-write-ppm #:ppu-framebuffer
                #:run-blargg-protocol #:run-screen-protocol)
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
   #:atomic-save-octets
   #:restore-octets
   #:make-gl-framebuffer
   #:gl-framebuffer-upload!
   #:run-play
   #:run-render #:run-rom-test #:run-blargg-protocol #:run-screen-protocol
   #:make-cli-app
   #:main #:image-entry-point))

(in-package #:cl-nes/frontend)

(defparameter *frontend-version* "0.1.1")

(defconstant +button-a-mask+ cl-nes:+button-a+)
(defconstant +button-b-mask+ cl-nes:+button-b+)
(defconstant +button-select-mask+ cl-nes:+button-select+)
(defconstant +button-start-mask+ cl-nes:+button-start+)
(defconstant +button-up-mask+ cl-nes:+button-up+)
(defconstant +button-down-mask+ cl-nes:+button-down+)
(defconstant +button-left-mask+ cl-nes:+button-left+)
(defconstant +button-right-mask+ cl-nes:+button-right+)
