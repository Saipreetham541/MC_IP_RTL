# Vivado tools pavan path
#XVLOG := /cygdrive/E/2025.2/Vivado/bin/xvlog
#XELAB := /cygdrive/E/2025.2/Vivado/bin/xelab
#XSIM  := /cygdrive/E/2025.2/Vivado/bin/xsim

# Vivado tools shivasai path
XVLOG := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xvlog
XELAB := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xelab
XSIM  := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xsim

# Base directories pavan path
#INTERFACE_DIR := D:/Busbridges/src/UVM_TB/interfaces
#RTL_DIR    := D:/Busbridges/src/rtl
#TB_DIR     := D:/Busbridges/src/UVM_TB/tb
#TEST_DIR   := D:/Busbridges/src/UVM_TB/test
#V_SEQS_DIR := D:/Busbridges/src/UVM_TB/virtual_seqs
#SEQS_DIR   := D:/Busbridges/src/UVM_TB/sequences
#WORK_DIR   := work
#LOG_DIR    := logs

# Base directories shivasai path
INTERFACE_DIR := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/interfaces
RTL_DIR    	  := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/rtl
TB_DIR     	  := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/tb
TEST_DIR   	  := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/test
V_SEQS_DIR 	  := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/virtual_seqs
SEQS_DIR   	  := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/sequences
WORK_DIR   	  := work
LOG_DIR    	  := logs

# Files
INTERFACE_FILES := $(wildcard $(INTERFACE_DIR)/*.sv)
RTL_FILES := $(wildcard $(RTL_DIR)/*.sv)
PKG_FILE  := $(TEST_DIR)/axfdi_pkg.sv
TOP_FILE  := $(TB_DIR)/axfdi_top.sv

TOP := axfdi_bridge_tb
UVM_TEST ?= axfdi_test

UVM_XVLOG_FLAGS := --sv -d SIMULATION --incr --relax -L uvm \
                    -i $(TB_DIR) -i $(TEST_DIR) -i $(V_SEQS_DIR) -i $(SEQS_DIR) \
                   -i E:/2025.2/Vivado/data/systemverilog/uvm/src

UVM_XELAB_FLAGS := --incr --debug typical --relax --mt auto -L uvm

all: uvm_vivado

clean:
	rm -rf xsim.dir *.log *.jou *.pb $(WORK_DIR) $(LOG_DIR)

uvm_vivado:
	@mkdir -p $(WORK_DIR) $(LOG_DIR)
	@echo "=== Compiling RTL ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(RTL_FILES)
	@echo "=== Compiling INTERFACE ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(INTERFACE_FILES)
	@echo "=== Compiling UVM package (includes agents/env/test) ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(PKG_FILE)
	@echo "=== Compiling Top TB ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(TOP_FILE)
	@echo "=== Elaborating with xelab ==="
	cd $(WORK_DIR) && $(XELAB) $(UVM_XELAB_FLAGS) -top $(TOP) -snapshot axfdi_uvm_sim
	@echo "=== Running UVM test: $(UVM_TEST) ==="
	cd $(WORK_DIR) && $(XSIM) axfdi_uvm_sim --runall
	+UVM_TESTNAME=$(UVM_TEST) /
	+UVM_VERBOSITY=UVM_MEDIUM /
	--log vivado_sim.log
		
# Vivado GUI
vivado_gui: 
	@mkdir -p $(WORK_DIR) $(LOG_DIR)

	@echo "=== Compiling RTL ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(RTL_FILES)

	@echo "=== Compiling UVM package ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(PKG_FILE)

	@echo "=== Compiling Top TB ==="
	cd $(WORK_DIR) && $(XVLOG) $(UVM_XVLOG_FLAGS) $(TOP_FILE)

	@echo "=== Elaborating ==="
	cd $(WORK_DIR) && $(XELAB) $(UVM_XELAB_FLAGS) \
	    -top $(TOP) \
	    -snapshot axfdi_uvm_sim

	@echo "=== Launching GUI ==="
	cd $(WORK_DIR) && $(XSIM) axfdi_uvm_sim --gui &

Ex_test1: 
	$(MAKE) uvm_vivado UVM_TEST=test_case1