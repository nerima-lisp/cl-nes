(in-package #:cl-nes/rom-suite)

(defstruct (rom-contract (:constructor make-rom-contract
                              (id category path protocol expected max-frames state
                               failure-text &optional mapper4-variant)))
  id category path protocol expected max-frames state failure-text mapper4-variant)

(defparameter *rom-root-environment* "CL_NES_TEST_ROMS")
(defparameter *accuracy-coin-environment* "CL_NES_ACCURACY_COIN")
(defparameter *nestest-rom-environment* "CL_NES_NESTEST_ROM")
(defparameter *nestest-log-environment* "CL_NES_NESTEST_LOG")
(defparameter *nestest-state* :known-fail)
(defparameter *nestest-failure-text*
  "line 5046 CYC expected 14691 actual 14690")

(defparameter *rom-contract-data*
  '(("instr-test-v5" :cpu "instr_test-v5/all_instrs.nes" :blargg 0 60 :known-fail
     "status 128; running test 5 of 16" nil)
    ("instr-timing" :cpu "instr_timing/instr_timing.nes" :blargg 0 60 :known-fail
     "status 128; 1C/3C/5C page-cross expected 5, got 4" nil)
    ("instr-misc" :cpu "instr_misc/instr_misc.nes" :blargg 0 60 :known-fail
     "Illegal 6502 opcode #x9B at #xF3E9" nil)
    ("cpu-interrupts-v2" :cpu "cpu_interrupts_v2/cpu_interrupts.nes" :blargg 0 360 :known-fail
     "status 1; failed while running test 2 of 5" nil)
    ("cpu-dummy-reads" :cpu "cpu_dummy_reads/cpu_dummy_reads.nes" :blargg 0 60 :known-fail
     "status 0 but signature mismatch" nil)
    ("cpu-dummy-writes" :cpu "cpu_dummy_writes/cpu_dummy_writes_oam.nes" :blargg 0 360 :pass
     "status 0" nil)
    ("ppu-vbl-nmi" :ppu "ppu_vbl_nmi/ppu_vbl_nmi.nes" :blargg 0 360 :known-fail
     "status 1; failed while running test 2 of 10" nil)
    ("ppu-sprite-hit" :ppu "sprite_hit_tests_2005.10.05/01.basics.nes" :screen-hash "UNRECORDED" 60 :known-fail
     "framebuffer hash B87D5DC5; expected hash unrecorded" nil)
    ("ppu-sprite-overflow" :ppu "sprite_overflow_tests/1.Basics.nes" :screen-hash "UNRECORDED" 60 :known-fail
     "framebuffer hash B87D5DC5; expected hash unrecorded" nil)
    ("ppu-open-bus" :ppu "ppu_open_bus/ppu_open_bus.nes" :screen-hash "UNRECORDED" 60 :known-fail
     "framebuffer hash B87D5DC5; expected hash unrecorded" nil)
    ("ppu-read-buffer" :ppu "ppu_read_buffer/test_ppu_read_buffer.nes" :screen-hash "UNRECORDED" 60 :known-fail
     "framebuffer hash B87D5DC5; expected hash unrecorded" nil)
    ("oam-read" :ppu "oam_read/oam_read.nes" :screen-hash "UNRECORDED" 60 :known-fail
     "framebuffer hash B87D5DC5; expected hash unrecorded" nil)
    ("apu-test" :apu "apu_test/apu_test.nes" :blargg 0 360 :pass
     "status 0; all 8 tests passed" nil)
    ("blargg-apu" :apu "blargg_apu_2005.07.30/01.len_ctr.nes" :blargg 0 60 :known-fail
     "status 0 but signature mismatch" nil)
    ("dmc-dma" :dma "dmc_dma_during_read4/dma_2007_read.nes" :blargg 0 60 :known-fail
     "status 0 but signature mismatch" nil)
    ("sprite-dma-and-dmc" :dma "sprdma_and_dmc_dma/sprdma_and_dmc_dma.nes" :blargg 0 60 :known-fail
     "status 128; incomplete at text T+ Clocks" nil)
    ("mmc3-test-2" :mapper "mmc3_test_2/rom_singles/1-clocking.nes" :blargg 0 60 :pass
     "status 0; 1-clocking Passed" :mmc3)))

(defparameter *accuracy-coin-contract*
  '(:id "accuracy-coin" :category :accuracy-coin :path "AccuracyCoin.nes"
    :protocol :accuracy-coin :expected 146 :max-frames 1200 :state :known-fail
    :failure-text "0/146 passed; no result cells completed before CI limit"))

(defun rom-contract-table ()
  (mapcar (lambda (row)
            (destructuring-bind (id category path protocol expected max-frames state failure-text mapper)
                row
              (make-rom-contract id category path protocol expected max-frames state
                                 failure-text mapper)))
          *rom-contract-data*))

(defun env-path (name)
  (uiop:getenv name))

(defun resolve-rom-path (contract)
  (let ((path (rom-contract-path contract)))
    (merge-pathnames
     path
     (uiop:ensure-directory-pathname
      (or (env-path *rom-root-environment*) "")))))

