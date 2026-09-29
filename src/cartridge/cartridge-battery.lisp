(in-package #:cl-nes)

(defun %ensure-cartridge-battery! (cartridge)
  (unless (cartridge-battery-backed-p cartridge)
    (error 'cartridge-battery-error
           :reason :not-battery-backed
           :expected-size (length (cartridge-prg-ram cartridge))
           :actual-size 0))
  (unless (plusp (length (cartridge-prg-ram cartridge)))
    (error 'cartridge-battery-error
           :reason :no-prg-ram :expected-size 0 :actual-size 0)))

(defun cartridge-save-battery (cartridge)
  (%ensure-cartridge-battery! cartridge)
  (copy-seq (cartridge-prg-ram cartridge)))

(defun cartridge-restore-battery! (cartridge octets)
  (%ensure-cartridge-battery! cartridge)
  (let ((expected (length (cartridge-prg-ram cartridge)))
        (actual (length octets)))
    (unless (= expected actual)
      (error 'cartridge-battery-error :reason :size-mismatch
             :expected-size expected :actual-size actual))
    (replace (cartridge-prg-ram cartridge) octets))
  cartridge)
