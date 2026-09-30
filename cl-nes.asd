(in-package #:asdf-user)

(defsystem "cl-nes"
  :description "A headless Nintendo Entertainment System core."
  :author "nerima-lisp"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("cl-host-kit")
  :pathname "src"
  :components
  ((:module "core"
    :components ((:file "package") (:file "conditions") (:file "macros")))
   (:module "cartridge"
    :depends-on ("core")
    :components
     ((:file "cartridge-state")
     (:file "cartridge-battery")
     (:file "cartridge-state-constructors")
     (:file "cartridge-state-forwarders")
     (:file "cartridge-validation")
     (:file "cartridge-data")
     (:file "cartridge-reset")
     (:file "cartridge-format")
     (:module "mappers"
      :components ((:file "cartridge-mapper1")
                   (:file "cartridge-mapper22-28")
                   (:file "cartridge-mapper4")
                   (:file "cartridge-mapper4-control")
                   (:file "cartridge-mapper5")
                   (:file "cartridge-mapper5-expansion")
                   (:file "cartridge-mapper9-10")
                   (:file "cartridge-mapper69-79")))
     (:file "cartridge-memory")
     (:file "cartridge-memory-accessors")
     (:file "cartridge-memory-bus")))
   (:module "apu"
    :depends-on ("core")
    :components
    ((:file "apu-data") (:file "apu-state") (:file "apu-construction")
     (:file "apu") (:file "apu-envelopes")
     (:file "apu-timers") (:file "apu-frame") (:file "apu-timing")
     (:file "apu-status") (:file "apu-registers") (:file "apu-output")))
   (:module "ppu"
    :depends-on ("core" "cartridge")
    :components
    ((:file "ppu-state") (:file "ppu") (:file "ppu-memory")
     (:file "ppu-registers") (:file "ppu-rendering") (:file "ppu-timing")))
   (:module "cpu"
    :depends-on ("core")
    :components
    ((:file "cpu-state") (:file "cpu") (:file "cpu-addressing")
     (:file "cpu-alu") (:file "cpu-control") (:file "opcode-macros")
     (:file "cpu-opcodes-00-7f") (:file "cpu-opcodes-80-ff")
     (:file "cpu-instructions")))
   (:module "system"
    :depends-on ("core" "cartridge" "apu" "ppu" "cpu")
    :components
    ((:file "controller-state") (:file "controller") (:file "timing-macros")
     (:file "bus-state")
     (:file "bus") (:file "nes-state") (:file "nes")
     (:file "nes-timing") (:file "nes-audio-data")
     (:file "nes-savestate")
     (:file "nes-execution") (:file "nes-output")
     (:file "nes-protocol"))))
  :in-order-to ((test-op (test-op "cl-nes/test"))))

(defsystem "cl-nes/test"
  :description "cl-nes tests driven by cl-weave."
  :author "nerima-lisp"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("cl-nes" "cl-weave")
  :pathname "t"
  :components
  ((:module "core"
    :components ((:file "package")
                 (:file "coverage-loaders")
                 (:file "edge-case-fixtures")
                 (:file "fixtures-runtime-core")))
   (:module "cartridge"
    :depends-on ("core")
    :components
    ((:file "fixtures-cartridge-core")
     (:file "fixtures-cartridge-mappers")
     (:file "fixtures-cartridge-mmc5")
     (:file "cartridge-contract-fixtures")
     (:file "cartridge-rom-size-contracts")
     (:file "cartridge-constructor-contracts")
     (:file "cartridge-mapper28-construction-contracts")
     (:file "cartridge-mapper5-construction-contracts")
     (:file "cartridge-discrete-mapper-contracts")
     (:file "cartridge-mmc3-banking-contracts")
     (:file "cartridge-mmc3-control-contracts")
     (:file "coverage-cartridge-default-contracts")
     (:file "coverage-cartridge-mmc2-mmc4-contracts")
     (:file "coverage-mapper-contracts")
     (:file "coverage-cartridge-mmc1-contracts")
     (:file "coverage-cartridge-discrete-banking-contracts")
     (:file "coverage-cartridge-vrc2-action53-contracts")
     (:file "coverage-cartridge-prg-ram-contracts")
     (:file "cartridge-p4-contracts")
     (:file "cartridge-mapper69-contracts")
     (:file "cartridge-regression-contracts")
     (:file "cartridge-mapper69-timing-contracts")
     (:file "public-api-cartridge-core")
     (:file "public-api-mmc5-banking-registers")
     (:file "public-api-mmc5-control-registers")
     (:file "public-api-mmc5-bank-mapping")
     (:file "public-api-mmc5-nametable-mapping")))
   (:module "apu"
    :depends-on ("core")
    :components
    ((:file "fixtures-apu-core") (:file "fixtures-apu-pulse")
     (:file "fixtures-apu-triangle") (:file "fixtures-apu-noise")
     (:file "fixtures-apu-dmc") (:file "fixtures-apu-frame")
     (:file "apu-register-io-contracts") (:file "apu-mixer-contracts")
     (:file "apu-envelope-sweep-contracts") (:file "apu-timer-contracts")
     (:file "apu-dmc-timing-contracts") (:file "apu-channel-frame-contracts")
     (:file "apu-frame-sequencer-contracts") (:file "coverage-apu-register-contracts")
     (:file "coverage-apu-dmc-contracts") (:file "edge-apu-register-boundaries")
     (:file "edge-apu-runtime-boundaries") (:file "public-api-apu-core")))
   (:module "cpu"
    :depends-on ("core")
    :components
    ((:file "fixtures-cpu-core") (:file "cpu-opcode-fixtures")
     (:file "cpu-transition-fixtures") (:file "cpu-state-transitions")
     (:file "cpu-hardware-interrupt-transitions") (:file "cpu-flag-transitions")
     (:file "cpu-addressing-transitions") (:file "cpu-opcodes-00-1f")
     (:file "cpu-opcodes-20-3f") (:file "cpu-opcodes-40-5f")
     (:file "cpu-opcodes-60-7f") (:file "cpu-opcodes-80-9f")
     (:file "cpu-opcodes-a0-bf") (:file "cpu-opcodes-c0-df")
     (:file "cpu-opcodes-e0-ff") (:file "coverage-cpu-contracts")
     (:file "coverage-cpu-illegal-contracts") (:file "coverage-cpu-flag-contracts")))
   (:module "ppu"
    :depends-on ("core" "cartridge")
    :components
    ((:file "ppu-transition-fixtures") (:file "ppu-register-memory-transitions")
     (:file "ppu-nametable-memory-transitions") (:file "ppu-mmc5-memory-transitions")
     (:file "ppu-background-rendering-transitions") (:file "ppu-sprite-rendering-transitions")
     (:file "ppu-timing-transitions") (:file "coverage-ppu-memory-contracts")
     (:file "coverage-ppu-mapper-contracts") (:file "coverage-ppu-render-gate-contracts")
     (:file "coverage-ppu-background-pixel-contracts") (:file "coverage-ppu-sprite-visibility-contracts")
     (:file "coverage-ppu-sprite-priority-contracts") (:file "coverage-ppu-frame-contracts")
     (:file "coverage-ppu-render-runtime") (:file "coverage-ppu-decay-runtime")
     (:file "coverage-ppu-nmi-mask-runtime")))
   (:module "system"
    :depends-on ("core" "cartridge" "apu" "cpu" "ppu")
    :components
     ((:file "properties-controller") (:file "properties-memory")
     (:file "protocol-contracts")
     (:file "bus-contracts") (:file "bus-routing-transitions")
     (:file "cartridge-cpu-cycle-contracts")
     (:file "bus-memory-transitions") (:file "edge-condition-reports")
     (:file "allocation-complexity")
     (:file "edge-controller-boundaries") (:file "edge-loader-input-boundaries")
     (:file "edge-loader-metadata-boundaries") (:file "nes-transitions")
     (:file "coverage-nes-timing") (:file "coverage-nes-bus-runtime")
     (:file "coverage-nes-lifecycle-surface") (:file "coverage-nes-step-runtime")
     (:file "coverage-nes-irq-runtime") (:file "mapper69-irq-runtime")
     (:file "coverage-nes-nmi-runtime")
     (:file "public-api-nes-runtime") (:file "savestate-contracts")
     (:file "output-contracts"))))
  :perform
  (test-op (operation component)
    (declare (ignore operation))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter :spec
                              :pass-with-no-tests nil)
      (error "cl-nes cl-weave test suite failed."))))

