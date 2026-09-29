(in-package #:cl-nes)

(defun %valid-ines-header-p (octets)
  (and (>= (length octets) +ines-header-size+)
       (= (aref octets 0) #x4E)
       (= (aref octets 1) #x45)
       (= (aref octets 2) #x53)
       (= (aref octets 3) #x1A)))

(defun %ines-error (format-control &rest arguments)
  (error 'invalid-rom :reason (apply #'format nil format-control arguments)))

(defun %nes2-rom-size (low-byte msb-nibble unit kind)
  (if (= msb-nibble #x0F)
      (let ((exponent (ldb (byte 6 2) low-byte))
            (multiplier (ldb (byte 2 0) low-byte)))
        (* (1+ (* 2 multiplier)) (ash 1 exponent)))
      (* (logior low-byte (ash msb-nibble 8)) unit)))

(defun %nes2-ram-size (shift)
  (if (zerop shift) 0 (ash 64 shift)))

(defun load-cartridge (source &key (mapper4-variant nil mapper4-variant-p))
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
           (submapper (if nes2-p (ldb (byte 4 4) byte8) 0))
           (prg-size (if nes2-p
                         (%nes2-rom-size (aref octets 4) (ldb (byte 4 0) byte9)
                                         +prg-bank-size+ "PRG")
                         (* (aref octets 4) +prg-bank-size+)))
           (chr-size (if nes2-p
                         (%nes2-rom-size (aref octets 5) (ldb (byte 4 4) byte9)
                                         +chr-bank-size+ "CHR")
                         (* (aref octets 5) +chr-bank-size+)))
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
           (prg-banks (floor prg-size +prg-bank-size+))
           (chr-banks (floor chr-size +chr-bank-size+))
           (effective-mapper4-variant
             (if mapper4-variant-p
                 mapper4-variant
                 (case submapper (1 :mmc6) (2 :mmc3-alt) (otherwise :mmc3))))
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
       :submapper submapper
       :bus-conflict-p (and (member mapper '(2 3 7 11))
                            (zerop submapper))
       :mirroring mirroring
       :battery-backed-p battery-backed-p
       :four-screen-p four-screen-p
       :chr-writable-p (zerop chr-banks)
       :prg-ram-size prg-ram-size
       :mapper4-variant effective-mapper4-variant))))
