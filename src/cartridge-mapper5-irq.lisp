(in-package #:cl-nes)

(defun cartridge-clock-scanline! (cartridge scanline)
  (when (and cartridge (= (cartridge-mapper cartridge) 5))
    (setf (cartridge-mapper5-in-frame-p cartridge) (< scanline 240))
    (when (and (cartridge-mapper5-in-frame-p cartridge)
               (cartridge-mapper5-irq-enabled-p cartridge)
               (= scanline (cartridge-mapper5-irq-scanline cartridge)))
      (setf (cartridge-mapper5-irq-pending-p cartridge) t)))
  cartridge)

(defun cartridge-irq-pending-p (cartridge)
  (and cartridge
       (or (and (= (cartridge-mapper cartridge) 4)
                (cartridge-mapper4-irq-pending-p cartridge))
           (and (= (cartridge-mapper cartridge) 5)
                (cartridge-mapper5-irq-pending-p cartridge)))))
