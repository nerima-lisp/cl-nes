(in-package #:cl-nes)

(defun %read-rom-file (pathname)
  (with-open-file (stream pathname :direction :input
                                  :element-type '(unsigned-byte 8))
    (let ((result (make-array (file-length stream)
                              :element-type '(unsigned-byte 8))))
      (read-sequence result stream)
      result)))

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

(defun %coerce-cartridge-source (source)
  (cond
    ((or (stringp source) (pathnamep source))
     (%read-rom-file source))
    ((vectorp source) (%octet-vector source))
    (t (%ines-error "Expected a pathname or octet vector"))))

(defun %decode-ines-geometry (octets)
  (let* ((flags6 (aref octets 6))
         (flags7 (aref octets 7))
         (nes2-p (= (logand flags7 #x0C) #x08))
         (byte8 (aref octets 8))
         (byte9 (aref octets 9)))
    (values (if nes2-p
                (%nes2-rom-bank-count
                 (aref octets 4) (ldb (byte 4 0) byte9) "PRG")
                (aref octets 4))
            (if nes2-p
                (%nes2-rom-bank-count
                 (aref octets 5) (ldb (byte 4 4) byte9) "CHR")
                (aref octets 5))
            (logior (ash (logand flags6 #xF0) -4)
                    (logand flags7 #xF0)
                    (if nes2-p
                        (ash (logand byte8 #x0F) 8)
                        0))
            nes2-p)))

(defun %decode-ines-metadata (flags6)
  (values (logbitp 2 flags6)
          (logbitp 3 flags6)
          (if (logbitp 0 flags6) :vertical :horizontal)
          (logbitp 1 flags6)))

(defun %decode-prg-ram-size (octets nes2-p)
  (let ((byte8 (aref octets 8)))
    (if nes2-p
        (+ (%nes2-ram-size
            (ldb (byte 4 0) (aref octets 10)))
           (%nes2-ram-size
            (ldb (byte 4 4) (aref octets 10))))
        (* (if (zerop byte8) 1 byte8)
           +prg-ram-bank-size+))))

(defun %ines-data-layout (prg-banks chr-banks trainer-p)
  (let* ((prg-size (* prg-banks +prg-bank-size+))
         (chr-size (* chr-banks +chr-bank-size+))
         (offset (+ +ines-header-size+
                    (if trainer-p +ines-trainer-size+ 0))))
    (values prg-size chr-size offset (+ offset prg-size chr-size))))

(defun %validate-ines-image! (octets prg-banks mapper required)
  (when (zerop prg-banks)
    (%ines-error "ROM has no PRG banks"))
  (unless (<= required (length octets))
    (%ines-error "ROM is truncated: expected at least ~D bytes, got ~D"
                 required (length octets)))
  (unless (member mapper '(0 1 2 3 4 5 7 11 22 28 34))
    (error 'unsupported-mapper :number mapper)))
