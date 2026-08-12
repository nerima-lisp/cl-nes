(in-package #:cl-nes)

;; Console reset preserves the register latches that are distinct from the
;; ordinary channel state reset.  Keeping this boundary separate from the
;; per-cycle timing code makes the APU lifecycle easier to audit.

(defun apu-console-reset! (apu)
  "Reset console-visible APU state while retaining the last $4017 mode.

Power-up and a subsequent RESET differ on the NES: RESET clears the frame
counter's IRQ inhibit state but repeats the previously selected four-/five-
step mode.  The channel register values remain latched across RESET, while
the ordinary APU reset clears the channel's active state."
  (%apu-console-reset! apu))
