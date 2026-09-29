(in-package #:cl-user)

(require :asdf)
(asdf:load-system "cl-nes/frontend/test")
(unless (asdf:test-system "cl-nes/frontend/test")
  (error "cl-nes frontend test suite failed."))
