# Getting started

This guide assumes a checkout containing cl-nes and an iNES ROM file.

## Prepare the environment

Enter the pinned development shell:

~~~sh
nix develop
~~~

The core can also be loaded from a standalone SBCL process with ASDF:

~~~sh
sbcl --non-interactive \
  --eval '(require :asdf)' \
  --load cl-nes.asd \
  --eval '(asdf:load-system :cl-nes)' \
  --quit
~~~

## Run a frame from Lisp

Load a cartridge, create the machine, and pass a continuation to
nes-run-frame/k:

~~~lisp
(let* ((cartridge (cl-nes:load-cartridge "game.nes"))
       (nes (cl-nes:make-nes :cartridge cartridge)))
  (cl-nes:nes-run-frame/k
   nes
   (lambda (framebuffer)
     (format t "received ~D framebuffer elements~%"
             (length framebuffer)))))
~~~

The continuation runs when the PPU reaches the next frame boundary. The core
does not choose a windowing or audio library.

## Use the command-line runner

To write one PPM frame:

~~~sh
sbcl --script run-nes.lisp game.nes
~~~

This creates frame-0001.ppm, a 256x240 binary PPM image. The optional
arguments are the frame count and output prefix:

~~~sh
sbcl --script run-nes.lisp game.nes 3 capture
~~~

For ROM diagnostics, run the suite wrapper:

~~~sh
sbcl --script run-rom-suite.lisp game.nes 1000000 mmc3
~~~

The wrapper prints one TSV row containing status, mapper, steps, frames, final
PC, elapsed seconds, checksum, output, error, and ROM path.
