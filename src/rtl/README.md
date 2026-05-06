# RTL Directory Notes

This directory contains the synthesizable RTL for the AXI-to-FDI bridge.

## Design Summary

At a high level, the bridge converts AXI traffic into FDI flits on transmit and converts inbound FDI flits back into AXI traffic on receive.

- On the transmit side, AXI-side requests/responses are accepted by the AXI adapter blocks, buffered, crossed from `axi_clk_i` into `fdi_clk_i`, selected by the merge/arbitration logic, and packed into outbound FDI flits.
- On the receive side, inbound FDI flits are accepted by the FDI interface block, decoded by the depacketizer, tracked for completion/credit handling, routed to the correct port and channel, and crossed back into the AXI clock domain.
- The top-level design supports two logical ports and handles both AXI request traffic and AXI completion/response traffic in both directions.

## Top-Level Integration

- `axfdi_bridge.sv` is the top-level bridge module.
- The bridge exposes two AXI subordinate-side ports, two AXI manager-side ports, and one FDI link interface.
- The design crosses between `axi_clk_i` and `fdi_clk_i` using multiple `cdc_fifo` instances for AXI request and response channels.

## RTL Hierarchy

The hierarchy below reflects the current structure of `axfdi_bridge.sv`.

```text
axfdi_bridge.sv
|-- axfdi_fdi_if.sv
|-- Receive-side control
|   |-- axfdi_depacketizer.sv
|   |-- axfdi_port_router.sv
|   |-- axfdi_completion_tracker.sv
|   `-- axfdi_credit_mgr.sv
|-- AXI manager-side adapters
|   |-- axfdi_axi_mgr.sv  (port 0)
|   |   `-- TX_BUFF.sv instances for local AXI channel buffering
|   `-- axfdi_axi_mgr.sv  (port 1)
|       `-- TX_BUFF.sv instances for local AXI channel buffering
|-- AXI subordinate-side adapters
|   |-- axfdi_axi_sub.sv  (port 0)
|   |   `-- TX_BUFF.sv instances for local AXI channel buffering
|   `-- axfdi_axi_sub.sv  (port 1)
|       `-- TX_BUFF.sv instances for local AXI channel buffering
|-- Clock-domain crossing
|   `-- cdc_fifo.sv x20
|       |-- SUB0: AW, W, AR, R, B
|       |-- SUB1: AW, W, AR, R, B
|       |-- MGR0: AW, W, AR, R, B
|       `-- MGR1: AW, W, AR, R, B
`-- Transmit-side selection and packing
    |-- axfdi_port_merge.sv
    |-- axfdi_tx_arb.sv
    `-- axfdi_packetizer.sv
```

## Data-Flow View

### AXI to FDI

1. `axfdi_axi_sub.sv` captures AXI subordinate-side write/read requests.
2. The request channels are moved into the FDI clock domain through `cdc_fifo.sv`.
3. `axfdi_port_merge.sv` advertises pending traffic across the two ports.
4. `axfdi_tx_arb.sv` selects the next transaction type, port, and VC based on availability and credit indications.
5. `axfdi_packetizer.sv` reads the selected FIFO payloads and builds the outbound flit.
6. `axfdi_fdi_if.sv` drives the external FDI transmit interface.

### FDI to AXI

1. `axfdi_fdi_if.sv` accepts inbound flits from the external FDI interface.
2. `axfdi_depacketizer.sv` decodes opcode, port, ID, address, payload, and credit-return information.
3. `axfdi_completion_tracker.sv` helps map returning completions back to the correct originating port.
4. `axfdi_credit_mgr.sv` tracks credit consumption, initialization, and returned credits.
5. `axfdi_port_router.sv` sends the decoded transaction to the correct per-port/channel CDC path.
6. `cdc_fifo.sv` moves the response/request payload back into the AXI clock domain.
7. `axfdi_axi_mgr.sv` and `axfdi_axi_sub.sv` present the resulting traffic on the external AXI interfaces.

## Main RTL Blocks

- `axfdi_bridge.sv`: top-level integration of the bridge datapath and control blocks.
- `axfdi_fdi_if.sv`: adapts the external FDI link signals to the bridge's internal flit-level transmit and receive handshake.
- `axfdi_packetizer.sv`: builds outbound FDI flits from internal AXI-side transactions and credit-return traffic.
- `axfdi_depacketizer.sv`: decodes inbound FDI flits into AXI request/response information and credit-return events.
- `axfdi_port_router.sv`: routes received transactions toward the correct internal AXI-side path and associated CDC ingress.
- `axfdi_port_merge.sv`: merges per-port traffic into the shared transmit path before arbitration.
- `axfdi_tx_arb.sv`: selects the next transaction class/VC to transmit.
- `axfdi_credit_mgr.sv`: tracks available credits, initialization, and credit-return handling.
- `axfdi_completion_tracker.sv`: tracks outstanding completions and associates responses back to the originating context.
- `axfdi_axi_mgr.sv`: AXI manager-side protocol adapter logic.
- `axfdi_axi_sub.sv`: AXI subordinate-side protocol adapter logic.
- `cdc_fifo.sv`: reusable clock-domain-crossing FIFO primitive used throughout the bridge.
- `TX_BUFF.sv`: local AXI channel buffer used inside the AXI adapter blocks.

## Build Notes

- `axfdi_bridge.f` is the RTL file list for this directory.
- The current file list contains the bridge top and all supporting RTL blocks in compile order.

## Quick Read Order

If you are new to this directory, the most useful order to read the code is:

1. `axfdi_bridge.sv`
2. `axfdi_fdi_if.sv`
3. `axfdi_packetizer.sv` and `axfdi_depacketizer.sv`
4. `axfdi_port_router.sv`, `axfdi_port_merge.sv`, and `axfdi_tx_arb.sv`
5. `axfdi_credit_mgr.sv` and `axfdi_completion_tracker.sv`
6. `axfdi_axi_mgr.sv`, `axfdi_axi_sub.sv`, and `cdc_fifo.sv`
