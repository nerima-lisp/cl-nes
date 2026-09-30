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

## Use the frontend CLI

The frontend executable uses subcommands. Check its version with:

~~~sh
cl-nes --version
~~~

To play a ROM interactively:

~~~sh
cl-nes play game.nes
~~~

The `play` command accepts `--state-directory PATH` for battery-backed saves
and save states, and `--scale INTEGER` for the logical viewport scale. If the
state directory is omitted, the frontend uses the XDG data directory under
`cl-nes/`, with a separate content-addressed directory for each ROM.

While playing, number keys `0` through `9` select a save-state slot. F5 saves
the selected slot and F7 loads it. P pauses and R resets. Z/X map to B/A,
Shift/Enter map to Select/Start, and the arrow keys map to the D-pad. If no
gamepad is connected, the gamepad path contributes no input.

To render frames without
opening the interactive frontend:

~~~sh
cl-nes render game.nes --frames 3 --prefix capture --format png
~~~

For a bounded ROM diagnostic:

~~~sh
cl-nes rom-test game.nes --max-frames 1000 --mapper4-variant mmc3
~~~

The diagnostic reports whether the ROM protocol passed and includes its frame,
status, signature, and text fields. The CLI does not download ROMs; use only a
legally obtained test corpus.
