(in-package #:cl-nes/test)

(defmacro with-apu-channels ((apu) &body body)
  `(let* ((,apu (make-apu))
          (pulse (cl-nes::apu-pulse-1 ,apu))
          (pulse-2 (cl-nes::apu-pulse-2 ,apu))
          (triangle (cl-nes::apu-triangle ,apu))
          (noise (cl-nes::apu-noise ,apu))
          (dmc (cl-nes::apu-dmc ,apu)))
     (declare (ignorable pulse pulse-2 triangle noise dmc))
     ,@body))

(defmacro with-patterned-cartridge ((cartridge &rest initargs) &body body)
  `(let ((,cartridge (make-patterned-cartridge ,@initargs)))
     ,@body))

(defmacro with-mmc5-cartridge ((cartridge &rest initargs) &body body)
  `(with-patterned-cartridge (,cartridge
                              :mapper 5
                              :prg-banks 16
                              :chr-banks 16
                              ,@initargs)
     ,@body))

(defmacro with-mmc3-cartridge ((cartridge &rest initargs) &body body)
  `(with-patterned-cartridge (,cartridge
                              :mapper 4
                              :prg-banks 8
                              :chr-banks 8
                              ,@initargs)
     ,@body))

(defmacro with-ppu ((ppu &optional cartridge) &body body)
  `(let ((,ppu ,(if cartridge
                    `(make-ppu ,cartridge)
                    '(make-ppu))))
     ,@body))

(defmacro with-fixture-ppu ((ppu &rest cartridge-initargs) &body body)
  `(with-ppu (,ppu (make-fixture-cartridge ,@cartridge-initargs))
     ,@body))

(defmacro with-screen-bits ((&rest names) &body body)
  `(let ,(loop for name in names
               collect
               `(,name
                 (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                             :element-type 'bit
                             :initial-element 0)))
     ,@body))

(defmacro expect-background-pixel ((ppu x y) color present)
  `(multiple-value-bind (actual-color actual-present)
       (cl-nes::%background-pixel ,ppu ,x ,y)
     (expect actual-color :to-be ,color)
     (expect actual-present :to-be ,present)))

(defmacro expect-sprite-pixel ((ppu sprite-index x y) color present behind)
  `(multiple-value-bind (actual-color actual-present actual-behind)
       (cl-nes::%sprite-pixel ,ppu ,sprite-index ,x ,y)
     (expect actual-color :to-be ,color)
     (expect actual-present :to-be ,present)
     (expect actual-behind :to-be ,behind)))

(defmacro expect-apu-register-state
    ((apu pulse-2 triangle noise dmc)
     &key
       pulse-duty
       pulse-period
       pulse-length
       pulse-sweep-enabled
       pulse-sweep-negate
       triangle-period
       triangle-length
       triangle-linear-reload
       noise-mode
       noise-length
       dmc-irq-enabled
       dmc-loop
       dmc-rate-index
       dmc-output
       dmc-sample-address
       dmc-sample-length
       status-mask)
  `(progn
     ,@(loop for (place value)
               in `(((cl-nes::apu-pulse-duty ,pulse-2) ,pulse-duty)
                    ((cl-nes::apu-pulse-timer-period ,pulse-2) ,pulse-period)
                    ((cl-nes::apu-pulse-length-counter ,pulse-2) ,pulse-length)
                    ((cl-nes::apu-pulse-sweep-enabled-p ,pulse-2)
                     ,pulse-sweep-enabled)
                    ((cl-nes::apu-pulse-sweep-negate-p ,pulse-2)
                     ,pulse-sweep-negate)
                    ((cl-nes::apu-triangle-timer-period ,triangle)
                     ,triangle-period)
                    ((cl-nes::apu-triangle-length-counter ,triangle)
                     ,triangle-length)
                    ((cl-nes::apu-triangle-linear-reload-value ,triangle)
                     ,triangle-linear-reload)
                    ((cl-nes::apu-noise-mode-p ,noise) ,noise-mode)
                    ((cl-nes::apu-noise-length-counter ,noise) ,noise-length)
                    ((cl-nes::apu-dmc-irq-enabled-p ,dmc) ,dmc-irq-enabled)
                    ((cl-nes::apu-dmc-loop-p ,dmc) ,dmc-loop)
                    ((cl-nes::apu-dmc-rate-index ,dmc) ,dmc-rate-index)
                    ((cl-nes::apu-dmc-output ,dmc) ,dmc-output)
                    ((cl-nes::apu-dmc-sample-address ,dmc) ,dmc-sample-address)
                    ((cl-nes::apu-dmc-sample-length ,dmc) ,dmc-sample-length))
             when value
               collect `(expect ,place :to-be ,value))
     ,@(when status-mask
         `((let ((status (apu-read-register ,apu #x4015)))
             (expect (logand status #x1F) :to-be ,status-mask))))))
