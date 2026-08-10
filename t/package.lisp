(in-package #:cl-user)

(defpackage #:cl-nes/test
  (:use #:cl #:cl-nes)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
                #:expect
                #:gen-integer
                #:gen-member
                #:gen-one-of
                #:gen-such-that
                #:gen-state-machine
                #:gen-tuple
                #:it
                #:it-each
                #:it-property
                #:with-soft-assertions))

(defpackage #:cl-nes/test-runner
  (:use #:cl #:cl-nes))
