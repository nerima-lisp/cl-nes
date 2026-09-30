(in-package #:cl-nes/frontend)

(defun nes-button-mask (&rest buttons)
  "Return the ORed NES controller mask for BUTTONS keyword names."
  (reduce #'logior buttons :key (lambda (button)
                                  (ecase button
                                    (:a cl-nes:+button-a+)
                                    (:b cl-nes:+button-b+)
                                    (:select cl-nes:+button-select+)
                                    (:start cl-nes:+button-start+)
                                    (:up cl-nes:+button-up+)
                                    (:down cl-nes:+button-down+)
                                    (:left cl-nes:+button-left+)
                                    (:right cl-nes:+button-right+)))
          :initial-value 0))

(defun keyboard-button-mask (window &key (key #'cl-glfw3-kit:key-pressed-p))
  "Read the standard NES keyboard layout from WINDOW.
Z/X are B/A, Shift/Enter are Select/Start, and arrows are the D-pad."
  (flet ((held-p (name) (funcall key window name)))
    (logior (if (held-p :z) cl-nes:+button-b+ 0)
            (if (held-p :x) cl-nes:+button-a+ 0)
            (if (or (held-p :left-shift) (held-p :right-shift))
                cl-nes:+button-select+ 0)
            (if (or (held-p :enter) (held-p :kp-enter))
                cl-nes:+button-start+ 0)
            (if (held-p :up) cl-nes:+button-up+ 0)
            (if (held-p :down) cl-nes:+button-down+ 0)
            (if (held-p :left) cl-nes:+button-left+ 0)
            (if (held-p :right) cl-nes:+button-right+ 0))))

(defun gamepad-button-mask (buttons &key (a 0) (b 1) (select 6) (start 7)
                                           (up 11) (down 13) (left 14) (right 12))
  "Map a GLFW joystick button vector to the NES layout.
BUTTONS may be any sequence of nonzero button values."
  (flet ((pressed-p (index)
           (and (< -1 index (length buttons))
                (let ((value (elt buttons index)))
                  (if (numberp value) (not (zerop value)) value)))))
    (logior (if (pressed-p a) cl-nes:+button-a+ 0)
            (if (pressed-p b) cl-nes:+button-b+ 0)
            (if (pressed-p select) cl-nes:+button-select+ 0)
            (if (pressed-p start) cl-nes:+button-start+ 0)
            (if (pressed-p up) cl-nes:+button-up+ 0)
            (if (pressed-p down) cl-nes:+button-down+ 0)
            (if (pressed-p left) cl-nes:+button-left+ 0)
            (if (pressed-p right) cl-nes:+button-right+ 0))))

(defun glfw-gamepad-mask (joystick-id)
  "Read one GLFW gamepad and map its digital buttons to an NES pad."
  (if (and (cl-glfw3-kit:joystick-present-p joystick-id)
           (cl-glfw3-kit:joystick-gamepad-p joystick-id))
      (let ((state (cl-glfw3-kit:gamepad-state joystick-id)))
        (if state
            (gamepad-button-mask
             (cl-glfw3-kit:glfw-gamepad-state-buttons state))
            0))
      0))
