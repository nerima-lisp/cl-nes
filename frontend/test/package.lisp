(defpackage #:cl-nes/frontend/test
  (:use #:cl)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave #:expect #:it)
  (:import-from #:cl-nes/frontend
                #:atomic-save-octets
                #:gamepad-button-mask
                #:glfw-gamepad-mask
                #:load-state-slot
                #:keyboard-button-mask
                #:make-cli-app
                #:make-rate-controller
                #:nes-button-mask
                #:rate-controller-delay
                #:rate-controller-update!
                #:restore-octets
                #:run-render
                #:run-rom-test
                #:rom-identity
                #:rom-state-directory
                #:save-state-slot
                #:savestate-path
                #:savestate-load-key
                #:savestate-save-key
                #:savestate-select-key))

(in-package #:cl-nes/frontend/test)

(import '(cl-nes:invalid-savestate
          cl-nes:cartridge-prg-ram
          cl-nes:make-cartridge
          cl-nes:make-nes
          cl-nes:nes-run-frame/k
          cl-nes:nes-save-state))
