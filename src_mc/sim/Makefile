# Run from anywhere: make -C src_mc/sim smoke
SIM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MC_DIR := $(abspath $(SIM_DIR)/..)
BUILD_DIR ?= /tmp/mc_axi_smoke
RTL := $(wildcard $(MC_DIR)/rtl/*.sv)
TB := $(MC_DIR)/tb/tb_mc_axi_smoke.sv
TOP := tb_mc_axi_smoke

.PHONY: smoke questa-smoke
smoke: $(BUILD_DIR)/obj/V$(TOP)
	cd $(BUILD_DIR) && ./obj/V$(TOP)
	@echo "Waveform: $(BUILD_DIR)/mc_axi_smoke.vcd"

$(BUILD_DIR)/obj/V$(TOP): $(RTL) $(TB) $(SIM_DIR)/Makefile
	mkdir -p $(BUILD_DIR)
	verilator --binary --timing --assert --trace --trace-depth 2 -Wno-fatal \
		--top-module $(TOP) -j 4 --Mdir $(BUILD_DIR)/obj $(RTL) $(TB)

questa-smoke:
	mkdir -p $(BUILD_DIR)/questa
	cd $(BUILD_DIR)/questa && vlib work
	cd $(BUILD_DIR)/questa && vlog -sv -work work $(RTL) $(TB)
	cd $(BUILD_DIR)/questa && vsim -c -voptargs=+acc work.$(TOP) \
		-do 'onerror {quit -code 1}; onbreak {quit -code 1}; do {$(SIM_DIR)mc_axi_smoke_wave.do}; run -all; quit -code 0'
	@echo "Waveform: $(BUILD_DIR)/questa/mc_axi_smoke.vcd"
