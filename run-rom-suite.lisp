(require :asdf)

(asdf:load-system "cl-nes/rom-suite")
(uiop:symbol-call :cl-nes/rom-suite :rom-suite-main)
