(defpackage #:cl-nes/frontend/test
  (:use #:cl)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave #:expect #:it)
  (:import-from #:cl-nes/frontend
                #:atomic-save-octets
                #:gamepad-button-mask
                #:keyboard-button-mask
                #:make-cli-app
                #:make-rate-controller
                #:nes-button-mask
                #:rate-controller-delay
                #:rate-controller-update!
                #:restore-octets))

(in-package #:cl-nes/frontend/test)
