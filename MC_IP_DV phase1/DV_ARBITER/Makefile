# =============================================================================
#  Makefile for Credit-Counter Arbiter (mc_arbiter) UVM Verification
#  -----------------------------------------------------------------------------
#  Available Tests:
#      make TEST=test_arbiter_highest_ctr_wins
#      make TEST=test_arbiter_ctr_reset_on_grant
#      make TEST=test_arbiter_saturation_255
#      make TEST=test_arbiter_tie_breaker_idx
#
#  Default: Type 'make' to run the test specified in mc_top.sv
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
