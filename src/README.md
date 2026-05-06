# Source Directory

This directory contains the source code for the AXI-FDI bridge project, along with supporting testbench, simulation, and local test collateral.

## Subdirectories

- `rtl/`: synthesizable RTL for the AXI-FDI bridge and its internal building blocks.
- `UVM_TB/`: UVM verification environment, including agents, sequences, tests, interfaces, and simulation scripts.
- `tb/`: standalone or module-level testbenches and waveform `.do` files used for focused validation.
- `dummy_tops/`: simple top-level wrapper or bring-up files used for local experiments and debug.
- `sim_dir/`: simulation working area containing makefiles, logs, generated databases, and tool outputs.

## Notes

- The main design implementation is under `rtl/`.
- The main verification environment is under `UVM_TB/`.
- Additional directory-specific notes are available in:
  - [`rtl/README.md`](rtl/README.md)
  - [`UVM_TB/README.md`](UVM_TB/README.md)
