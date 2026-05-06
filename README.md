# Busbridges

## AXI to FDI Bridge
The AXFDI bridge is defined to connect the AXI interface with the FDI interface
The specification about the implementation can be found: [AXI-FDI SPEC](https://github.com/sevyamm/Busbridges/blob/master/docs/AXI-FDI%20Bridge%20%E2%80%94%20Project%20SpecificationV2.pdf) defines AXI-to-FDI Bridge  

## Block Diagram:
The design supports bi-directional data flow between the AXI and FDI interface. 

### Block Diagram:
![Block Diagram](https://github.com/sevyamm/Busbridges/blob/master/docs/Block_Diagram.png)

## Repository Layout

- `docs/` contains the project specification PDF and architecture collateral referenced above.
- `src/rtl/` contains the synthesizable AXI-to-FDI bridge RTL, including the top-level bridge, clock-domain crossing FIFOs, packetization/depacketization logic, credit handling, and AXI manager/subordinate side adapters.
- `src/UVM_TB/` contains the UVM verification environment for the bridge, including agents, sequences, virtual sequences, tests, and simulation makefiles.
- `review_meeting/` contains review notes captured during project checkpoints.

Additional directory-specific notes are available in:

- [`src/rtl/README.md`](src/rtl/README.md)
- [`src/UVM_TB/README.md`](src/UVM_TB/README.md)

## RTL Notes

The main bridge implementation is `src/rtl/axfdi_bridge.sv`. The current top-level wiring shows:

- two AXI subordinate-side ports feeding the bridge,
- two AXI manager-side ports driven by the bridge,
- one FDI link interface,
- dedicated CDC FIFOs between the AXI and FDI clock domains,
- internal blocks for credit management, completion tracking, routing, arbitration, packetization, and depacketization.

The RTL file list used for compilation is maintained in `src/rtl/axfdi_bridge.f`.

## Verification Notes

The UVM testbench top is `src/UVM_TB/tb/axfdi_top.sv`, which instantiates the RTL bridge and connects:

- 2 AXI subordinate interfaces,
- 2 AXI manager interfaces,
- 1 FDI interface,
- 1 APB interface,
- 1 reset interface.

The UVM environment is organized around:

- AXI, FDI, and APB agents,
- a virtual sequencer for cross-agent coordination,
- a scoreboard composed of a predictor and comparator,
- directed tests and regressions driven through the `sim/Makefile`.

## Simulation Notes

The current simulation flow in `src/UVM_TB/sim/Makefile` is based on Vivado `xvlog`, `xelab`, and `xsim`.

- Default single-test run: `UVM_TEST=single_read_test`
- Default regression list: `single_read_test single_write_test fdi_data_test`

The make targets currently use Windows-style absolute paths for both the Vivado installation and the repository location, so they may need to be adjusted before running in a different environment.
<!--
> **Note:**  
> This repository contains the AXFDI bridge source code, developed by **Sevya Multimedia Technologies**.  
  >> Contributors:  
  >>Pavan Kammili (pavan.kammili@sevyamm.com)  
  >>Raja Ramagani (raja.ramagani@sevyamm.com)  
  >>Yesaswini Bedadhuru (yesaswini.bedadhuru@sevyamm.com)  
  >>Vishwa Patwari (vishwa.patwari@sevyamm.com)  
  >>Shivasai Tatipalli (shivasai.tatipalli@sevyamm.com)  
  >> Aravind P S  (aravind.prasannanpillai@sevyamm.com)  
-->
