(in-package #:asdf-user)

(defsystem "cl-nes"
  :description "A headless Nintendo Entertainment System core."
  :author "nerima-lisp"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-nes"
  :source-control (:git "https://github.com/nerima-lisp/cl-nes.git")
  :serial t
  :components
  ((:file "src/package")
   (:file "src/conditions")
   (:file "src/macros")
   (:file "src/apu-data")
   (:file "src/apu-state")
   (:file "src/apu-construction")
   (:file "src/cartridge-state")
   (:file "src/cartridge-data")
   (:file "src/cartridge-format")
   (:file "src/cartridge-mapper1")
   (:file "src/cartridge-mapper22-28")
   (:file "src/cartridge-mapper4")
   (:file "src/cartridge-mapper5")
   (:file "src/cartridge-memory")
   (:file "src/controller-state")
   (:file "src/controller")
   (:file "src/apu")
   (:file "src/apu-lifecycle")
   (:file "src/apu-timing")
   (:file "src/apu-registers")
   (:file "src/ppu-state")
   (:file "src/ppu")
   (:file "src/ppu-rendering")
   (:file "src/ppu-timing")
   (:file "src/bus-state")
   (:file "src/bus")
   (:file "src/cpu-state")
   (:file "src/cpu")
   (:file "src/cpu-instructions")
   (:file "src/nes-state")
   (:file "src/nes")
   (:file "src/nes-execution"))
  :in-order-to ((test-op (test-op "cl-nes/test"))))

(defsystem "cl-nes/test"
  :description "cl-nes tests driven by cl-weave."
  :depends-on ("cl-nes" "cl-weave")
  :pathname "t"
  :serial t
  :components
    ((:file "package")
     (:file "legacy-runner")
     (:file "legacy-support")
     (:file "legacy-cartridge-core")
     (:file "legacy-cartridge-advanced")
     (:file "legacy-devices")
     (:file "legacy-cpu")
     (:file "legacy-apu")
     (:file "fixtures")
     (:file "properties")
     (:file "edge-cases")
     (:file "cartridge-contracts")
     (:file "apu-contracts")
     (:file "cpu-opcodes")
     (:file "state-transitions")
     (:file "public-api")
     (:file "coverage-contracts")
     (:file "legacy-regression"))
  :perform
  (test-op (operation component)
    (declare (ignore operation))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter :spec
                              :pass-with-no-tests nil)
      (error "cl-nes cl-weave test suite failed."))))
