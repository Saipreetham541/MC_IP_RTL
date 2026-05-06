>## This Directory contains UVM for AXIFDI Bridge

## Overview

This directory contains the UVM verification environment for the AXI-FDI bridge RTL in `src/rtl/`. It includes reusable AXI, FDI, and APB agents, protocol   interfaces, directed sequences, virtual sequences, scoreboard/predictor/comparator infrastructure, testcases, and Vivado XSim makefile-based simulation support.

## Directory Structure

- `interfaces/`: SystemVerilog interfaces for AXI manager, AXI subordinate, FDI, APB, and reset connectivity.
- `axi_agent/`: AXI sequence item, config, driver, monitor, sequencer, coverage, and agent implementation for both manager and subordinate roles.
- `fdi_agent/`: FDI packet item, config, driver, monitor, sequencer, sequences, coverage, and a local credit model.
- `apb_agent/`: APB-side verification scaffolding with config, transaction, driver, monitor, sequencer, sequences, and agent.
- `tb/`: environment, environment config, scoreboard, predictor, comparator, virtual sequencer, and the simulation top module.
- `sequences/`: leaf AXI and FDI sequences used to generate directed traffic and protocol corner cases.
- `virtual_seqs/`: virtual sequences that coordinate AXI-side and FDI-side stimulus across the environment.
- `test/`: package file, base test, and derived UVM tests.
- `sim/`: Makefile-based compile, elaborate, run, GUI, and regression flow.
- `test_results/`: saved log files from sample simulations.

## Environment Notes

The simulation top is `tb/axfdi_top.sv`. It instantiates:

- `axfdi_bridge` as the DUT,
- 2 AXI subordinate interfaces,
- 2 AXI manager interfaces,
- 1 FDI interface,
- 1 APB interface,
- 1 reset interface.

The current top also generates clocks directly in the testbench:

- AXI clock: `always #1.0 axi_clk = ~axi_clk;`
- FDI clock: `always #0.8 fdi_clk = ~fdi_clk;`
- APB clock: `always #2.5 apb_clk = ~apb_clk;`

The base test `test/axfdi_test.sv` builds:

- 2 AXI agents,
- 1 FDI agent,
- 1 APB agent,
- 1 environment config object,
- 1 scoreboard-backed environment.

The environment `tb/axfdi_env.sv` connects monitor outputs into `tb/axfdi_scoreboard.sv`, where:

- the predictor models expected AXI/FDI behavior,
- the comparator checks actual traffic against the expected transactions,
- virtual sequencers coordinate cross-interface stimulus.

## Tests And Sequences

The repository currently contains directed tests for:

- single AXI read flow,
- single AXI write flow,
- FDI-to-AXI data flow,
- credit starvation and back-pressure scenarios,
- inline and standalone credit return scenarios,
- mixed read/write sequencing.

Note that `test/axfdi_pkg.sv` currently includes only a subset of the available tests and virtual sequences by default. At the moment, the package directly includes:

- `single_read_test`
- `single_write_test`
- `fdi_data_test`

Several other tests and sequences are present in the tree but commented out in the package file, so enabling them in the normal build flow may require uncommenting or otherwise integrating them into `axfdi_pkg.sv`.

## Simulation Flow

The active simulation flow is in `sim/Makefile` and uses Vivado tools:

- `xvlog` for compilation,
- `xelab` for elaboration,
- `xsim` for simulation.

Important current defaults:

- `UVM_TEST ?= single_read_test`
- `REG_TESTS ?= single_read_test single_write_test fdi_data_test`
- `TOP := axfdi_bridge_tb`

Useful targets:

- `make compile`
- `make elab`
- `make run UVM_TEST=single_write_test`
- `make gui UVM_TEST=fdi_data_test`
- `make regression`
- `make clean`

## Path And Portability Notes

The checked-in Makefile currently uses Windows-style absolute paths for:

- the Vivado installation location,
- the repository source directories used as include paths.

If this testbench is moved to another machine or run from Linux, those path variables in `sim/Makefile` will need to be updated before the flow will run as-is.
