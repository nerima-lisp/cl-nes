(in-package #:cl-user)

(defpackage #:cl-nes/rom-suite
  (:use #:cl)
  (:import-from #:cl-weave
                #:describe-each
                #:it
                #:it-each)
  (:export
   #:*rom-contract-data*
   #:*accuracy-coin-contract*
   #:run-rom-suite
   #:run-nestest-trace
   #:rom-suite-main))
