(in-package #:cl-nes)

(define-constant +nes-savestate-magic+ #(67 76 78 83))
(define-constant +nes-savestate-version+ 1)

(defun %savestate-append (output octets)
  (dotimes (index (length octets))
    (vector-push-extend (aref octets index) output)))

(defun %savestate-write-section (state-writer state output)
  (let ((section (funcall state-writer state)))
    (%state-write-u32 (length section) output)
    (%savestate-append output section)))

(defun %savestate-read-section (reader input position)
  (multiple-value-bind (length position) (%state-read-u32 input position)
    (let ((end (+ position length)))
      (when (> end (length input))
        (error 'invalid-savestate :reason :truncated))
      (multiple-value-bind (state state-position)
          (funcall reader input position)
        (unless (= state-position end)
          (error 'invalid-savestate :reason :invalid-section))
        (values state end)))))

(defun %savestate-load-section (loader state input position)
  (multiple-value-bind (length position) (%state-read-u32 input position)
    (let ((end (+ position length)))
      (when (> end (length input))
        (error 'invalid-savestate :reason :truncated))
      (funcall loader state (subseq input position end))
      end)))

(defun nes-save-state (nes)
  "Return a deterministic octet vector containing the complete machine state."
  (let ((output (make-array 0 :adjustable t :fill-pointer 0
                            :element-type '(unsigned-byte 8))))
    (%savestate-append output +nes-savestate-magic+)
    (%state-write-u32 +nes-savestate-version+ output)
    (%savestate-write-section #'cpu-state-save (nes-cpu nes) output)
    (%savestate-write-section #'ppu-state-save (nes-ppu nes) output)
    (%savestate-write-section #'apu-state-save (nes-apu nes) output)
    (%savestate-write-section #'bus-state-save (nes-bus nes) output)
    (%savestate-write-section #'controller-state-save
                              (bus-controller-1 (nes-bus nes)) output)
    (%savestate-write-section #'controller-state-save
                              (bus-controller-2 (nes-bus nes)) output)
    (%state-write-value (bus-cartridge (nes-bus nes)) output)
    (%savestate-write-section #'nes-state-save nes output)
    output))

(defun %savestate-check-header (octets)
  (when (< (length octets) 8)
    (error 'invalid-savestate :reason :truncated))
  (dotimes (index 4)
    (unless (= (aref octets index) (aref +nes-savestate-magic+ index))
      (error 'invalid-savestate :reason :bad-magic)))
  (multiple-value-bind (version position) (%state-read-u32 octets 4)
    (declare (ignore position))
    (unless (= version +nes-savestate-version+)
      (error 'invalid-savestate :reason :unsupported-version))))

(defun nes-load-state (nes octets)
  "Restore NES from OCTETS and return NES.

The cartridge in NES is replaced only by its serialized mutable vector; the
bus, PPU, APU, and controller object identities remain stable."
  (unless (typep octets '(vector (unsigned-byte 8)))
    (error 'invalid-savestate :reason :not-octets))
  (%savestate-check-header octets)
  (let ((position 8))
    (setf position (%savestate-load-section #'cpu-state-load
                                             (nes-cpu nes) octets position)
          position (%savestate-load-section #'ppu-state-load
                                             (nes-ppu nes) octets position)
          position (%savestate-load-section #'apu-state-load
                                             (nes-apu nes) octets position)
          position (%savestate-load-section #'bus-state-load
                                             (nes-bus nes) octets position)
          position (%savestate-load-section #'controller-state-load
                                             (bus-controller-1 (nes-bus nes))
                                             octets position)
          position (%savestate-load-section #'controller-state-load
                                             (bus-controller-2 (nes-bus nes))
                                             octets position))
    (multiple-value-bind (cartridge position-next)
        (%state-read-value octets position)
      (unless (or (null cartridge) (typep cartridge 'simple-vector))
        (error 'invalid-savestate :reason :invalid-cartridge))
      (setf position position-next)
      (let ((current (bus-cartridge (nes-bus nes))))
        (if (and current cartridge)
            (replace current cartridge)
            (setf (bus-cartridge (nes-bus nes)) cartridge)))
      (setf (ppu-cartridge (nes-ppu nes)) (bus-cartridge (nes-bus nes)))
      (setf position (%savestate-load-section #'nes-state-load nes octets position))
      (unless (= position (length octets))
        (error 'invalid-savestate :reason :trailing-data))
      nes)))
