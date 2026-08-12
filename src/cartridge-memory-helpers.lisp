(in-package #:cl-nes)

(defun %cartridge-mapper-p (cartridge mapper)
  (and cartridge
       (= (cartridge-mapper cartridge) mapper)))

(defun %cartridge-mapper5-p (cartridge)
  (%cartridge-mapper-p cartridge 5))

(defun %cartridge-cpu-expansion-address-p (address)
  (<= #x5000 address #x5FFF))

(defun %cartridge-cpu-prg-ram-address-p (address)
  (<= #x6000 address #x7FFF))

(defun %cartridge-cpu-prg-address-p (address)
  (<= #x8000 address #xFFFF))

(defun %cartridge-standard-prg-register-address-p (address)
  (%cartridge-cpu-prg-address-p address))

(defun %cartridge-mapper28-register-address-p (address)
  (or (%cartridge-cpu-expansion-address-p address)
      (%cartridge-standard-prg-register-address-p address)))

(defun %cartridge-nrom-368-address-p (address)
  (<= #x4800 address #xFFFF))

(defun %cartridge-cpu-readable-prg-address-p (cartridge address)
  (or (and (%cartridge-nrom-368-p cartridge)
           (%cartridge-nrom-368-address-p address))
      (%cartridge-cpu-prg-address-p address)))

(defun %cartridge-chr-address-p (address)
  (<= 0 address #x1FFF))
