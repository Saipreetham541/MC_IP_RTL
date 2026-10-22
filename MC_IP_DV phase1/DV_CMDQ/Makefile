# =============================================================================
#  Makefile for MC16X2 CMDQ UVM Verification (4 Tests Available)
#  - Type 'make' to run the test specified in mc_top.sv (run_test("..."))
#  - Or override from terminal:
#      make TEST=test_cmdq_fill
#      make TEST=test_cmdq_overflow
#      make TEST=test_cmdq_data_integrity_pop
#      make TEST=test_cmdq_boundary_empty_full
#  - Type 'make clean' to remove generated simulation files
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
