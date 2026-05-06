# Busbridges

## AXI to FDI Bridge
The AXFDI bridge is defined to connect the AXI interface with the FDI interface
The specification about the implementation can be found: [AXI-FDI SPEC](https://github.com/sevyamm/Busbridges/blob/master/docs/AXI-FDI%20Bridge%20%E2%80%94%20Project%20SpecificationV2.pdf) defines AXI-to-FDI Bridge  

## Project Description

According to the project specification in `docs/`, `AXFDI_BRIDGE` is a fully symmetric, bidirectional protocol-conversion IP that connects the local SoC AXI4 Full fabric to a UCIe 2.0 Flex Die Interface (FDI) mainband link. The same bridge instance is intended to be used on both dies of a chiplet link, so traffic can move in either direction using the same architectural model.

At the system level, the bridge has three main jobs:

- accept AXI4 Full requests from the local die through two AXI subordinate-side ports,
- packetize those requests and responses into UCIe Streaming Format 6 flits for die-to-die transport over FDI,
- receive remote flits, depacketize them, and issue the corresponding AXI4 Full transactions into the local die through two AXI manager-side ports.

The specification defines the bridge as the protocol boundary between:

- a local AXI domain running at `500 MHz`,
- an FDI mainband domain running at `625 MHz`,
- an APB sideband / CSR control domain running asynchronously at up to `200 MHz`.

This makes the bridge important for chiplet-based systems because it allows a design to extend AXI transactions across dies without pushing AXI itself directly across the physical die-to-die boundary. Instead, AXI semantics are preserved locally while the inter-die path uses a transport-friendly flit format, credit-based flow control, and explicit clock-domain crossing.

The spec also highlights why this block matters architecturally:

- it isolates the SoC-facing AXI protocol from the UCIe adapter/PHY-facing FDI transport layer,
- it provides a reusable symmetric bridge that can be instantiated on both dies,
- it supports packetization, depacketization, completion tracking, and credit return in hardware,
- it places all major CDC crossings at the AXI boundary rather than scattering them across the datapath,
- it provides bandwidth headroom, since the spec targets `128 GB/s` aggregate AXI bandwidth against `160 GB/s` peak FDI bandwidth per direction.

In scope, per the spec, are the AXI subordinate and manager interfaces, the FDI mainband transport, APB-accessible CSR control, packetization/depacketization, credit management, CDC, and protocol/error handling. Out of scope are the UCIe PHY, the lower UCIe adapter behavior below the FDI boundary, cache coherency protocols, and retransmission logic.

## Block Diagram:
The design supports bi-directional data flow between the AXI and FDI interface. 

### Block Diagram:
![Block Diagram](https://github.com/sevyamm/Busbridges/blob/master/docs/Block_Diagram.png)

## AXI Interface Overview

AXI in this project refers to ARM AMBA AXI4 Full, which is the local memory-mapped transaction protocol used by the SoC fabric. In the spec, the bridge exposes:

- `AXFSUB[0]` and `AXFSUB[1]`: subordinate-side ports that accept requests from local SoC masters,
- `AXFMGR[0]` and `AXFMGR[1]`: manager-side ports that issue remote-originated requests into the local SoC fabric.

The spec-defined AXI interface characteristics are:

- data width: `1024 bits` (`128 bytes` per beat),
- address width: `40 bits`,
- AXI ID width: `8 bits`,
- clock: `axi_clk` at `500 MHz`,
- bursts: `INCR` and `WRAP` supported, `FIXED` accepted and mapped internally to `INCR`,
- byte enables: `WSTRB[127:0]` fully supported,
- outstanding transactions: up to `256` per port,
- QoS: `AWQOS/ARQOS` used by the spec to select the FDI virtual channel,
- unsupported features in the spec: exclusive accesses and locked transactions.

### AXI Signal Groups

The AXI-side signals are organized into the standard five channels:

- `AW` write address channel: `awaddr`, `awid`, `awlen`, `awsize`, `awburst`, `awvalid`, `awready`
- `W` write data channel: `wdata`, `wstrb`, `wlast`, `wvalid`, `wready`
- `B` write response channel: `bid`, `bresp`, `bvalid`, `bready`
- `AR` read address channel: `araddr`, `arid`, `arlen`, `arsize`, `arburst`, `arvalid`, `arready`
- `R` read data channel: `rdata`, `rid`, `rresp`, `rlast`, `rvalid`, `rready`

Functionally, AXI writes are carried by `AW + W` and completed by `B`, while AXI reads are issued on `AR` and completed on `R`.

## FDI Interface Overview

FDI stands for Flex Die Interface. In the spec it is the protocol boundary between the die-local bridge logic and the UCIe adapter. The bridge uses a single FDI mainband interface with separate transmit and receive directions.

The spec-defined FDI mainband characteristics are:

- flit width: `2048 bits` (`256 bytes`) per transfer,
- usable payload per flit: `248 bytes`, because the last `8 bytes` are reserved for the UCIe adapter CRC,
- clock: `fdi_clk` at `625 MHz`,
- reset: `fdi_rst_n`,
- protocol: `UCIe 2.0 Streaming`, `Flit Format 6`,
- peak bandwidth: `160 GB/s` per direction.

### FDI Signal Groups

The spec divides the FDI interface into `LP` and `PL` directions.

- `LP` means Local Protocol to Adapter:
  `fdi_lp_data`, `fdi_lp_valid`, `fdi_lp_irdy`, `fdi_lp_startofpkt`, `fdi_lp_endofpkt`, `fdi_lp_state_req`, `fdi_lp_linkerror`
- `PL` means Adapter to Local Protocol:
  `fdi_pl_data`, `fdi_pl_valid`, `fdi_pl_irdy`, `fdi_pl_startofpkt`, `fdi_pl_endofpkt`, `fdi_pl_state_sts`, `fdi_pl_inband_pres`
- Backpressure handshake signals:
  `fdi_pl_trdy` for adapter readiness on TX and `fdi_lp_trdy` for bridge readiness on RX

Per the spec, a flit transfer occurs only when `valid`, `irdy`, and `trdy` are asserted in the same cycle. The adapter may deassert `trdy` to apply backpressure, and the bridge is expected not to drop `irdy` in the middle of a packet.

## Protocol And Packet Format

The spec maps AXI traffic onto UCIe Streaming Format 6 flits. Every packet starts with one header flit, and optional data flits follow depending on payload size.

### Header Flit

The header flit carries protocol and routing metadata, including:

- `FORMAT[2:0] = 3'b110` to identify UCIe Streaming Format 6,
- `VCN` to select the virtual channel,
- `SOP` and `EOP` to mark packet boundaries,
- `OPCODE` to identify the packet type,
- `PORT_ID` to select the destination manager port on the receiving die,
- `TXN_ID` to carry the AXI transaction ID,
- `BURST_LEN`, `BURST_TYPE`, and `BURST_SIZE` for AXI burst reconstruction,
- `RESP` for AXI response packets,
- `CREDIT_RTN_VCN` and `CREDIT_RTN_CNT` for inline credit return,
- `WSTRB_PRESENT`, `ADDR`, `WSTRB_B0`, and `DATA_INLINE` for write/read payload transport.

The last `64 bits` of every flit are `CRC_RSVD`. The bridge drives them as zero and the UCIe adapter overwrites them with the actual CRC before PHY transmission.

### Data Flits

When the transaction payload does not fit in the header flit's inline payload space, additional data flits follow. Each data flit contributes `248 bytes` of contiguous payload stream data.

The spec specifically optimizes the common write case: a single-beat `128-byte` AXI write can fit entirely inside one header flit along with its strobe information, so no extra data flit is needed.

### Opcode Definitions

The main spec-defined flit opcodes are:

- `WRITE_REQ`: AXI write request packet
- `READ_REQ`: AXI read request packet
- `WRITE_RESP`: AXI write response packet
- `READ_RESP`: AXI read response packet
- `CREDIT_RTN`: standalone credit return packet
- `NOP`: no-operation / keepalive class packet

### Virtual Channels And QoS

The spec defines separate virtual channels for traffic classes:

- `VC_NP`: normal non-posted requests
- `VC_CPL`: completions
- `VC_NP_HI`: high-priority non-posted requests
- `VC_CPL_HI`: high-priority completions

Credit pools are maintained independently per virtual channel. The spec also maps AXI `AWQOS/ARQOS` into the request-side VCN selection.

### Credit-Based Flow Control

The FDI transport in the spec is credit-based. The transmitter must have credit available for the target virtual channel before sending a packet. Credits are:

- initialized at link bring-up,
- consumed per transmitted packet,
- returned either inline in a header flit or through a standalone `CREDIT_RTN` packet,
- prioritized high enough to avoid deadlock.

This credit model is one of the key differences between local AXI transport and the die-to-die FDI transport: AXI uses channel-level ready/valid flow control locally, while the FDI packet transport uses both cycle-level handshaking and packet-level credit accounting.

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

> **Note:**  
> This repository contains the AXFDI bridge source code, developed by **Sevya Multimedia Technologies**.  
  >> Contributors:  
  >>Pavan Kammili (pavan.kammili@sevyamm.com)  
  >>Raja Ramagani (raja.ramagani@sevyamm.com)  
  >>Yesaswini Bedadhuru (yesaswini.bedadhuru@sevyamm.com)  
  >>Vishwa Patwari (vishwa.patwari@sevyamm.com)  
  >>Shivasai Tatipalli (shivasai.tatipalli@sevyamm.com)  
  >> Aravind P S  (aravind.prasannanpillai@sevyamm.com)  

