(in-package #:cl-nes/test-runner)

(defun test-cpu-instructions ()
  (let* ((cartridge (make-test-cartridge
                     :program (list #xA9 #x42 #xAA #xE8 #x69 #x01 #x85 #x10)))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (cpu-reset! cpu bus)
    (check-equal (cpu-pc cpu) #x8000 "CPU loads the reset vector")
    (check-equal (cpu-step! cpu bus) 2 "LDA immediate has two cycles")
    (check-equal (cpu-a cpu) #x42 "LDA updates A")
    (cpu-step! cpu bus)
    (cpu-step! cpu bus)
    (cpu-step! cpu bus)
    (check-equal (cpu-a cpu) #x43 "ADC updates A")
    (cpu-step! cpu bus)
    (check-equal (bus-read bus #x0010) #x43 "STA writes through the CPU bus")
    (let* ((indexed-cartridge
             (make-test-cartridge :program (list #xA0 #x01 #xB6 #x10)))
           (indexed-bus (make-bus :cartridge indexed-cartridge))
           (indexed-cpu (make-cpu)))
      (bus-write! indexed-bus #x0011 #x77)
      (cpu-reset! indexed-cpu indexed-bus)
      (check-equal (cpu-step! indexed-cpu indexed-bus) 2
                   "LDY immediate prepares the zero-page index")
      (check-equal (cpu-step! indexed-cpu indexed-bus) 4
                   "LDX zero-page,Y uses the documented four cycles")
      (check-equal (cpu-x indexed-cpu) #x77
                   "LDX zero-page,Y reads the indexed byte"))
    (let* ((jsr-cartridge (make-test-cartridge
                           :program (list #x20 #x06 #x80 #xEA #xEA #xEA
                                          #xA9 #x55 #x60)))
           (jsr-bus (make-bus :cartridge jsr-cartridge))
           (jsr-cpu (make-cpu)))
      (cpu-reset! jsr-cpu jsr-bus)
      (cpu-step! jsr-cpu jsr-bus)
      (check-equal (cpu-pc jsr-cpu) #x8006 "JSR jumps to the subroutine")
      (cpu-step! jsr-cpu jsr-bus)
      (cpu-step! jsr-cpu jsr-bus)
      (check-equal (cpu-a jsr-cpu) #x55 "subroutine executes")
      (check-equal (cpu-pc jsr-cpu) #x8003 "RTS returns after the JSR operand"))
    (let* ((illegal-cartridge (make-test-cartridge :program (list #x02)))
           (illegal-bus (make-bus :cartridge illegal-cartridge))
           (illegal-cpu (make-cpu)))
      (cpu-reset! illegal-cpu illegal-bus)
      (check (signals-type-p 'illegal-opcode
                             (lambda () (cpu-step! illegal-cpu illegal-bus)))
             "undefined opcodes signal illegal-opcode"))))

(defun test-cpu-interrupts ()
  (let* ((cartridge (make-test-cartridge :nmi #x9000 :irq #xA000))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (cpu-reset! cpu bus)
    (check-equal (cpu-cycles cpu) 7 "CPU reset starts the cycle counter at seven reset cycles")
    (check-equal (cpu-interrupt! cpu bus :nmi) 7 "NMI takes seven cycles")
    (check-equal (cpu-pc cpu) #x9000 "NMI loads the NMI vector")
    (check-equal (cpu-sp cpu) #xFA "NMI pushes PC and status")
    (check-equal (bus-read bus #x01FD) #x80 "NMI pushes the PC high byte")
    (let ((pc (cpu-pc cpu)))
      (check (not (cpu-interrupt! cpu bus :irq))
             "IRQ is masked while the I flag is set")
      (check-equal (cpu-pc cpu) pc "masked IRQ leaves PC unchanged"))))

(defun test-boundary-cases ()
  (let ((rom (make-array (+ 16 #x200 #x4000)
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    (setf (aref rom 0) #x4E
          (aref rom 1) #x45
          (aref rom 2) #x53
          (aref rom 3) #x1A
          (aref rom 4) 1
          (aref rom 5) 0
          (aref rom 6) #x05
          (aref rom (+ 16 #x200)) #xA5)
    (let ((loaded (load-cartridge rom)))
      (check-equal (cartridge-read-prg loaded #x8000) #xA5
                   "iNES trainer is skipped before PRG data")
      (check (cartridge-chr-writable-p loaded)
             "iNES zero CHR banks create CHR-RAM")
      (cartridge-write-chr! loaded 0 #x3D)
      (check-equal (cartridge-read-chr loaded 0) #x3D
                   "iNES CHR-RAM is writable")))
  (let* ((prg (make-array #x8000
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (vertical (make-cartridge :prg-rom prg :mirroring :vertical))
         (horizontal (make-cartridge :prg-rom prg :mirroring :horizontal))
         (four-screen (make-cartridge :prg-rom prg :four-screen-p t)))
    (let ((ppu (make-ppu vertical)))
      (ppu-write-vram! ppu 0 #x66)
      (check-equal (ppu-read-vram ppu 0) #x66
                   "direct cartridges default to writable CHR-RAM")
      (ppu-write-vram! ppu #x2000 #x11)
      (ppu-write-vram! ppu #x2400 #x22)
      (check-equal (ppu-read-vram ppu #x2800) #x11
                   "vertical mirroring maps $2000 to $2800")
      (check-equal (ppu-read-vram ppu #x2C00) #x22
                   "vertical mirroring maps $2400 to $2C00"))
    (let ((ppu (make-ppu horizontal)))
      (ppu-write-vram! ppu #x2000 #x33)
      (ppu-write-vram! ppu #x2800 #x44)
      (check-equal (ppu-read-vram ppu #x2400) #x33
                   "horizontal mirroring maps $2000 to $2400")
      (check-equal (ppu-read-vram ppu #x2C00) #x44
                   "horizontal mirroring maps $2800 to $2C00"))
    (let ((ppu (make-ppu four-screen)))
      (ppu-write-vram! ppu #x2000 #x55)
      (check-equal (ppu-read-vram ppu #x2800) 0
                   "four-screen mirroring keeps nametables distinct")))
  (let* ((cartridge (make-test-cartridge
                     :program (list #x6C #xFF #x12)))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (bus-write! bus #x12FF #x34)
    (bus-write! bus #x1200 #x12)
    (cpu-reset! cpu bus)
    (cpu-step! cpu bus)
    (check-equal (cpu-pc cpu) #x1234
                 "indirect JMP wraps the pointer within its page"))
  (let* ((cartridge (make-test-cartridge
                     :program (list #xA2 #x01 #xBD #xFF #x00)))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (bus-write! bus #x0100 #x7A)
    (cpu-reset! cpu bus)
    (cpu-step! cpu bus)
    (check-equal (cpu-step! cpu bus) 5
                 "absolute indexed read charges a page-cross cycle")
    (check-equal (cpu-a cpu) #x7A
                 "absolute indexed read crosses into the next page"))
  (let* ((cartridge (make-test-cartridge
                     :program (list #x9C #xFF #x00)))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (cpu-reset! cpu bus)
    (setf (cpu-x cpu) 1
          (cpu-y cpu) #xFF)
    (cpu-step! cpu bus)
    (check-equal (bus-read bus #x0200) 2
                 "SHY uses the effective high byte after an indexed page crossing"))
  (let* ((cartridge (make-test-cartridge
                     :program (list #x00 #xEA)
                     :irq #x9000))
         (bus (make-bus :cartridge cartridge))
         (cpu (make-cpu)))
    (setf (aref (cartridge-prg-rom cartridge) #x1000) #x40)
    (cpu-reset! cpu bus)
    (cpu-step! cpu bus)
    (check-equal (cpu-pc cpu) #x9000 "BRK loads the IRQ vector")
    (check-equal (cpu-sp cpu) #xFA "BRK pushes the return state")
    (cpu-step! cpu bus)
    (check-equal (cpu-pc cpu) #x8002 "RTI restores the BRK return address")
    (check-equal (cpu-sp cpu) #xFD "RTI restores the stack pointer"))
  (let* ((ppu (make-ppu (make-test-cartridge)))
         (bus (make-bus :ppu ppu)))
    (loop for index from 0 below 256
          do (bus-write! bus (+ #x0200 index) index))
    (bus-write! bus #x4014 #x02)
    (check-equal (aref (ppu-oam ppu) 0) 0
                 "OAM DMA copies the first byte")
    (check-equal (aref (ppu-oam ppu) #xFF) #xFF
                 "OAM DMA copies the last byte")))
