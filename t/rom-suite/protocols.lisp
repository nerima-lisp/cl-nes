(in-package #:cl-nes/rom-suite)

(defstruct (rom-contract (:constructor make-rom-contract
                              (id category path protocol expected max-frames state
                               failure-text &optional mapper4-variant suite
                               result-address running-value)))
  id category path protocol expected max-frames state failure-text mapper4-variant suite
  result-address running-value)

(defparameter *rom-root-environment* "CL_NES_TEST_ROMS")
(defparameter *accuracy-coin-environment* "CL_NES_ACCURACY_COIN")
(defparameter *nestest-rom-environment* "CL_NES_NESTEST_ROM")
(defparameter *nestest-log-environment* "CL_NES_NESTEST_LOG")
(defparameter *nestest-state* :pass)
(defparameter *nestest-failure-text* nil)

(defparameter *rom-contract-data*
  '((:suite "cpu" :category :cpu
     :subroms ((:id "instr-test-v5" :path "instr_test-v5/all_instrs.nes"
                 :protocol :blargg :expected 0 :max-frames 3000 :state :pass
                 :failure-text "All 16 tests passed")
               (:id "instr-timing" :path "instr_timing/instr_timing.nes"
                 :protocol :blargg :expected 0 :max-frames 1500 :state :pass
                 :failure-text "All 2 tests passed")
               (:id "instr-misc" :path "instr_misc/instr_misc.nes"
                 :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                 :failure-text "Illegal 6502 opcode #x9B at #xF3E9")
               (:id "cpu-interrupts-v2" :path "cpu_interrupts_v2/cpu_interrupts.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                 :failure-text "status 1; failed while running test 2 of 5")
               (:id "cpu-dummy-reads" :path "cpu_dummy_reads/cpu_dummy_reads.nes"
                 :protocol :ram-result :expected 0 :result-address #x6000
                 :max-frames 60 :state :pass
                 :failure-text "status $6000; 0 means PASSED")
               (:id "cpu-dummy-writes" :path "cpu_dummy_writes/cpu_dummy_writes_oam.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :pass
                 :failure-text "status 0")))
    (:suite "cpu-subroms" :category :cpu
     :subroms
     ((:id "instr-test-v5-01-basics" :path "instr_test-v5/rom_singles/01-basics.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 01-basics..Passed")
      (:id "instr-test-v5-02-implied" :path "instr_test-v5/rom_singles/02-implied.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 02-implied..Passed")
      (:id "instr-test-v5-03-immediate" :path "instr_test-v5/rom_singles/03-immediate.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 03-immediate..Passed")
      (:id "instr-test-v5-04-zero-page" :path "instr_test-v5/rom_singles/04-zero_page.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 04-zero_page..Passed")
      (:id "instr-test-v5-05-zp-xy" :path "instr_test-v5/rom_singles/05-zp_xy.nes"
       :protocol :blargg :expected 0 :max-frames 600 :state :pass :failure-text "status 0; 05-zp_xy..Passed")
      (:id "instr-test-v5-06-absolute" :path "instr_test-v5/rom_singles/06-absolute.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 06-absolute..Passed")
      (:id "instr-test-v5-07-abs-xy" :path "instr_test-v5/rom_singles/07-abs_xy.nes"
       :protocol :blargg :expected 0 :max-frames 600 :state :pass :failure-text "status 0; 07-abs_xy..Passed")
      (:id "instr-test-v5-08-ind-x" :path "instr_test-v5/rom_singles/08-ind_x.nes"
       :protocol :blargg :expected 0 :max-frames 600 :state :pass :failure-text "status 0; 08-ind_x..Passed")
      (:id "instr-test-v5-09-ind-y" :path "instr_test-v5/rom_singles/09-ind_y.nes"
       :protocol :blargg :expected 0 :max-frames 600 :state :pass :failure-text "status 0; 09-ind_y..Passed")
      (:id "instr-test-v5-10-branches" :path "instr_test-v5/rom_singles/10-branches.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 10-branches..Passed")
      (:id "instr-test-v5-11-stack" :path "instr_test-v5/rom_singles/11-stack.nes"
       :protocol :blargg :expected 0 :max-frames 600 :state :pass :failure-text "status 0; 11-stack..Passed")
      (:id "instr-test-v5-12-jmp-jsr" :path "instr_test-v5/rom_singles/12-jmp_jsr.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 12-jmp_jsr..Passed")
      (:id "instr-test-v5-13-rts" :path "instr_test-v5/rom_singles/13-rts.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 13-rts..Passed")
      (:id "instr-test-v5-14-rti" :path "instr_test-v5/rom_singles/14-rti.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 14-rti..Passed")
      (:id "instr-test-v5-15-brk" :path "instr_test-v5/rom_singles/15-brk.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 15-brk..Passed")
      (:id "instr-test-v5-16-special" :path "instr_test-v5/rom_singles/16-special.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; 16-special..Passed")
      (:id "instr-misc-01-abs-x-wrap" :path "instr_misc/rom_singles/01-abs_x_wrap.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; Passed")
      (:id "instr-misc-02-branch-wrap" :path "instr_misc/rom_singles/02-branch_wrap.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; Passed")
      (:id "instr-misc-03-dummy-reads" :path "instr_misc/rom_singles/03-dummy_reads.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; Passed")
      (:id "instr-misc-04-dummy-reads-apu" :path "instr_misc/rom_singles/04-dummy_reads_apu.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "instr-timing-01" :path "instr_timing/rom_singles/1-instr_timing.nes"
       :protocol :blargg :expected 0 :max-frames 1500 :state :pass :failure-text "1-instr_timing..Passed")
      (:id "instr-timing-02-branch" :path "instr_timing/rom_singles/2-branch_timing.nes"
       :protocol :blargg :expected 0 :max-frames 1500 :state :pass :failure-text "2-branch_timing..Passed")
      (:id "cpu-interrupts-v2-01-cli" :path "cpu_interrupts_v2/rom_singles/1-cli_latency.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; Passed")
      (:id "cpu-interrupts-v2-02-nmi-brk" :path "cpu_interrupts_v2/rom_singles/2-nmi_and_brk.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "cpu-interrupts-v2-03-nmi-irq" :path "cpu_interrupts_v2/rom_singles/3-nmi_and_irq.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "cpu-interrupts-v2-04-irq-dma" :path "cpu_interrupts_v2/rom_singles/4-irq_and_dma.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "cpu-interrupts-v2-05-branch" :path "cpu_interrupts_v2/rom_singles/5-branch_delays_irq.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "cpu-exec-space-apu" :path "cpu_exec_space/test_cpu_exec_space_apu.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 2")
      (:id "cpu-exec-space-ppuio" :path "cpu_exec_space/test_cpu_exec_space_ppuio.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :pass :failure-text "status 0; Passed")
      (:id "cpu-dummy-reads-subrom" :path "cpu_dummy_reads/cpu_dummy_reads.nes"
       :protocol :ram-result :expected 0 :result-address #x6000
       :max-frames 120 :state :pass
       :failure-text "status $6000; 0 means PASSED")
      (:id "cpu-reset-ram" :path "cpu_reset/ram_after_reset.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")
      (:id "cpu-reset-registers" :path "cpu_reset/registers.nes"
       :protocol :blargg :expected 0 :max-frames 120 :state :known-fail :failure-text "status 128")))
    (:suite "ppu" :category :ppu
     :subroms ((:id "ppu-vbl-nmi" :path "ppu_vbl_nmi/ppu_vbl_nmi.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                 :failure-text "status 128; vbl_set_time failed")
               (:id "ppu-vbl-01" :path "ppu_vbl_nmi/rom_singles/01-vbl_basics.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-02" :path "ppu_vbl_nmi/rom_singles/02-vbl_set_time.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-03" :path "ppu_vbl_nmi/rom_singles/03-vbl_clear_time.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-04" :path "ppu_vbl_nmi/rom_singles/04-nmi_control.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; immediate NMI control timing passed #11")
               (:id "ppu-vbl-05" :path "ppu_vbl_nmi/rom_singles/05-nmi_timing.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-06" :path "ppu_vbl_nmi/rom_singles/06-suppression.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-07" :path "ppu_vbl_nmi/rom_singles/07-nmi_on_timing.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-08" :path "ppu_vbl_nmi/rom_singles/08-nmi_off_timing.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-09" :path "ppu_vbl_nmi/rom_singles/09-even_odd_frames.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :pass
                :failure-text "status 0; measured pass")
               (:id "ppu-vbl-10" :path "ppu_vbl_nmi/rom_singles/10-even_odd_timing.nes"
                :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                :failure-text "status 128; even/odd timing failure")
               (:id "sprite-hit-01" :path "sprite_hit_tests_2005.10.05/01.basics.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED, 2-10 are README failure codes")
               (:id "sprite-hit-02" :path "sprite_hit_tests_2005.10.05/02.alignment.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-03" :path "sprite_hit_tests_2005.10.05/03.corners.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-04" :path "sprite_hit_tests_2005.10.05/04.flip.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-05" :path "sprite_hit_tests_2005.10.05/05.left_clip.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-06" :path "sprite_hit_tests_2005.10.05/06.right_edge.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-07" :path "sprite_hit_tests_2005.10.05/07.screen_bottom.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-08" :path "sprite_hit_tests_2005.10.05/08.double_height.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-09" :path "sprite_hit_tests_2005.10.05/09.timing_basics.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-10" :path "sprite_hit_tests_2005.10.05/10.timing_order.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-hit-11" :path "sprite_hit_tests_2005.10.05/11.edge_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :pass
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-overflow-1" :path "sprite_overflow_tests/1.Basics.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :pass
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-overflow-2" :path "sprite_overflow_tests/2.Details.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :pass
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-overflow-3" :path "sprite_overflow_tests/3.Timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :known-fail
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-overflow-4" :path "sprite_overflow_tests/4.Obscure.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :pass
                :failure-text "result $F8; 1 means PASSED")
               (:id "sprite-overflow-5" :path "sprite_overflow_tests/5.Emulator.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 360 :state :pass
                :failure-text "result $F8; 1 means PASSED")
               (:id "ppu-open-bus" :path "ppu_open_bus/ppu_open_bus.nes"
                :protocol :ram-result :expected 0 :result-address #x6000 :running-value #x80 :max-frames 360 :state :pass
                :failure-text "status $6000; 0 means PASSED")
               (:id "ppu-read-buffer" :path "ppu_read_buffer/test_ppu_read_buffer.nes"
                :protocol :ram-result :expected 0 :result-address #x6000 :running-value #x80 :max-frames 360 :state :known-fail
                :failure-text "status $6000 remains $80 after running marker; ROM did not complete")
               (:id "oam-read" :path "oam_read/oam_read.nes"
                :protocol :ram-result :expected 0 :result-address #x6000 :running-value #x80 :max-frames 360 :state :pass
                :failure-text "status $6000; 0 means PASSED")
               (:id "blargg-ppu-palette-ram" :path "blargg_ppu_tests_2005.09.15b/palette_ram.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 360 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-ppu-power-up-palette" :path "blargg_ppu_tests_2005.09.15b/power_up_palette.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 360 :state :known-fail
                :failure-text "result $F0; power-up palette differs from reference NES")
               (:id "blargg-ppu-sprite-ram" :path "blargg_ppu_tests_2005.09.15b/sprite_ram.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 360 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-ppu-vbl-clear-time" :path "blargg_ppu_tests_2005.09.15b/vbl_clear_time.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 360 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-ppu-vram-access" :path "blargg_ppu_tests_2005.09.15b/vram_access.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 360 :state :pass
                :failure-text "result $F0; 1 means PASSED")))
    (:suite "apu" :category :apu
               :subroms ((:id "apu-test" :path "apu_test/apu_test.nes"
                 :protocol :blargg :expected 0 :max-frames 360 :state :known-fail
                 :failure-text "status 128; #19 one-byte buffer timing; #31 rate 14 timing")
               (:id "apu-dmc-basics" :path "apu_test/rom_singles/7-dmc_basics.nes"
                :protocol :ram-result :expected 0 :result-address #x6000
                :running-value #x80 :max-frames 360 :state :pass
                :failure-text "status 0; DMC test failure code is described in apu_test/readme.txt")
               (:id "apu-dmc-rates" :path "apu_test/rom_singles/8-dmc_rates.nes"
                :protocol :ram-result :expected 0 :result-address #x6000
                :running-value #x80 :max-frames 360 :state :known-fail
                :failure-text "status 0; text reports Rate 14's period is too long (#31)")
               (:id "blargg-apu" :path "blargg_apu_2005.07.30/01.len_ctr.nes"
                 :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                 :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-02" :path "blargg_apu_2005.07.30/02.len_table.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-03" :path "blargg_apu_2005.07.30/03.irq_flag.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-04" :path "blargg_apu_2005.07.30/04.clock_jitter.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-05" :path "blargg_apu_2005.07.30/05.len_timing_mode0.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :known-fail
                :failure-text "result $F0 = 2; length timing mode 0 failed")
               (:id "blargg-apu-06" :path "blargg_apu_2005.07.30/06.len_timing_mode1.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :known-fail
                :failure-text "result $F0 = 2; length timing mode 1 failed")
               (:id "blargg-apu-07" :path "blargg_apu_2005.07.30/07.irq_flag_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-08" :path "blargg_apu_2005.07.30/08.irq_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :known-fail
                :failure-text "result $F0 = 2; IRQ timing failed")
               (:id "blargg-apu-09" :path "blargg_apu_2005.07.30/09.reset_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-10" :path "blargg_apu_2005.07.30/10.len_halt_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :pass
                :failure-text "result $F0; 1 means PASSED")
               (:id "blargg-apu-11" :path "blargg_apu_2005.07.30/11.len_reload_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F0 :max-frames 60 :state :known-fail
                :failure-text "result $F0 = 2; length reload timing case failed")))
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
                 :mapper4-variant :mmc3)
               (:id "mmc3-test-2-details" :path "mmc3_test_2/rom_singles/2-details.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 2-details Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-2-a12" :path "mmc3_test_2/rom_singles/3-A12_clocking.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 3-A12_clocking Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-2-scanline-timing" :path "mmc3_test_2/rom_singles/4-scanline_timing.nes"
                :protocol :blargg :expected 0 :max-frames 120 :state :known-fail
                :failure-text "status 128; Scanline 0 IRQ should occur sooner when $2000=$08"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-2-mmc3" :path "mmc3_test_2/rom_singles/5-MMC3.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 5-MMC3 Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-2-alt" :path "mmc3_test_2/rom_singles/6-MMC3_alt.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 6-MMC3_alt Passed"
                :mapper4-variant :mmc3-alt)
               (:id "mmc3-test-legacy-clocking" :path "mmc3_test/1-clocking.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 1-clocking Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-legacy-details" :path "mmc3_test/2-details.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 2-details Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-legacy-a12" :path "mmc3_test/3-A12_clocking.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 3-A12_clocking Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-legacy-scanline" :path "mmc3_test/4-scanline_timing.nes"
                :protocol :blargg :expected 0 :max-frames 120 :state :known-fail
                :failure-text "status 128; scanline timing IRQ failure"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-legacy-mmc3" :path "mmc3_test/5-MMC3.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :pass
                :failure-text "status 0; 5-MMC3 Passed"
                :mapper4-variant :mmc3)
               (:id "mmc3-test-legacy-mmc6" :path "mmc3_test/6-MMC6.nes"
                :protocol :blargg :expected 0 :max-frames 60 :state :known-fail
                :failure-text "status 128; MMC6 IRQ reload behavior failure"
                :mapper4-variant :mmc6)
               (:id "mmc1-a12" :path "MMC1_A12/mmc1_a12.nes"
                :protocol :mmc1-a12 :expected 1 :max-frames 60 :state :pass
                :failure-text "$6000 remains the WRAM-gate sentinel; zero means the A12 probe completed")
               (:id "mmc3-irq-tests-clocking" :path "mmc3_irq_tests/1.Clocking.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 60 :state :pass
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3)
               (:id "mmc3-irq-tests-details" :path "mmc3_irq_tests/2.Details.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 60 :state :pass
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3)
               (:id "mmc3-irq-tests-a12" :path "mmc3_irq_tests/3.A12_clocking.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 60 :state :known-fail
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3)
               (:id "mmc3-irq-tests-scanline" :path "mmc3_irq_tests/4.Scanline_timing.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 120 :state :pass
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3)
               (:id "mmc3-irq-tests-rev-a" :path "mmc3_irq_tests/5.MMC3_rev_A.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 60 :state :pass
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3-rev-a)
               (:id "mmc3-irq-tests-rev-b" :path "mmc3_irq_tests/6.MMC3_rev_B.nes"
                :protocol :ram-result :expected 1 :result-address #x00F8 :max-frames 60 :state :pass
                :failure-text "result $F8; 1 means PASSED"
                :mapper4-variant :mmc3)))))

