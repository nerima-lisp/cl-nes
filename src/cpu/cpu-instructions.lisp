(in-package #:cl-nes)

(defun %accumulator-rmw-op! (cpu operation)
  (setf (cpu-a cpu) (funcall operation cpu (cpu-a cpu)))
  2)

(defun %dummy-stack-read (cpu bus)
  (bus-read bus (+ #x100 (cpu-sp cpu))))

(defun %brk-op! (cpu bus nmi-poll)
  ;; BRK reads and discards its padding byte before pushing the
  ;; return address.
  (bus-read bus (cpu-pc cpu))
  (setf (cpu-pc cpu) (logand (1+ (cpu-pc cpu)) #xFFFF))
  (%push-word! cpu bus (cpu-pc cpu))
  (%push-byte! cpu bus (%status-for-stack cpu t))
  (%set-flag! cpu +flag-interrupt-disable+ t)
  ;; A pending NMI can hijack BRK after its stack writes but before
  ;; the interrupt vector is fetched. The pushed status still has BRK
  ;; set, as on the 6502.
  (let ((vector-type
          (if (and nmi-poll (funcall nmi-poll))
              :nmi
              :irq)))
    (setf (cpu-pc cpu)
          (if (eq vector-type :nmi)
              (logior (bus-read bus #xFFFA)
                      (ash (bus-read bus #xFFFB) 8))
              (logior (bus-read bus #xFFFE)
                      (ash (bus-read bus #xFFFF) 8)))))
  7)

(defun %php-op! (cpu bus)
  ;; PHP has an internal/dummy read before the stack write.
  (bus-read bus (cpu-pc cpu))
  (%push-byte! cpu bus (%status-for-stack cpu t))
  3)

(defun %jsr-op! (cpu bus)
  ;; JSR fetches the low target byte, performs a dummy stack read,
  ;; pushes the return address, and fetches the high target byte
  ;; last.
  (let* ((low (%fetch-byte cpu bus))
         (return-address (cpu-pc cpu)))
    (%dummy-stack-read cpu bus)
    (%push-byte! cpu bus (ldb (byte 8 8) return-address))
    (%push-byte! cpu bus (ldb (byte 8 0) return-address))
    (setf (cpu-pc cpu)
          (logior low (ash (%fetch-byte cpu bus) 8)))
    6))

(defun %plp-op! (cpu bus)
  ;; PLP has a dummy read from the next instruction byte and a second
  ;; dummy read from the current stack location.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (%restore-status! cpu (%pop-byte! cpu bus))
  4)

(defun %rti-op! (cpu bus)
  ;; RTI's two cycles before pulling the status are dummy reads, one
  ;; from the next instruction and one from the current stack
  ;; location.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (%restore-status! cpu (%pop-byte! cpu bus) nil)
  (setf (cpu-pc cpu) (%pop-word! cpu bus))
  6)

(defun %pha-op! (cpu bus)
  ;; PHA has an internal/dummy read before the stack write.
  (bus-read bus (cpu-pc cpu))
  (%push-byte! cpu bus (cpu-a cpu))
  3)

(defun %interrupt-disable-op! (cpu enabled-p)
  (let ((was-disabled (%flag-set-p cpu +flag-interrupt-disable+)))
    (%set-flag! cpu +flag-interrupt-disable+ enabled-p)
    (if enabled-p
        (unless was-disabled
          (setf (cpu-irq-delay cpu) 1))
        (when was-disabled
          (setf (cpu-irq-delay cpu) 1)))
    2))

(defun %rts-op! (cpu bus)
  ;; RTS performs a next-PC dummy read, a stack dummy read, pulls the
  ;; return address, then reads from the resumed PC.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (setf (cpu-pc cpu)
        (logand (1+ (%pop-word! cpu bus)) #xFFFF))
  (bus-read bus (cpu-pc cpu))
  6)

(defun %pla-op! (cpu bus)
  ;; PLA has the same two dummy reads as PLP.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (setf (cpu-a cpu) (%pop-byte! cpu bus))
  (%update-zn! cpu (cpu-a cpu))
  4)

(defun cpu-step! (cpu bus &optional nmi-poll)
  (if (cpu-stopped-p cpu)
      0
      (let* ((address (cpu-pc cpu))
             (opcode (%fetch-byte cpu bus))
             (_ (setf (cpu-irq-poll-delay cpu) nil))
             (cycles (progn _ (case opcode
                 ((#x00 #x01 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C
                   #x0D #x0E #x0F #x10 #x11 #x13 #x14 #x15 #x16 #x17 #x18 #x19
                   #x1A #x1B #x1C #x1D #x1E #x1F #x20 #x21 #x23 #x24 #x25 #x26
                   #x27 #x28 #x29 #x2A #x2B #x2C #x2D #x2E #x2F #x30 #x31 #x33
                   #x34 #x35 #x36 #x37 #x38 #x39 #x3A #x3B #x3C #x3D #x3E #x3F
                   #x40 #x41 #x43 #x44 #x45 #x46 #x47 #x48 #x49 #x4A #x4B #x4C
                   #x4D #x4E #x4F #x50 #x51 #x53 #x54 #x55 #x56 #x57 #x58 #x59
                   #x5A #x5B #x5C #x5D #x5E #x5F #x60 #x61 #x63 #x64 #x65 #x66
                   #x67 #x68 #x69 #x6A #x6B #x6C #x6D #x6E #x6F #x70 #x71 #x73
                   #x74 #x75 #x76 #x77 #x78 #x79 #x7A #x7B #x7C #x7D #x7E #x7F)
                  (%dispatch-cpu-opcode-00-7f cpu bus opcode nmi-poll))

                 ((#x80 #x81 #x82 #x83 #x84 #x85 #x86 #x87 #x88 #x89 #x8A #x8C #x8D #x8E #x8F
                   #x90 #x91 #x94 #x95 #x96 #x97 #x98 #x99 #x9A #x9C #x9D #x9E
                   #xA0 #xA1 #xA2 #xA3 #xA4 #xA5 #xA6 #xA7 #xA8 #xA9 #xAA #xAB
                   #xAC #xAD #xAE #xAF #xB0 #xB1 #xB3 #xB4 #xB5 #xB6 #xB7 #xB8
                   #xB9 #xBA #xBC #xBD #xBE #xBF #xC0 #xC1 #xC3 #xC4 #xC5 #xC6
                   #xC2 #xC7 #xC8 #xC9 #xCA #xCB #xCC #xCD #xCE #xCF #xD0 #xD1 #xD3
                   #xD4 #xD5 #xD6 #xD7 #xD8 #xD9 #xDA #xDB #xDC #xDD #xDE #xDF #xE0 #xE1 #xE3
                   #xE2 #xE4 #xE5 #xE6 #xE7 #xE8 #xE9 #xEA #xEB #xEC #xED #xEE #xEF
                   #xF0 #xF1 #xF3 #xF4 #xF5 #xF6 #xF7 #xF8 #xF9 #xFA #xFB #xFC #xFD #xFE #xFF)
                  (%dispatch-cpu-opcode-80-ff cpu bus opcode))
                 (otherwise
                  (error 'illegal-opcode
                         :opcode opcode
                         :address address))))))
        (incf (cpu-cycles cpu) cycles)
        cycles)))
