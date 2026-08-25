;;; This form comes first, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current.
(in-package #:asdf-user)

(defsystem "cl-nes"
  :description "A headless Nintendo Entertainment System core."
  :long-description "A headless, cycle-driven Nintendo Entertainment System
core supporting iNES cartridges, the supported subset of NES 2.0, mappers 0,
1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28, and 34, and headless CPU, PPU,
controller, and APU execution. Its only runtime dependency is the
nerima-lisp cl-host-kit toolkit, used for cartridge ROM file reads."
  :author "nerima-lisp"
  :maintainer "nerima-lisp"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-nes"
  :bug-tracker "https://github.com/nerima-lisp/cl-nes/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-nes.git")
  ;; cl-host-kit (L1, depth 0): read-file-octets for cartridge ROM loading.
  :depends-on ("cl-host-kit")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "conditions")
   (:file "macros")
   (:file "apu-data")
   (:file "apu-state")
   (:file "apu-construction")
   (:file "cartridge-state")
   (:file "cartridge-state-constructors")
   (:file "cartridge-state-forwarders")
   (:file "cartridge-validation")
   (:file "cartridge-data")
   (:file "cartridge-reset")
   (:file "cartridge-format")
   (:file "cartridge-mapper1")
   (:file "cartridge-mapper22-28")
   (:file "cartridge-mapper4")
   (:file "cartridge-mapper4-control")
   (:file "cartridge-mapper5")
   (:file "cartridge-mapper5-expansion")
   (:file "cartridge-mapper9-10")
   (:file "cartridge-memory")
   (:file "cartridge-memory-accessors")
   (:file "cartridge-memory-bus")
   (:file "controller-state")
   (:file "controller")
   (:file "apu")
   (:file "apu-lifecycle")
   (:file "apu-envelopes")
   (:file "apu-timers")
   (:file "apu-frame")
   (:file "apu-timing")
   (:file "apu-status")
   (:file "apu-registers")
   (:file "apu-output")
   (:file "ppu-state")
   (:file "ppu")
   (:file "ppu-memory")
   (:file "ppu-registers")
   (:file "ppu-rendering")
   (:file "ppu-timing")
   (:file "bus-state")
   (:file "bus")
   (:file "cpu-state")
   (:file "cpu")
   (:file "cpu-addressing")
   (:file "cpu-alu")
   (:file "cpu-control")
   (:file "cpu-opcodes-00-7f")
   (:file "cpu-opcodes-80-ff")
   (:file "cpu-instructions")
   (:file "nes-state")
   (:file "nes")
   (:file "nes-timing")
   (:file "nes-execution")
   (:file "nes-output"))
  :in-order-to ((test-op (test-op "cl-nes/test"))))

