(in-package #:cl-user)
;; Explicit entry point that flake.nix apps.bench runs; loading the ASDF system alone does not run the suite.

(require :asdf)
(load (merge-pathnames "../cl-nes.asd" *load-truename*))
(asdf:load-system "cl-nes/benchmark")
(run-benchmarks)