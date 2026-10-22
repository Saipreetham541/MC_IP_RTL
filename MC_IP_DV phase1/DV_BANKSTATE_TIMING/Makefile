# =============================================================================
#  Makefile for MC16X2 HBM3 Memory Controller IP (mc_pc_core)
#  Feature 3: Bank State and Timing Legality Verification
#  -----------------------------------------------------------------------------
#  Available Tests:
#      make TEST=t_p1_timing_tRCD_block         (or test_timing_trcd_block)
#      make TEST=t_p1_timing_legal_boundary     (or test_timing_legal_boundary)
#      make TEST=t_p1_timing_bank_independence  (or test_timing_bank_independence)
#
#  Default: Type 'make' to run the default test specified in mc_top.sv
#           Type 'make clean' to remove generated simulation files
# =============================================================================

UVM_HOME ?= C:/questasim64_2024.1/verilog_src/uvm-1.1d/src

# If TEST is passed on the command line, use +UVM_TESTNAME.
# Otherwise, leave it empty so the test specified in mc_top.sv is used!
ifdef TEST
    UVM_TEST_ARG = +UVM_TESTNAME=$(TEST)
else
    UVM_TEST_ARG =
endif

all: compile run

compile:
	vlib work
	vlog -sv -mfcu +incdir+$(UVM_HOME) -f filelist.f

run:
	vsim -c -do "run -all; quit" mc_top $(UVM_TEST_ARG)

clean:
	rm -rf work transcript dump.vcd *.log *.wlf vsim.wlf _opt