(defsystem "cl-nes/benchmark"
  :description "Benchmarks for cl-nes."
  :depends-on ("cl-nes")
  :pathname "benchmark"
  :components ((:file "run-benchmarks")))

(defsystem "cl-nes/frontend"
  :description "Interactive GLFW/OpenGL/SDL2 frontend for cl-nes."
  :author "nerima-lisp"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("cl-nes" "cl-glfw3-kit" "cl-cli")
  :pathname "frontend"
  :serial t
  :components
  ((:file "package")
   (:file "input")
   (:file "video")
   (:file "audio")
   (:file "persistence")
   (:file "play")
   (:file "protocol")
   (:file "render")
   (:file "rom-test")
   (:file "cli"))
  :build-operation "program-op"
  :build-pathname "cl-nes"
  :entry-point "cl-nes/frontend:image-entry-point")

(defsystem "cl-nes/frontend/test"
  :description "Headless tests for the cl-nes frontend's pure components."
  :author "nerima-lisp"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("cl-nes/frontend" "cl-weave")
  :pathname "frontend/test"
  :serial t
  :components ((:file "package")
               (:file "frontend-contracts"))
  :perform
  (test-op (operation component)
    (declare (ignore operation))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter :spec
                              :pass-with-no-tests nil)
      (error "cl-nes frontend test suite failed."))))

(defsystem "cl-nes/rom-suite"
  :description "Table-driven test-ROM and golden-trace harness for cl-nes."
  :author "nerima-lisp"
  :maintainer "nerima-lisp"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("cl-nes" "cl-weave")
  :pathname "t/rom-suite"
  :serial t
  :components ((:file "package")
               (:file "protocols")
               (:file "suite")
               (:file "nestest"))
  :perform
  (test-op (operation component)
    (declare (ignore operation))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter :spec
                              :pass-with-no-tests nil)
      (error "cl-nes ROM contract tests failed."))))
