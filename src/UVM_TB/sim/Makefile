# Vivado tools
XVLOG := /cygdrive/E/2025.2/Vivado/bin/xvlog
XELAB := /cygdrive/E/2025.2/Vivado/bin/xelab
XSIM  := /cygdrive/E/2025.2/Vivado/bin/xsim

# Base directories
RTL_DIR    := D:/axfdi_bridge_verification/rtl
TB_DIR     := D:/axfdi_bridge_verification/tb
TEST_DIR   := D:/axfdi_bridge_verification/test
WORK_DIR   := work
LOG_DIR    := logs

# Files
RTL_FILES := $(wildcard $(RTL_DIR)/*.sv)
PKG_FILE  := $(TEST_DIR)/axfdi_pkg.sv
TOP_FILE  := $(TB_DIR)/axfdi_top.sv

TOP := axfdi_bridge_tb
UVM_TEST ?= axfdi_test

UVM_XVLOG_FLAGS := --sv -d SIMULATION --incr --relax -L uvm \
                   -i $(TB_DIR) -i $(TEST_DIR) \
                   -i E:/2025.2/Vivado/data/systemverilog/uvm/src

UVM_XELAB_FLAGS := --incr --debug typical --relax --mt auto -L uvm

all: uvm_vivado

clean:
	rm -rf xsim.dir *.log *.jou *.pb $(WORK_DIR) $(LOG_DIR)

uvm_vivado:
	@mkdir -p $(WORK_DIR) $(LOG_DIR)
	@echo "=== Compiling RTL ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(RTL_FILES)
	@echo "=== Compiling UVM package (includes agents/env/test) ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(PKG_FILE)
	@echo "=== Compiling Top TB ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(TOP_FILE)
	@echo "=== Elaborating with xelab ==="
	cd $(WORK_DIR) && $(XELAB) $(UVM_XELAB_FLAGS) -top $(TOP) -snapshot sar_adc_uvm_sim
	@echo "=== Running UVM test: $(UVM_TEST) ==="
	cd $(WORK_DIR) && $(XSIM) sar_adc_uvm_sim --runall 
	    +UVM_TESTNAME=$(UVM_TEST)
		+UVM_VERBOSITY=UVM_MEDIUM | tee ../$(LOG_DIR)/uvm_vivado_sim.log