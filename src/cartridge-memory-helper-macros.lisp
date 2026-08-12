(in-package #:cl-nes)

(defmacro %when-cartridge-standard-prg-register-address ((address) &body body)
  `(when (%cartridge-standard-prg-register-address-p ,address)
     ,@body))

(defmacro %when-cartridge-mapper28-register-address ((address) &body body)
  `(when (%cartridge-mapper28-register-address-p ,address)
     ,@body))

(defmacro %with-mmc5-nametable-location ((source within cartridge address)
                                         &body body)
  `(multiple-value-bind (,source ,within)
       (cartridge-mmc5-nametable-location ,cartridge ,address)
     ,@body))
