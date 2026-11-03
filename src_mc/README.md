# MC16x2 memory-controller RTL

This directory contains a **16-channel, 2-pseudo-channel-per-channel** controller
core: 32 independent PC schedulers connected to 16 shared channel command buses
and DFI formatters. The top-level module is [`mc16x2`](rtl/mc16x2.sv).

The current top accepts decoded commands and 32-bit write words for each PC.
AXI/CDC support modules are present separately; the AXI transaction backend,
APB/CSR subsystem and PHY initialization/control are future integration work.

## File structure

```text
src_mc/
|-- README.md
|-- rtl/
|   |-- mc16x2.sv             32-PC / 16-channel core top
|   |-- mc_pc_core.sv         Per-PC scheduler and submodule integration
|   |-- mc_cmdq.sv            Command queue and slot allocation
|   |-- mc_wdb.sv             Write payload storage and allocation pointers
|   |-- mc_rdb.sv             Read-return storage and issue-ID tracking
|   |-- mc_bank_state.sv      Open-bank and open-row tracking
|   |-- mc_timing_check.sv    DRAM timing-legality counters
|   |-- mc_refresh_engine.sv  Per-PC periodic refresh request generation
|   |-- mc_arbiter.sv         Shared credit-counter arbitration primitive
|   |-- mc_ch_arb.sv          Independent channel row/column arbitration
|   |-- mc_dfi_fmt.sv         Registered command packing and data-lane routing
|   |-- mc_addr_decode.sv     Fixed address-field extraction
|   |-- mc_axi_sub.sv         AXI signal passthrough interface
|   |-- mc_axi_cdc.sv         Five AXI CDC FIFOs and AW/AR address decode
|   `-- mc_async_fifo.sv      Gray-pointer asynchronous FIFO
`-- tb/
    |-- tb_mc16x2.sv          Full core integration regression
    |-- tb_mc_core.sv         Simple single-PC write/read waveform demo
    |-- tb_mc_dfi_fmt.sv      Formatter unit test
    `-- tb_mc_async_fifo.sv   Asynchronous FIFO unit test
```

There are 15 RTL modules and four testbenches. Each RTL module has one source
file in `rtl/`; no duplicate phase snapshot or generated build directory is
needed in this tree.

## Architecture

The current top instantiates these blocks directly:

```text
mc16x2
`-- g_channel[0:15]
    |-- g_pc[0:1].u_pc_core        mc_pc_core
    |   |-- mc_cmdq / mc_wdb / mc_rdb
    |   |-- mc_bank_state / mc_timing_check
    |   `-- mc_arbiter / mc_refresh_engine
    |-- u_ch_arb                  mc_ch_arb, with row and column arbiters
    `-- u_dfi_fmt                 mc_dfi_fmt
```

PC0 and PC1 have independent queues, buffers, bank state and refresh engines.
They share their channel's row and column command buses. Those buses arbitrate
independently, so a row command for one PC and a column command for the other
can issue in the same cycle. Refresh candidates receive priority.

| Resource | Current configuration |
| --- | --- |
| Channels / PCs | 16 channels, 2 PCs each, 32 PCs total |
| Banks | 16 per PC: 4 bank groups x 4 banks |
| CMDQ / WDB / RDB depth | 32 / 16 / 16 entries per PC |
| PC data / mask | 32 data bits, 4 mask bits |
| Channel data / mask | 64 data bits, 8 mask bits |
| Command ID / entry | 8-bit ID, 36-bit decoded entry |
| Shared row / column bus | 22 bits / 12 bits per channel |

`mc_axi_sub`, `mc_axi_cdc`, `mc_addr_decode` and `mc_async_fifo` are standalone
support modules; they are not instantiated by the current `mc16x2` top.

## Top-level interface

All integrated logic uses `dfi_clk`. `ctl_reset_n` is active low; hold it low
across a rising edge to reset synchronous core state. The formatter and arbiter
also receive this reset. PHY reset sequencing is not implemented here.

For channel `ch` and local PC `pc`, the flattened port index is:

```text
p = 2*ch + pc
channel 0:  PC0 -> p=0,  PC1 -> p=1
channel 15: PC0 -> p=30, PC1 -> p=31
```

| Port group | Meaning |
| --- | --- |
| `cmd_push_val[p]`, `cmd_push_entry[p]`, `cmdq_full[p]` | Decoded command ingress |
| `wdb_push_val[p]`, `wdb_push_data[p]`, `wdb_push_mask[p]`, `wdb_alloc_ptr[p]`, `wdb_full[p]` | Write payload allocation |
| `rdb_valid[p]`, `rdb_data[p]`, `rdb_axi_id[p]`, `rdb_ready[p]` | Per-PC read completions |
| `dfi_row_val[ch]`, `dfi_row[ch]`, `dfi_col_val[ch]`, `dfi_col[ch]` | Shared channel commands |
| `dfi_wrdata[ch]`, `dfi_wrdata_mask[ch]`, `dfi_wrdata_en[ch]` | Channel write data and independent PC enables |
| `dfi_rddata[ch]`, `dfi_rddata_valid[ch]`, `dfi_rddata_en[ch]` | PHY read returns and PC read enables |
| `err_cmdq_overflow[p]`, `err_wdb_overflow[p]`, `err_ref_deadline_miss[p]` | Raw per-PC error indications |

See [`mc16x2.sv`](rtl/mc16x2.sv) for complete port widths and directions.

