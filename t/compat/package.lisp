(defpackage #:cl-nes/compat
  (:use #:cl)
  (:import-from #:cl-nes
                #:cartridge-mapper
                #:cpu-cycles
                #:cpu-pc
                #:load-cartridge
                #:make-nes
                #:make-nes-audio-buffer
                #:nes-audio-buffer-samples
                #:nes-audio-buffer-count
                #:nes-cpu
                #:nes-run-frame/k
                #:nes-run-frames/k
                #:nes-framebuffer-rgb-octets
                #:nes-write-ppm
                #:ppu-framebuffer)
  (:export #:compat-main))
