(in-package #:cl-nes/frontend)

#+sbcl
(progn
  (sb-alien:define-alien-routine ("glfwJoystickPresent" %glfw-joystick-present)
      sb-alien:int (jid sb-alien:int))
  (sb-alien:define-alien-routine ("glfwGetJoystickButtons" %glfw-get-joystick-buttons)
      (* sb-alien:unsigned-char) (jid sb-alien:int) (count (* sb-alien:int))))

(defun nes-button-mask (&rest buttons)
  "Return the ORed NES controller mask for BUTTONS keyword names."
  (reduce #'logior buttons :key (lambda (button)
                                  (ecase button
                                    (:a +button-a-mask+)
                                    (:b +button-b-mask+)
                                    (:select +button-select-mask+)
                                    (:start +button-start-mask+)
                                    (:up +button-up-mask+)
                                    (:down +button-down-mask+)
                                    (:left +button-left-mask+)
                                    (:right +button-right-mask+)))
          :initial-value 0))

(defun keyboard-button-mask (window &key (key #'cl-glfw3-kit:key-pressed-p))
  "Read the standard NES keyboard layout from WINDOW.
Z/X are B/A, Shift/Enter are Select/Start, and arrows are the D-pad."
  (flet ((held-p (name) (funcall key window name)))
    (logior (if (held-p :z) +button-b-mask+ 0)
            (if (held-p :x) +button-a-mask+ 0)
            (if (or (held-p :left-shift) (held-p :right-shift))
                +button-select-mask+ 0)
            (if (or (held-p :enter) (held-p :kp-enter))
                +button-start-mask+ 0)
            (if (held-p :up) +button-up-mask+ 0)
            (if (held-p :down) +button-down-mask+ 0)
            (if (held-p :left) +button-left-mask+ 0)
            (if (held-p :right) +button-right-mask+ 0))))

(defun gamepad-button-mask (buttons &key (a 0) (b 1) (select 6) (start 7)
                                           (up 11) (down 13) (left 14) (right 12))
  "Map a GLFW joystick button vector to the NES layout.
BUTTONS may be any sequence of nonzero button values."
  (flet ((pressed-p (index)
           (and (< -1 index (length buttons))
                (let ((value (elt buttons index)))
                  (if (numberp value) (not (zerop value)) value)))))
    (logior (if (pressed-p a) +button-a-mask+ 0)
            (if (pressed-p b) +button-b-mask+ 0)
            (if (pressed-p select) +button-select-mask+ 0)
            (if (pressed-p start) +button-start-mask+ 0)
            (if (pressed-p up) +button-up-mask+ 0)
            (if (pressed-p down) +button-down-mask+ 0)
            (if (pressed-p left) +button-left-mask+ 0)
            (if (pressed-p right) +button-right-mask+ 0))))

(defun glfw-gamepad-mask (joystick-id)
  "Read one GLFW joystick's digital buttons and map it to an NES pad."
  #+sbcl
  (if (zerop (%glfw-joystick-present joystick-id))
      0
      (let ((count (sb-alien:make-alien sb-alien:int)))
        (unwind-protect
             (let ((buttons (%glfw-get-joystick-buttons joystick-id count)))
               (gamepad-button-mask
                (loop for index below (sb-alien:deref count)
                      collect (sb-sys:sap-ref-8 (sb-alien:alien-sap buttons) index))))
          (sb-alien:free-alien count))))
  #-sbcl 0)