(defun accuracy-coin-path ()
  (or (env-path *accuracy-coin-environment*)
      (let ((root (env-path *rom-root-environment*)))
        (and root (merge-pathnames "../AccuracyCoin/AccuracyCoin.nes" root)))))

(defun read-bus-range (bus start end)
  (loop for address from start to end collect (cl-nes:bus-read bus address)))

(defun ascii-result (bytes)
  (string-trim '(#\Space #\Tab #\Return #\Newline #\Null #\.)
               (coerce (mapcar (lambda (byte)
                                 (if (<= 32 byte 126) (code-char byte) #\.))
                               bytes)
                       'string)))

(defun framebuffer-hash (framebuffer)
  (let ((hash 2166136261))
    (loop for byte across framebuffer
          do (setf hash (logand #xffffffff (* (logxor hash byte) 16777619))))
    (format nil "~8,'0X" hash)))

(defun run-frames-until (nes max-frames predicate)
  (loop for frame from 1 to max-frames
        do (cl-nes:nes-run-frame/k nes #'identity)
           (when (funcall predicate frame)
             (return frame))))

(defun load-contract-cartridge (path contract)
  (let ((variant (rom-contract-mapper4-variant contract)))
    (if variant
        (cl-nes:load-cartridge path :mapper4-variant variant)
        (cl-nes:load-cartridge path))))

(defun run-blargg-contract (path contract)
  (let* ((cartridge (load-contract-cartridge path contract))
         (nes (cl-nes:make-nes :cartridge cartridge))
         (last-text "")
         (frames (run-frames-until
                  nes (rom-contract-max-frames contract)
                  (lambda (frame)
                    (declare (ignore frame))
                    (let* ((bus (cl-nes:nes-bus nes))
                           (status (cl-nes:bus-read bus #x6000))
                           (signature-p (equal '(222 176 97)
                                               (read-bus-range bus #x6001 #x6003))))
                      (setf last-text (ascii-result (read-bus-range bus #x6004 #x60ff)))
                      (or (= status 1)
                          (and (zerop status) signature-p)
                          (and (/= status 0) (/= status #x80))
                          (search "FAILED" (string-upcase last-text))))))))
    (let* ((bus (cl-nes:nes-bus nes))
           (signature-ok (equal '(222 176 97)
                                (read-bus-range bus #x6001 #x6003)))
           (status (cl-nes:bus-read bus #x6000))
           (passed (and signature-ok (zerop status))))
      (list :passed passed :frames frames :text last-text :status status
            :signature signature-ok
            :hash (framebuffer-hash (cl-nes:ppu-framebuffer (cl-nes:nes-ppu nes)))))))

(defun run-screen-contract (path contract)
  (let ((nes (cl-nes:make-nes :cartridge (cl-nes:load-cartridge path))))
    (run-frames-until nes (rom-contract-max-frames contract) (constantly t))
    (let ((hash (framebuffer-hash (cl-nes:ppu-framebuffer (cl-nes:nes-ppu nes)))))
      (list :passed (string-equal hash (rom-contract-expected contract))
            :hash hash :frames (rom-contract-max-frames contract)))))

(defun accuracy-result-value-p (value)
  (or (= value 1) (= value #xff) (= value 3)
      (and (= (logand value 3) 2) (>= value 2))))

(defun accuracy-result-kind (value)
  (cond
    ((= value 1) :pass)
    ((= value #xff) :skipped)
    ((= value 3) :running)
    ((and (= (logand value 3) 2) (>= value 2)) :fail)
    (t :unrecorded)))

(defun run-accuracy-coin (path contract)
  (let ((nes (cl-nes:make-nes :cartridge (cl-nes:load-cartridge path)))
        (results nil))
    (run-frames-until
     nes (getf contract :max-frames)
     (lambda (frame)
       (declare (ignore frame))
       (let ((bus (cl-nes:nes-bus nes)))
         (setf results (read-bus-range bus #x0400 #x04ff))
         (and (= 146 (count-if #'accuracy-result-value-p results))
              (not (member 3 results))))))
    (unless results
      (setf results (read-bus-range (cl-nes:nes-bus nes) #x0400 #x04ff)))
    (let* ((items (loop for value in results
                        for index from #x0400
                        for kind = (accuracy-result-kind value)
                        when (not (eq kind :unrecorded))
                          collect (list :address index :value value :kind kind)))
           (pass-count (count :pass items :key (lambda (item) (getf item :kind))))
           (fail-count (count :fail items :key (lambda (item) (getf item :kind))))
           (skip-count (count :skipped items :key (lambda (item) (getf item :kind))))
           (running-count (count :running items :key (lambda (item) (getf item :kind))))
           (completed-count (+ pass-count fail-count)))
      (list :passed (and (= completed-count (getf contract :expected))
                         (= pass-count (getf contract :expected)))
            :pass-count pass-count :total (getf contract :expected)
            :fail-count fail-count :skip-count skip-count
            :running-count running-count :completed-count completed-count
            :items items :results results))))
