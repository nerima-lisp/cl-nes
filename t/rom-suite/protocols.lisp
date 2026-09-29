(in-package #:cl-nes/rom-suite)

(defstruct (rom-contract (:constructor make-rom-contract
                              (id category path protocol expected max-frames state
                               failure-text &optional mapper4-variant suite)))
  id category path protocol expected max-frames state failure-text mapper4-variant suite)

(defparameter *rom-root-environment* "CL_NES_TEST_ROMS")
(defparameter *accuracy-coin-environment* "CL_NES_ACCURACY_COIN")
(defparameter *nestest-rom-environment* "CL_NES_NESTEST_ROM")
(defparameter *nestest-log-environment* "CL_NES_NESTEST_LOG")
(defparameter *nestest-state* :pass)
(defparameter *nestest-failure-text* nil)

(defparameter *rom-contract-data*
  '((:suite "cpu" :category :cpu
     :subroms ((:id "instr-test-v5" :path "instr_test-v5/all_instrs.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "status 128; running test 5 of 16")
               (:id "instr-timing" :path "instr_timing/instr_timing.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "1C/3C/5C page-cross expected 5, got 4")
               (:id "instr-misc" :path "instr_misc/instr_misc.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "Illegal 6502 opcode #x9B at #xF3E9")
               (:id "cpu-interrupts-v2" :path "cpu_interrupts_v2/cpu_interrupts.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                 :failure-text "status 1; failed while running test 2 of 5")
               (:id "cpu-dummy-reads" :path "cpu_dummy_reads/cpu_dummy_reads.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "status 0 but signature mismatch")
               (:id "cpu-dummy-writes" :path "cpu_dummy_writes/cpu_dummy_writes_oam.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :pass
                 :failure-text "status 0")))
    (:suite "ppu" :category :ppu
     :subroms ((:id "ppu-vbl-nmi" :path "ppu_vbl_nmi/ppu_vbl_nmi.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                 :failure-text "status 1; failed while running test 2 of 10")))
    (:suite "apu" :category :apu
     :subroms ((:id "apu-test" :path "apu_test/apu_test.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :pass
                 :failure-text "status 0; all 8 tests passed")
               (:id "blargg-apu" :path "blargg_apu_2005.07.30/01.len_ctr.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "status 0 but signature mismatch")))
    (:suite "dma" :category :dma
     :subroms ((:id "dmc-dma" :path "dmc_dma_during_read4/dma_2007_read.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "status 0 but signature mismatch")
               (:id "sprite-dma-and-dmc" :path "sprdma_and_dmc_dma/sprdma_and_dmc_dma.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "status 128; incomplete at text T+ Clocks")))
    (:suite "mapper" :category :mapper
     :subroms ((:id "mmc3-test-2" :path "mmc3_test_2/rom_singles/1-clocking.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :pass
                 :failure-text "status 0; 1-clocking Passed"
                 :mapper4-variant :mmc3)))))

(defparameter *accuracy-coin-contract*
  '(:id "accuracy-coin" :category :accuracy-coin :path "AccuracyCoin.nes"
    :protocol :accuracy-coin :expected 146 :max-frames 1200 :state :known-fail
    :failure-text "named result item mismatch"
    :items ((:name "item-0400" :address #x0400 :expected :pass))))

(defun accuracy-coin-items ()
  (loop for address from #x0400 below (+ #x0400 146)
        collect (list :name (format nil "item-~4,'0X" address)
                      :address address :expected :pass)))

(setf (getf *accuracy-coin-contract* :items) (accuracy-coin-items))

(defparameter *rom-contract-test-data*
  (loop for suite in *rom-contract-data*
        append (loop with category = (getf suite :category)
                     for subrom in (getf suite :subroms)
                     collect (list (getf subrom :id) category
                                   (getf subrom :path)
                                   (getf subrom :protocol)
                                   (getf subrom :expected)
                                   (getf subrom :max-frames)
                                   (getf subrom :state)
                                   (getf subrom :failure-text)
                                   (getf subrom :mapper4-variant)))))

(defun rom-contract-table ()
  (loop for suite in *rom-contract-data*
        append (loop with category = (getf suite :category)
                     with suite-name = (getf suite :suite)
                     for subrom in (getf suite :subroms)
                     collect (make-rom-contract
                              (getf subrom :id) category (getf subrom :path)
                              (getf subrom :protocol) (getf subrom :expected)
                              (getf subrom :max-frames) (getf subrom :state)
                              (getf subrom :failure-text)
                              (getf subrom :mapper4-variant) suite-name))))

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

(defun run-frames-until (nes max-frames predicate)
  (loop for frame from 1 to max-frames
        do (cl-nes:nes-run-frame/k nes #'identity)
           (when (funcall predicate frame)
             (return frame))))

(defun run-blargg-contract (path contract)
  (run-blargg-protocol path (rom-contract-max-frames contract)
                       :mapper4-variant
                       (rom-contract-mapper4-variant contract)))

(defun run-screen-contract (path contract)
  (run-screen-protocol path (rom-contract-max-frames contract)
                       (rom-contract-expected contract)))

(defun accuracy-result-kind (value)
  (cond
    ((= value 1) :pass)
    ((= value #xff) :skipped)
    ((= value 3) :running)
    ((and (= (logand value 3) 2) (>= value 2)) :fail)
    (t :fail)))

(defun run-accuracy-coin (path contract)
  (let ((nes (cl-nes:make-nes :cartridge (cl-nes:load-cartridge path)))
        (results nil))
    (run-frames-until
     nes (getf contract :max-frames)
     (lambda (frame)
       (declare (ignore frame))
       (let ((bus (cl-nes:nes-bus nes)))
         (setf results (read-bus-range bus #x0400 #x04ff))
         (and results
              (every (lambda (item)
                       (not (= 3 (nth (- (getf item :address) #x0400)
                                      results))))
                     (getf contract :items))))))
    (unless results
      (setf results (read-bus-range (cl-nes:nes-bus nes) #x0400 #x04ff)))
    (let* ((items (loop for item in (getf contract :items)
                        for address = (getf item :address)
                        for value = (nth (- address #x0400) results)
                        for kind = (accuracy-result-kind value)
                        collect (list :name (getf item :name)
                                      :address address :value value :kind kind
                                      :expected (getf item :expected))))
           (pass-count (count :pass items :key (lambda (item) (getf item :kind))))
           (fail-count (count :fail items :key (lambda (item) (getf item :kind))))
           (skip-count (count :skipped items :key (lambda (item) (getf item :kind))))
           (running-count (count :running items :key (lambda (item) (getf item :kind))))
           (completed-count (+ pass-count fail-count)))
      (list :passed (every (lambda (item)
                             (eq (getf item :kind) (getf item :expected)))
                           items)
            :pass-count pass-count :total (getf contract :expected)
            :fail-count fail-count :skip-count skip-count
            :running-count running-count :completed-count completed-count
            :items items :results results))))
