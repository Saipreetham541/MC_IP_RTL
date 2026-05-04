# ================================
# Vivado Tool Paths (Pavan)
# ================================
#XVLOG := /cygdrive/E/2025.2/Vivado/bin/xvlog
#XELAB := /cygdrive/E/2025.2/Vivado/bin/xelab
#XSIM  := /cygdrive/E/2025.2/Vivado/bin/xsim
#SNAPSHOT_NAME := uvm_sim_snapshot

# ================================
# Vivado Tool Paths (shiva)
# ================================
XVLOG := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xvlog
XELAB := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xelab
XSIM  := /cygdrive/c/AMDDesignTools/2025.2/Vivado/bin/xsim
SNAPSHOT_NAME := uvm_sim_snapshot

# ================================
# Directories path (pavan)
# ================================
#INTERFACE_DIR := D:/Busbridges/src/UVM_TB/interfaces
#RTL_DIR       := D:/Busbridges/src/rtl
#TB_DIR        := D:/Busbridges/src/UVM_TB/tb
#TEST_DIR      := D:/Busbridges/src/UVM_TB/test
#V_SEQS_DIR    := D:/Busbridges/src/UVM_TB/virtual_seqs
#SEQS_DIR      := D:/Busbridges/src/UVM_TB/sequences

# ================================
# Directories path (shiva)
# ================================
INTERFACE_DIR := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/interfaces
RTL_DIR       := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/rtl
TB_DIR        := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/tb
TEST_DIR      := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/test
V_SEQS_DIR    := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/virtual_seqs
SEQS_DIR      := D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/sequences


WORK_DIR := work
LOG_DIR  := logs
REG_SUMMARY := regression_summary.log

# ================================
# Files
# ================================
INTERFACE_FILES := $(wildcard $(INTERFACE_DIR)/*.sv)
RTL_FILES       := $(wildcard $(RTL_DIR)/*.sv)
SEQ_FILES       := $(wildcard $(SEQS_DIR)/*.sv)
VSEQ_FILES      := $(wildcard $(V_SEQS_DIR)/*.sv)

PKG_FILE := $(TEST_DIR)/axfdi_pkg.sv
TOP_FILE := $(TB_DIR)/axfdi_top.sv

TOP := axfdi_bridge_tb

UVM_TEST ?= single_read_test
REG_TESTS ?= single_read_test single_write_test fdi_data_test

# ================================
# Create folders
# ================================
setup:
	mkdir -p $(WORK_DIR)
	mkdir -p $(LOG_DIR)

# ================================
# Compile (pavan)
# ================================

#compile: setup
#	@echo "=== Compiling Files ==="
#	$(XVLOG) --sv \
#	-L uvm \
#	-i D:/Busbridges/src/UVM_TB/apb_agent \
#	-i D:/Busbridges/src/UVM_TB/axi_agent \
#	-i D:/Busbridges/src/UVM_TB/fdi_agent \
#	-i D:/Busbridges/src/UVM_TB/test \
#	-i D:/Busbridges/src/UVM_TB/tb \
#	-i D:/Busbridges/src/UVM_TB/sequences \
#	-i D:/Busbridges/src/UVM_TB/virtual_seqs \
#	$(INTERFACE_FILES) \
#	$(RTL_FILES) \
#	$(PKG_FILE) \
#	$(TOP_FILE) \
#	--log $(LOG_DIR)/compile.log


# ================================
# Compile (shiva)
# ================================

compile: setup
	@echo "=== Compiling Files ==="
	$(XVLOG) --sv \
	-L uvm \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/apb_agent \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/axi_agent \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/fdi_agent \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/test \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/tb \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/sequences \
	-i D:/vlsi/SEVYA/AXI-FDI/Busbridges/src/UVM_TB/virtual_seqs \
	$(INTERFACE_FILES) \
	$(RTL_FILES) \
	$(PKG_FILE) \
	$(TOP_FILE) \
	--log $(LOG_DIR)/compile.log

# ================================
# Elaborate
# ================================
elab: compile
	@echo "=== Elaborating ==="
	$(XELAB) $(TOP) \
	--debug typical \
	-L uvm \
	--snapshot $(SNAPSHOT_NAME) \
	--log $(LOG_DIR)/elab.log

# ================================
# Run Simulation
# ================================

run: elab
	@echo "=== Running UVM Test: $(UVM_TEST) ==="
	@args_file=.xsim_$(UVM_TEST).args; \
	sim_log=$(UVM_TEST).log; \
	rm -f $$args_file $$sim_log; \
	printf '%s\n' \
		'--runall' \
		'$(SNAPSHOT_NAME)' \
		'--testplusarg' \
		'UVM_TESTNAME=$(UVM_TEST)' \
		'--log' \
		"$$sim_log" > $$args_file; \
	$(XSIM) --file $$args_file; \
	status=$$?; \
	rm -f $$args_file; \
	exit $$status
	
	
gui: elab
	@args_file=.xsim_gui_$(UVM_TEST).args; \
	rm -f $$args_file; \
	printf '%s\n' \
		'$(SNAPSHOT_NAME)' \
		'--gui' \
		'--testplusarg' \
		'UVM_TESTNAME=$(UVM_TEST)' > $$args_file; \
	$(XSIM) --file $$args_file; \
	status=$$?; \
	rm -f $$args_file; \
	exit $$status


# ================================
# Regression
# ================================
regression: elab
	@echo "=== Running Regression ==="
	rm -f $(REG_SUMMARY)
	@status=0; \
	for test in $(REG_TESTS); do \
		args_file=".xsim_$$test.args"; \
		sim_log="$$test.log"; \
		log_file="$$test.log"; \
		rm -f $$args_file $$sim_log; \
		printf '%s\n' \
			'--runall' \
			'$(SNAPSHOT_NAME)' \
			'--testplusarg' \
			"UVM_TESTNAME=$$test" \
			'--log' \
			"$$sim_log" > $$args_file; \
		echo "=== Running UVM Test: $$test ==="; \
		$(XSIM) --file $$args_file; \
		xsim_status=$$?; \
		rm -f $$args_file; \
		if [ $$xsim_status -ne 0 ]; then \
			result="$$test : FAIL (xsim error, check $$log_file)"; \
			status=1; \
		elif [ ! -f "$$log_file" ]; then \
			result="$$test : FAIL (log missing)"; \
			status=1; \
		elif grep -Eq "UVM_ERROR :[[:space:]]*0" "$$log_file" && grep -Eq "UVM_FATAL :[[:space:]]*0" "$$log_file"; then \
			result="$$test : PASS"; \
		else \
			result="$$test : FAIL (check $$log_file)"; \
			status=1; \
		fi; \
		echo "$$result"; \
		echo "$$result" >> $(REG_SUMMARY); \
	done; \
	exit $$status
	
	
# ================================
# Full Flow
# ================================
all: compile elab run

# ================================
# Clean
# ================================
clean:
	rm -rf $(WORK_DIR)
	rm -rf $(LOG_DIR)
	rm -rf xsim.dir
	rm -rf *.jou
	rm -rf *.pb

.PHONY: setup compile elab run gui regression all clean