(defparameter *accuracy-coin-contract*
  '(:id "accuracy-coin" :category :accuracy-coin :path "AccuracyCoin.nes"
    :protocol :accuracy-coin :expected 146 :max-frames 1200 :state :known-fail
    :failure-text "named result item mismatch"
    :accepted-values (#x01 #x05 #x09 #x0D #x11 #x39 #x41)
    :shared-draw ((:name "PPU Reset Flag" :category :power-on-state
                   :address #x03ff :expected :pass)
                  (:name "CPU RAM" :category :power-on-state
                   :address #x03ff :expected :pass)
                  (:name "CPU Registers" :category :power-on-state
                   :address #x03ff :expected :pass)
                  (:name "PPU RAM" :category :power-on-state
                   :address #x03ff :expected :pass)
                  (:name "PPU Palette RAM" :category :power-on-state
                   :address #x03ff :expected :pass))
    :items nil
    :ratchet-pass-count 86
    :ratchet-pass-items
    ("ROM is not writable" "RAM Mirroring" "PC Wraparound"
     "The Decimal Flag" "The B Flag" "Dummy read cycles" "Dummy write cycles"
     "All NOP instructions" "Absolute Indexed" "Zero Page Indexed" "Indirect"
     "Indirect, X" "Indirect, Y" "Relative" "$03   SLO indirect,X"
     "$07   SLO zeropage" "$0F   SLO absolute" "$13   SLO indirect,Y"
     "$17   SLO zeropage,X" "$1B   SLO absolute,Y" "$1F   SLO absolute,X"
     "$23   RLA indirect,X" "$27   RLA zeropage" "$2F   RLA absolute"
     "$33   RLA indirect,Y" "$37   RLA zeropage,X" "$3B   RLA absolute,Y"
     "$3F   RLA absolute,X" "$43   SRE indirect,X" "$47   SRE zeropage"
     "$4F   SRE absolute" "$53   SRE indirect,Y" "$57   SRE zeropage,X"
     "$5B   SRE absolute,Y" "$5F   SRE absolute,X" "$63   RRA indirect,X"
     "$67   RRA zeropage" "$6F   RRA absolute" "$73   RRA indirect,Y"
     "$77   RRA zeropage,X" "$7B   RRA absolute,Y" "$7F   RRA absolute,X"
     "$83   SAX indirect,X" "$87   SAX zeropage" "$8F   SAX absolute"
     "$97   SAX zeropage,Y" "$A3   LAX indirect,X" "$A7   LAX zeropage"
     "$AF   LAX absolute" "$B3   LAX indirect,Y" "$B7   LAX zeropage,Y"
     "$BF   LAX absolute,Y" "$C3   DCP indirect,X" "$C7   DCP zeropage"
     "$CF   DCP absolute" "$D3   DCP indirect,Y" "$D7   DCP zeropage,X"
     "$DB   DCP absolute,Y" "$DF   DCP absolute,X" "$E3   ISC indirect,X"
     "$E7   ISC zeropage" "$EF   ISC absolute" "$F3   ISC indirect,Y"
     "$F7   ISC zeropage,X" "$FB   ISC absolute,Y" "$FF   ISC absolute,X"
     "$BB   LAE absolute,Y" "$0B   ANC Immediate" "$2B   ANC Immediate"
     "$4B   ASR Immediate" "$6B   ARR Immediate" "$AB   LXA Immediate"
     "$CB   AXS Immediate" "$EB   SBC Immediate" "NMI Overlap IRQ"
     "DMA + Open Bus" "Length Counter" "Length Table" "Frame Counter 5-step"
     "Controller Strobing" "Controller Clocking" "Instruction Timing"
     "Branch Dummy Reads" "JSR Edge Cases" "CHR ROM is not writable"
     "PPU Register Mirroring")))

(defparameter *accuracy-coin-item-specs*
  '((:cpu-behavior "ROM is not writable" #x0405)
    (:cpu-behavior "RAM Mirroring" #x0403)
    (:cpu-behavior "PC Wraparound" #x044d)
    (:cpu-behavior "The Decimal Flag" #x0474)
    (:cpu-behavior "The B Flag" #x0475)
    (:cpu-behavior "Dummy read cycles" #x0406)
    (:cpu-behavior "Dummy write cycles" #x0407)
    (:cpu-behavior "Open Bus" #x0408)
    (:cpu-behavior "All NOP instructions" #x047d)
    (:cpu-instructions "Absolute Indexed" #x046e)
    (:cpu-instructions "Zero Page Indexed" #x046f)
    (:cpu-instructions "Indirect" #x0470)
    (:cpu-instructions "Indirect, X" #x0471)
    (:cpu-instructions "Indirect, Y" #x0472)
    (:cpu-instructions "Relative" #x0473)
    (:unofficial-slo "$03   SLO indirect,X" #x0409)
    (:unofficial-slo "$07   SLO zeropage" #x040a)
    (:unofficial-slo "$0F   SLO absolute" #x040b)
    (:unofficial-slo "$13   SLO indirect,Y" #x040c)
    (:unofficial-slo "$17   SLO zeropage,X" #x040d)
    (:unofficial-slo "$1B   SLO absolute,Y" #x040e)
    (:unofficial-slo "$1F   SLO absolute,X" #x040f)
    (:unofficial-rla "$23   RLA indirect,X" #x0419)
    (:unofficial-rla "$27   RLA zeropage" #x041a)
    (:unofficial-rla "$2F   RLA absolute" #x041b)
    (:unofficial-rla "$33   RLA indirect,Y" #x041c)
    (:unofficial-rla "$37   RLA zeropage,X" #x041d)
    (:unofficial-rla "$3B   RLA absolute,Y" #x041e)
    (:unofficial-rla "$3F   RLA absolute,X" #x041f)
    (:unofficial-sre "$43   SRE indirect,X" #x0420)
    (:unofficial-sre "$47   SRE zeropage" #x047f)
    (:unofficial-sre "$4F   SRE absolute" #x0422)
    (:unofficial-sre "$53   SRE indirect,Y" #x0423)
    (:unofficial-sre "$57   SRE zeropage,X" #x0424)
    (:unofficial-sre "$5B   SRE absolute,Y" #x0425)
    (:unofficial-sre "$5F   SRE absolute,X" #x0426)
    (:unofficial-rra "$63   RRA indirect,X" #x0427)
    (:unofficial-rra "$67   RRA zeropage" #x0428)
    (:unofficial-rra "$6F   RRA absolute" #x0429)
    (:unofficial-rra "$73   RRA indirect,Y" #x042a)
    (:unofficial-rra "$77   RRA zeropage,X" #x042b)
    (:unofficial-rra "$7B   RRA absolute,Y" #x042c)
    (:unofficial-rra "$7F   RRA absolute,X" #x042d)
    (:unofficial-ax "$83   SAX indirect,X" #x042e)
    (:unofficial-ax "$87   SAX zeropage" #x042f)
    (:unofficial-ax "$8F   SAX absolute" #x0430)
    (:unofficial-ax "$97   SAX zeropage,Y" #x0431)
    (:unofficial-ax "$A3   LAX indirect,X" #x0432)
    (:unofficial-ax "$A7   LAX zeropage" #x0433)
    (:unofficial-ax "$AF   LAX absolute" #x0434)
    (:unofficial-ax "$B3   LAX indirect,Y" #x0435)
    (:unofficial-ax "$B7   LAX zeropage,Y" #x0436)
    (:unofficial-ax "$BF   LAX absolute,Y" #x0437)
    (:unofficial-dcp "$C3   DCP indirect,X" #x0438)
    (:unofficial-dcp "$C7   DCP zeropage" #x0439)
    (:unofficial-dcp "$CF   DCP absolute" #x043a)
    (:unofficial-dcp "$D3   DCP indirect,Y" #x043b)
    (:unofficial-dcp "$D7   DCP zeropage,X" #x043c)
    (:unofficial-dcp "$DB   DCP absolute,Y" #x043d)
    (:unofficial-dcp "$DF   DCP absolute,X" #x043e)
    (:unofficial-isc "$E3   ISC indirect,X" #x043f)
    (:unofficial-isc "$E7   ISC zeropage" #x0440)
    (:unofficial-isc "$EF   ISC absolute" #x0441)
    (:unofficial-isc "$F3   ISC indirect,Y" #x0442)
    (:unofficial-isc "$F7   ISC zeropage,X" #x0443)
    (:unofficial-isc "$FB   ISC absolute,Y" #x0444)
    (:unofficial-isc "$FF   ISC absolute,X" #x0445)
    (:unofficial-sh "$93   SHA indirect,Y" #x0446)
    (:unofficial-sh "$9F   SHA absolute,Y" #x0447)
    (:unofficial-sh "$9B   SHS absolute,Y" #x0448)
    (:unofficial-sh "$9C   SHY absolute,X" #x0449)
    (:unofficial-sh "$9E   SHX absolute,Y" #x044a)
    (:unofficial-sh "$BB   LAE absolute,Y" #x044b)
    (:unofficial-immediate "$0B   ANC Immediate" #x0410)
    (:unofficial-immediate "$2B   ANC Immediate" #x0411)
    (:unofficial-immediate "$4B   ASR Immediate" #x0412)
    (:unofficial-immediate "$6B   ARR Immediate" #x0413)
    (:unofficial-immediate "$8B   ANE Immediate" #x0414)
    (:unofficial-immediate "$AB   LXA Immediate" #x0415)
    (:unofficial-immediate "$CB   AXS Immediate" #x0416)
    (:unofficial-immediate "$EB   SBC Immediate" #x0417)
    (:cpu-interrupts "Interrupt flag latency" #x0461)
    (:cpu-interrupts "NMI Overlap BRK" #x0462)
    (:cpu-interrupts "NMI Overlap IRQ" #x0463)
    (:dma "DMA + Open Bus" #x046c)
    (:dma "DMA + $2002 Read" #x0488)
    (:dma "DMA + $2007 Read" #x044c)
    (:dma "DMA + $2007 Write" #x044f)
    (:dma "DMA + $4015 Read" #x045d)
    (:dma "DMA + $4016 Read" #x045e)
    (:dma "DMC DMA Bus Conflicts" #x046b)
    (:dma "DMC DMA + OAM DMA" #x0477)
    (:dma "Explicit DMA Abort" #x0479)
    (:dma "Implicit DMA Abort" #x0478)
    (:apu "Length Counter" #x0465)
    (:apu "Length Table" #x0466)
    (:apu "Frame Counter IRQ" #x0467)
    (:apu "Frame Counter 4-step" #x0468)
    (:apu "Frame Counter 5-step" #x0469)
    (:apu "Delta Modulation Channel" #x046a)
    (:apu "APU Register Activation" #x045c)
    (:apu "Controller Strobing" #x045f)
    (:apu "Controller Clocking" #x047a)
    (:cpu-behavior-2 "Instruction Timing" #x0460)
    (:cpu-behavior-2 "Implied Dummy Reads" #x046d)
    (:cpu-behavior-2 "Branch Dummy Reads" #x048b)
    (:cpu-behavior-2 "JSR Edge Cases" #x047c)
    (:cpu-behavior-2 "Internal Data Bus" #x0490)
    (:ppu "CHR ROM is not writable" #x0485)
    (:ppu "PPU Register Mirroring" #x0404)
    (:ppu "PPU Register Open Bus" #x044e)
    (:ppu "PPU Read Buffer" #x0476)
    (:ppu "Palette RAM Quirks" #x047e)
    (:ppu-vblank "VBlank beginning" #x0450)
    (:ppu-vblank "VBlank end" #x0451)
    (:ppu-vblank "NMI Control" #x0452)
    (:ppu-vblank "NMI Timing" #x0453)
    (:ppu-vblank "NMI Suppression" #x0454)
    (:ppu-vblank "NMI at VBlank end" #x0455)
    (:ppu-vblank "NMI disabled at VBlank" #x0456)
    (:sprite "Sprite overflow behavior" #x0459)
    (:sprite "Sprite 0 Hit behavior" #x0457)
    (:sprite "$2002 flag timing" #x048d)
    (:sprite "Suddenly Resize Sprite" #x0489)
    (:sprite "Misaligned OAM DMA" #x0494)
    (:sprite "Arbitrary Sprite zero" #x0458)
    (:sprite "Misaligned OAM behavior" #x045a)
    (:sprite "OAM Corruption" #x047b)
    (:ppu-misc "t Register Quirks" #x0482)
    (:ppu-misc "Address $2004 behavior" #x045b)
    (:ppu-misc "INC $4014" #x0480)
    (:ppu-misc "Rendering Flag Behavior" #x0486)
    (:ppu-misc "$2007 read w/ rendering" #x048a)
    (:ppu-misc "$2004 Stress Test" #x048c)
    (:ppu-misc "$2007 Stress Test" #x048e)
    (:advanced-bg "Attributes As Tiles" #x0481)
    (:advanced-bg "Stale BG Shift Registers" #x0483)
    (:advanced-bg "BG Serial In" #x0487)
    (:advanced-bg "ALE + Read" #x0491)
    (:advanced-bg "Hybrid Addresses" #x0492)
    (:advanced-sprite "Sprites On Scanline 0" #x0484)
    (:advanced-sprite "Stale Sprite Shift Regs" #x048f)
    (:advanced-sprite "Frozen OAM2 Increment" #x0493)
    (:advanced-sprite "Misaligned OAM2 Address" #x0495)))

(defun accuracy-coin-items ()
  (append
   (list (list :name "reserved Unimplemented" :address #x0400
               :expected :reserved :category :reserved)
         (list :name "reserved CPU Instruction" :address #x0401
               :expected :reserved :category :reserved))
   (loop for (category name address) in *accuracy-coin-item-specs*
         collect (list :name name :address address :expected :pass
                       :category category))))

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
                                   (getf subrom :mapper4-variant)
                                   (getf subrom :result-address)
                                   (getf subrom :running-value)))))

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
                              (getf subrom :mapper4-variant) suite-name
                              (getf subrom :result-address)
                              (getf subrom :running-value)))))

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

(defun run-blargg-contract (path contract)
  (run-blargg-protocol path (rom-contract-max-frames contract)
                       :mapper4-variant
                       (rom-contract-mapper4-variant contract)))

(defun run-ram-result-contract (path contract)
  (run-ram-result-protocol path (rom-contract-max-frames contract)
                           (rom-contract-result-address contract)
                           (rom-contract-expected contract)
                           :mapper4-variant
                           (rom-contract-mapper4-variant contract)
                           :running-value
                           (rom-contract-running-value contract)))

(defun run-text-progress-contract (path contract)
  (run-text-progress-protocol path (rom-contract-max-frames contract)
                              (rom-contract-expected contract)
                              :mapper4-variant
                              (rom-contract-mapper4-variant contract)))

(defun mmc1-a12-tile-map (tile)
  (cond ((<= #x10 tile #x19) (code-char (+ (char-code #\0) (- tile #x10))))
        ((<= #x20 tile #x39) (code-char (+ (char-code #\A) (- tile #x20))))
        ((= tile #x1c) #\=)
        ((= tile #x1e) #\?)
        ((= tile #x1f) #\ )
        ((= tile #x3b) #\/)))

(defun run-nametable-text-contract (path contract)
  (run-nametable-text-protocol path (rom-contract-max-frames contract)
                                (rom-contract-expected contract)
                                :start #x2000 :tile-map #'mmc1-a12-tile-map))

(defun run-mmc1-a12-contract (path contract)
  (run-mmc1-a12-protocol path (rom-contract-max-frames contract)))

(defun accuracy-result-kind (value)
  (cond
    ((and (oddp value) (/= value 3)) :pass)
    ((= value #xff) :skipped)
    ((= value 3) :running)
    ((and (= (logand value 3) 2) (>= value 2)) :fail)
    (t :fail)))

(defun run-accuracy-coin (path contract)
  (let* ((protocol-result
           (cl-nes:run-accuracy-coin-protocol path (getf contract :max-frames)))
         (results (getf protocol-result :results))
         (shared-draw (getf protocol-result :shared-draw)))
    (let* ((items (loop for item in (getf contract :items)
                        for address = (getf item :address)
                        for value = (if (= address #x03FF)
                                        shared-draw
                                        (nth (- address #x0400) results))
                        for kind = (if (eq (getf item :expected) :reserved)
                                       :reserved
                                       (accuracy-result-kind value))
                        collect (list :name (getf item :name)
                                      :address address :value value :kind kind
                                      :expected (getf item :expected)
                                      :category (getf item :category))))
           (shared-draw-items
             (loop for item in (getf contract :shared-draw)
                   for value = shared-draw
                   collect (list :name (getf item :name)
                                 :address (getf item :address) :value value
                                 :kind (accuracy-result-kind value)
                                 :expected (getf item :expected)
                                 :category (getf item :category))))
           (pass-count (count :pass items :key (lambda (item) (getf item :kind))))
           (fail-count (count :fail items :key (lambda (item) (getf item :kind))))
           (skip-count (count :skipped items :key (lambda (item) (getf item :kind))))
           (running-count (count :running items :key (lambda (item) (getf item :kind))))
           (completed-count (+ pass-count fail-count))
           (category-pass-counts
             (loop with categories = nil
                   for item in items
                   for category = (getf item :category)
                   when category
                     do (let ((entry (assoc category categories)))
                          (if entry
                              (when (eq (getf item :kind) :pass)
                                (incf (cdr entry)))
                              (push (cons category
                                           (if (eq (getf item :kind) :pass) 1 0))
                                    categories)))
                   finally (return (nreverse categories)))))
      (list :passed (every (lambda (item)
                             (eq (getf item :kind) (getf item :expected)))
                           items)
            :pass-count pass-count :total (getf contract :expected)
            :fail-count fail-count :skip-count skip-count
            :running-count running-count :completed-count completed-count
            :category-pass-counts category-pass-counts
            :frames (getf protocol-result :frames)
            :items items :shared-draw-items shared-draw-items
            :results results))))
