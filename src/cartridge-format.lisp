(in-package #:cl-nes)

(defun load-cartridge (source &key mapper4-variant)
  (setf mapper4-variant (or mapper4-variant :mmc3))
  (let ((octets (%coerce-cartridge-source source)))
    (unless (%valid-ines-header-p octets)
      (%ines-error "Missing NES\\x1A header"))
    (let ((flags6 (aref octets 6)))
      (multiple-value-bind (prg-banks chr-banks mapper nes2-p)
          (%decode-ines-geometry octets)
        (multiple-value-bind (trainer-p four-screen-p mirroring battery-backed-p)
            (%decode-ines-metadata flags6)
          (multiple-value-bind (prg-size chr-size offset required)
              (%ines-data-layout prg-banks chr-banks trainer-p)
            (declare (ignore chr-size))
            (%validate-ines-image! octets prg-banks mapper required)
            (make-cartridge
             :prg-rom (subseq octets offset (+ offset prg-size))
             :chr-rom (unless (zerop chr-banks)
                        (subseq octets (+ offset prg-size) required))
             :mapper mapper
             :mirroring mirroring
             :battery-backed-p battery-backed-p
             :four-screen-p four-screen-p
             :chr-writable-p (zerop chr-banks)
             :prg-ram-size (%decode-prg-ram-size octets nes2-p)
             :mapper4-variant mapper4-variant)))))))