### Decoded command entry

`cmd_push_entry[p]` is packed as follows:

| Bits | Field |
| --- | --- |
| 35:28 | Command ID |
| 27 | Write=1, read=0 |
| 26:13 | Row address |
| 12:11 | Bank group |
| 10:9 | Bank |
| 8:4 | Column address |
| 3:0 | WDB pointer for a write |

Equivalent SystemVerilog packing:

```systemverilog
{id[7:0], is_write, row[13:0], bg[1:0], bank[1:0], col[4:0], wdb_ptr[3:0]}
```

### Handshake and data behavior

- A command or payload push is accepted at a rising edge only when its matching
  full output was low before that edge. Do not push into a full buffer.
- Sample `wdb_alloc_ptr[p]` before pushing its payload, and copy that pointer
  into the matching write command. Payload may precede the command or arrive
  on the same edge. A queued command does not reserve an empty WDB slot against
  unrelated allocations.
- On an accepted WR, the formatter captures the selected 32-bit payload and raw
  mask on the same edge as the command, and that WDB slot is released. This is
  the current zero-additional-write-offset, single-word transfer contract.
- Channel data `[31:0]` belongs to PC0 and `[63:32]` to PC1. Mask nibbles and
  enable bits follow the same PC order. Inactive write lanes output zero.
- RD enable accompanies RD. Return PHY data in issue order independently for
  each PC; both PC return-valid bits may be high together. The formatter
  registers returns before the corresponding RDB receives them.
- Read completions use valid/ready. Data and ID stay stable while ready is low.
  IDs are restored in DRAM issue order; AXI request-order tracking is future work.

## Testbenches

| File | Simulation top | Purpose |
| --- | --- | --- |
| [`tb_mc16x2.sv`](tb/tb_mc16x2.sv) | `tb_mc16x2` | All-channel stress and integration checks |
| [`tb_mc_core.sv`](tb/tb_mc_core.sv) | `tb_mc_core` | One checked write/read with a focused waveform |
| [`tb_mc_dfi_fmt.sv`](tb/tb_mc_dfi_fmt.sv) | `tb_dfi_formatter` | Reset, field packing, PC routing and data strobes |
| [`tb_mc_async_fifo.sv`](tb/tb_mc_async_fifo.sv) | `tb_mc_async_fifo` | Reset, ordering, fill/full and drain/empty |

The formatter test uses the module name `tb_dfi_formatter`, which differs
from its filename.

### Single-PC waveform demo

The demo resets the core, writes `32'h1234_ABCD` to row `14'h0123`, column
`5'h04`, bank group/bank 0, then reads the same address with ID `8'h21`.
It checks ACT/WR/RD, payload/mask/ID, WDB release and readback. It finishes
before refresh, without artificial grant or consumer stalls.

The waveform contains RESET, IDLE, WRITE, READ and DONE phase labels and
accepted-command pulses (`act_fire`, `wr_fire`, `rd_fire`). The test clock
period is 1 ns, and the behavioral memory uses a five-clock read-return delay.
The demo does not model the PHY formatter or masked memory updates.

## What the 16x2 regression checks

The scoreboard records accepted host requests and WDB ownership. It compares
public DFI traffic with those requests and maintains reference memory. A
separate PHY memory/return queue supplies read data; completions are checked
against the expected request ID and data. Internal signals are observed for
grant/fairness assertions.

Coverage requirements include:

- All 32 PCs, all 16 banks per PC, high row-address bits and all 16 mask values.
- Distinct per-PC data, PC-select fields, independent lanes and inactive-lane zeros.
- CMDQ/WDB capacities of 32/16, deliberate overflow checks and correct slot release.
- RDB capacity 16, queued reads waiting for space, stable stalled completions,
  simultaneous PHY returns and sibling-PC progress while one PC is stalled.
- Row conflicts, row/column contention, same-cycle different-PC row/column issue
  and parallel activity on multiple channels.
- Seeded load with randomized read readiness, return-pointer wrap and refresh
  while commands are queued on every PC.
- One-hot eligible grants, refresh priority and bounded waiting under the
  current always-accepting formatter contract.
- Checks for tRCD, tRAS, tRP, tRC, tRRD, tFAW, tCCD, tWTR, tWR, tRTP and tRFC
  using the current RTL defaults.
- Reset during outstanding reads, recovery with external memory preserved,
  delayed write-payload arrival, watchdogs and complete drain.

The PHY model treats mask bit 1 as byte-write inhibit. The RTL forwards raw mask
bits. IDs are unique while outstanding within a PC in this test, while the same
IDs are deliberately reused on different PCs.

Seeds 1, 7 and 42 passed the full regression, each completing over 34,000 checked
reads in its main traffic phase. The three unit/demo tests also passed. Prior
scratch fault checks caught swapped channel-15 read lanes and a fixed WDB read
pointer; those faults are not present in the sources.

## Implementation status

Current lint includes unused-field/index-bit and mixed synchronous/asynchronous
reset-style notices. The verified build reported no undriven signals, missing
ports, combinational loops or inferred latches.

The integrated top currently covers decoded single-word core operation. AXI
burst handling, 256-to-32-bit data conversion, AXI response ordering, APB/CSR,
programmable PHY data offsets, initialization/update and low-power sequencing
remain to be integrated. Simulation results do not establish synthesis timing
closure, structural CDC signoff or compliance with a selected HBM/PHY device.
