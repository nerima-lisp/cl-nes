(in-package #:cl-nes)

(defun %valid-ines-header-p (octets)
  (and (>= (length octets) +ines-header-size+)
       (= (aref octets 0) #x4E)
       (= (aref octets 1) #x45)
       (= (aref octets 2) #x53)
       (= (aref octets 3) #x1A)))

(defun %ines-error (format-control &rest arguments)
  (error 'invalid-rom :reason (apply #'format nil format-control arguments)))

(defun %nes2-rom-bank-count (low-byte msb-nibble kind)
  (when (= msb-nibble #x0F)
    (%ines-error "NES 2.0 exponent-encoded ~A ROM size is unsupported" kind))
  (logior low-byte (ash msb-nibble 8)))

(defun %nes2-ram-size (shift)
  (if (zerop shift) 0 (ash 64 shift)))

(defun load-cartridge (source &key (mapper4-variant :mmc3))
  (let ((octets (cond
                  ((or (stringp source) (pathnamep source))
                   (read-file-octets source))
                  ((vectorp source) (%octet-vector source))
                  (t (%ines-error "Expected a pathname or octet vector")))))
    (unless (%valid-ines-header-p octets)
      (%ines-error "Missing NES\\x1A header"))
    (let* ((flags6 (aref octets 6))
           (flags7 (aref octets 7))
           (nes2-p (= (logand flags7 #x0C) #x08))
           (byte8 (aref octets 8))
           (byte9 (aref octets 9))
           (prg-banks (if nes2-p
                          (%nes2-rom-bank-count
                           (aref octets 4) (ldb (byte 4 0) byte9) "PRG")
                          (aref octets 4)))
           (chr-banks (if nes2-p
                          (%nes2-rom-bank-count
                           (aref octets 5) (ldb (byte 4 4) byte9) "CHR")
                          (aref octets 5)))
           (mapper (logior (ash (logand flags6 #xF0) -4)
                           (logand flags7 #xF0)
                           (if nes2-p
                               (ash (logand byte8 #x0F) 8)
                               0)))
           (trainer-p (logbitp 2 flags6))
           (four-screen-p (logbitp 3 flags6))
           (mirroring (if (logbitp 0 flags6) :vertical :horizontal))
           (battery-backed-p (logbitp 1 flags6))
           (prg-ram-size (if nes2-p
                             (+ (%nes2-ram-size
                                 (ldb (byte 4 0) (aref octets 10)))
                                (%nes2-ram-size
                                 (ldb (byte 4 4) (aref octets 10))))
                             (* (if (zerop byte8) 1 byte8)
                                +prg-ram-bank-size+)))
           (prg-size (* prg-banks +prg-bank-size+))
           (chr-size (* chr-banks +chr-bank-size+))
           (offset (+ +ines-header-size+
                      (if trainer-p +ines-trainer-size+ 0)))
           (required (+ offset prg-size chr-size)))
      (when (zerop prg-banks)
        (%ines-error "ROM has no PRG banks"))
      (unless (<= required (length octets))
        (%ines-error "ROM is truncated: expected at least ~D bytes, got ~D"
                     required (length octets)))
      (%ensure-supported-mapper! mapper)
      (make-cartridge
       :prg-rom (subseq octets offset (+ offset prg-size))
       :chr-rom (unless (zerop chr-banks)
                  (subseq octets (+ offset prg-size) required))
       :mapper mapper
       :mirroring mirroring
       :battery-backed-p battery-backed-p
       :four-screen-p four-screen-p
       :chr-writable-p (zerop chr-banks)
       :prg-ram-size prg-ram-size
       :mapper4-variant mapper4-variant))))
