(require :asdf)

(asdf:load-system "cl-nes/compat")
(uiop:quit (uiop:symbol-call :cl-nes/compat :compat-main))
