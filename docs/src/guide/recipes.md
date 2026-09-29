# Recipes

These small examples show how to connect the headless core to an application.

## Read a completed frame

nes-run-frame/k supplies a framebuffer to its continuation:

~~~lisp
(cl-nes:nes-run-frame/k
 nes
 (lambda (framebuffer)
   (write-frame-to-your-backend framebuffer)))
~~~

The framebuffer is owned by the PPU. Copy it if the consumer keeps the data
after the next frame mutates it.

## Set controller buttons

Button constants are bit values and can be combined with logior:

~~~lisp
(let ((buttons (logior cl-nes:+button-a+
                       cl-nes:+button-right+)))
  (cl-nes:controller-set-buttons! controller buttons))
~~~

The controller strobe and serial reads are driven through bus writes and reads
at the normal controller addresses. The first eight reads return the latched
button bits; subsequent reads return the controller's post-shift value.

## Drive controller input at frame boundaries

The `:input-continuation` keyword of `nes-run-frame/k` and `nes-run-frames/k`
is called once per frame, before that frame's first CPU step, with the nes
instance:

~~~lisp
(cl-nes:nes-run-frames/k
 nes 60
 (lambda (framebuffer)
   (write-frame-to-your-backend framebuffer))
 :input-continuation
 (lambda (nes)
   (cl-nes:controller-set-buttons! controller-1 (next-input-frame))))
~~~

This lets a caller update live controller state each frame during a headless
run, without stepping the CPU manually between frames.

## Connect DMC memory reads

An APU that is not connected through make-bus can receive a reader directly:

~~~lisp
(cl-nes:apu-set-memory-reader!
 apu
 (lambda (address)
   (cl-nes:bus-read bus address)))
~~~

The reader must return the byte at the supplied CPU address. An APU connected
to a bus receives this connection during bus construction.

## Select a mapper 4 revision

Choose the reload behavior when constructing or loading a mapper 4 cartridge;
`:mmc6` and `:mmc3-alt` select the MMC6-compatible behavior:

~~~lisp
(let ((cartridge
        (cl-nes:load-cartridge "test.nes"
                               :mapper4-variant :mmc6)))
  (cl-nes:nes-load-cartridge! nes cartridge))
~~~

Use :mmc3 for the default behavior. Both :mmc6 and :mmc3-alt enable the
zero-counter reload suppression behavior.

## Produce PPM output

The command-line wrapper handles the framebuffer-to-PPM conversion:

~~~sh
sbcl --script run-nes.lisp game.nes 10 frame
~~~

It writes frame-0001.ppm through frame-0010.ppm using the standard 64-entry
NES palette.

Library callers can use the same formatters directly. `nes-framebuffer-rgb-octets`
returns packed RGB data, and `nes-write-ppm` writes a framebuffer to a binary
P6 image:

~~~lisp
(cl-nes:nes-write-ppm "frame.ppm" framebuffer)
~~~

To save audio, create one reusable buffer and pass it with
`:audio-buffer`/`:audio-continuation` to `nes-run-frames/k`. The continuation
receives a full single-float buffer in `[-1,1]`; pass copied buffers to
`nes-write-wav` when a file is desired. The optional `:sample-rate` keyword
controls the output rate and defaults to 44100 Hz.
