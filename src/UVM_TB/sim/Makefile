# ================================
# Vivado Tool Paths (Pavan)
# ================================
XVLOG := /cygdrive/E/2025.2/Vivado/bin/xvlog
XELAB := /cygdrive/E/2025.2/Vivado/bin/xelab
XSIM  := /cygdrive/E/2025.2/Vivado/bin/xsim
SNAPSHOT_NAME := uvm_sim_snapshot

# ================================
# Directories
# ================================
INTERFACE_DIR := D:/Busbridges/src/UVM_TB/interfaces
RTL_DIR       := D:/Busbridges/src/rtl
TB_DIR        := D:/Busbridges/src/UVM_TB/tb
TEST_DIR      := D:/Busbridges/src/UVM_TB/test
V_SEQS_DIR    := D:/Busbridges/src/UVM_TB/virtual_seqs
SEQS_DIR      := D:/Busbridges/src/UVM_TB/sequences

WORK_DIR := work
LOG_DIR  := logs

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

UVM_TEST ?= axfdi_test

# ================================
# Create folders
# ================================
setup:
	mkdir -p $(WORK_DIR)
	mkdir -p $(LOG_DIR)

# ================================
# Compile
# ================================

compile: setup
	@echo "=== Compiling Files ==="
	$(XVLOG) --sv \
	-L uvm \
	-i D:/Busbridges/src/UVM_TB/apb_agent \
	-i D:/Busbridges/src/UVM_TB/axi_agent \
	-i D:/Busbridges/src/UVM_TB/fdi_agent \
	-i D:/Busbridges/src/UVM_TB/test \
	-i D:/Busbridges/src/UVM_TB/tb \
	-i D:/Busbridges/src/UVM_TB/sequences \
	-i D:/Busbridges/src/UVM_TB/virtual_seqs \
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
	$(XSIM) -runall $(SNAPSHOT_NAME) -log $(LOG_DIR)/sim.log
	
	
gui: elab
	$(XSIM) $(SNAPSHOT_NAME) --gui
	
	
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