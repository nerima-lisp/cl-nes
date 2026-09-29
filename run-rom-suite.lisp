(require :asdf)

(asdf:load-system "cl-nes/rom-suite")
(uiop:quit (uiop:symbol-call :cl-nes/rom-suite :rom-suite-main))