(defsystem "cl-nes/test"
  :description "cl-nes tests driven by cl-weave."
  :author "nerima-lisp"
  :maintainer "nerima-lisp"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-nes"
  :bug-tracker "https://github.com/nerima-lisp/cl-nes/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-nes.git")
  :depends-on ("cl-nes" "cl-weave")
  :pathname "t"
  :serial t
  :components
    ((:file "package")
     (:file "fixtures-runtime-core")
     (:file "fixtures-cpu-core")
     (:file "fixtures-cartridge-core")
     (:file "fixtures-cartridge-mappers")
     (:file "fixtures-cartridge-mmc5")
     (:file "fixtures-apu-core")
     (:file "fixtures-apu-pulse")
     (:file "fixtures-apu-triangle")
     (:file "fixtures-apu-noise")
     (:file "fixtures-apu-dmc")
     (:file "fixtures-apu-frame")
     (:file "properties-controller")
     (:file "properties-memory")
     (:file "bus-contracts")
    (:file "edge-case-fixtures")
    (:file "edge-loader-input-boundaries")
    (:file "edge-loader-metadata-boundaries")
    (:file "edge-condition-reports")
    (:file "edge-controller-boundaries")
    (:file "edge-apu-register-boundaries")
    (:file "edge-apu-runtime-boundaries")
     (:file "cartridge-contract-fixtures")
     (:file "cartridge-rom-size-contracts")
     (:file "cartridge-constructor-contracts")
     (:file "cartridge-mapper28-construction-contracts")
     (:file "cartridge-mapper5-construction-contracts")
     (:file "cartridge-discrete-mapper-contracts")
     (:file "cartridge-mmc3-banking-contracts")
     (:file "cartridge-mmc3-control-contracts")
     (:file "apu-register-io-contracts")
     (:file "apu-mixer-contracts")
     (:file "apu-envelope-sweep-contracts")
     (:file "apu-timer-contracts")
     (:file "apu-dmc-timing-contracts")
     (:file "apu-channel-frame-contracts")
     (:file "apu-frame-sequencer-contracts")
    (:file "cpu-opcode-fixtures")
    (:file "cpu-opcodes-00-1f")
    (:file "cpu-opcodes-20-3f")
    (:file "cpu-opcodes-40-5f")
    (:file "cpu-opcodes-60-7f")
    (:file "cpu-opcodes-80-9f")
    (:file "cpu-opcodes-a0-bf")
    (:file "cpu-opcodes-c0-df")
    (:file "cpu-opcodes-e0-ff")
    (:file "cpu-transition-fixtures")
     (:file "cpu-state-transitions")
     (:file "cpu-hardware-interrupt-transitions")
     (:file "cpu-flag-transitions")
     (:file "cpu-addressing-transitions")
     (:file "nes-transitions")
     (:file "ppu-transition-fixtures")
     (:file "ppu-register-memory-transitions")
     (:file "ppu-nametable-memory-transitions")
     (:file "ppu-mmc5-memory-transitions")
     (:file "ppu-background-rendering-transitions")
     (:file "ppu-sprite-rendering-transitions")
     (:file "ppu-timing-transitions")
     (:file "bus-routing-transitions")
     (:file "bus-memory-transitions")
               (:file "public-api-cartridge-core")
               (:file "public-api-nes-runtime")
               (:file "public-api-apu-core")
               (:file "public-api-mmc5-banking-registers")
               (:file "public-api-mmc5-control-registers")
               (:file "public-api-mmc5-bank-mapping")
               (:file "public-api-mmc5-nametable-mapping")
               (:file "coverage-cartridge-default-contracts")
               (:file "coverage-cartridge-mmc2-mmc4-contracts")
               (:file "coverage-apu-register-contracts")
               (:file "coverage-apu-dmc-contracts")
     (:file "coverage-mapper-contracts")
     (:file "coverage-cpu-illegal-contracts")
     (:file "coverage-cpu-flag-contracts")
     (:file "coverage-cartridge-mmc1-contracts")
     (:file "coverage-cartridge-discrete-banking-contracts")
     (:file "coverage-cartridge-vrc2-action53-contracts")
     (:file "coverage-cartridge-prg-ram-contracts")
     (:file "coverage-cpu-contracts")
     (:file "coverage-ppu-memory-contracts")
     (:file "coverage-ppu-mapper-contracts")
     (:file "coverage-ppu-render-gate-contracts")
     (:file "coverage-ppu-background-pixel-contracts")
     (:file "coverage-ppu-sprite-visibility-contracts")
     (:file "coverage-ppu-sprite-priority-contracts")
     (:file "coverage-ppu-frame-contracts")
     (:file "coverage-loaders")
     (:file "coverage-nes-timing")
     (:file "coverage-ppu-render-runtime")
     (:file "coverage-ppu-decay-runtime")
     (:file "coverage-ppu-nmi-mask-runtime")
     (:file "coverage-nes-bus-runtime")
     (:file "coverage-nes-lifecycle-surface")
     (:file "coverage-nes-step-runtime")
     (:file "coverage-nes-irq-runtime")
     (:file "coverage-nes-nmi-runtime")
     (:file "output-contracts"))
  :perform
  (test-op (operation component)
    (declare (ignore operation))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter :spec
                              :pass-with-no-tests nil)
      (error "cl-nes cl-weave test suite failed."))))

;;; Third system, per PERFORMANCE_STANDARD.md: benchmarks are not folded into
;;; cl-nes/test. run-benchmarks.lisp is the entry point `apps.bench` in
;;; flake.nix drives.
(defsystem "cl-nes/benchmark"
  :description "Benchmarks for cl-nes."
  :author "nerima-lisp"
  :maintainer "nerima-lisp"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-nes"
  :bug-tracker "https://github.com/nerima-lisp/cl-nes/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-nes.git")
  :depends-on ("cl-nes")
  :pathname "benchmark"
  :serial t
  :components ((:file "run-benchmarks")))
