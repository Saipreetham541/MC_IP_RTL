# MC16x2 memory-controller RTL

This directory contains a **16-channel, 2-pseudo-channel-per-channel** controller
core: 32 independent PC schedulers connected to 16 shared channel command buses
and DFI formatters. The single AXI-facing top is
[`mc16x2`](rtl/mc16x2.sv), integrating CDC, transaction dispatch and all channel cores.

`mc16x2` connects one 256-bit AXI port through `mc_axi_sub` and five
asynchronous FIFOs to the
dispatch/response backend in `mc_addr_decode`, then to all 32 PCs. APB/CSR and
PHY initialization/control are outside this integration's scope.

## File structure

```text
src_mc/
|-- README.md
|-- rtl/
|   |-- mc16x2.sv             Unified AXI/CDC/backend/32-PC/DFI top
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
|   |-- mc_addr_decode.sv     AXI burst dispatch, word conversion and responses
|   |-- mc_axi_sub.sv         Instantiated AXI subordinate passthrough interface
|   |-- mc_axi_cdc.sv         Five AXI CDC FIFOs and AW/AR address decode
|   `-- mc_async_fifo.sv      Gray-pointer asynchronous FIFO
`-- tb/
    |-- tb_mc_axi_smoke.sv    Minimal AXI write/read with a small DFI memory model
    |-- tb_mc_axi.sv          AXI-to-memory regression through CDC and 32-PC core
    |-- tb_mc16x2.sv          Full core integration regression
    |-- tb_mc_channel_integration.sv  Older single-channel integration test
    |-- tb_mc_core.sv         Simple single-PC write/read waveform demo
    |-- tb_mc_dfi_fmt.sv      Formatter unit test
    `-- tb_mc_async_fifo.sv   Asynchronous FIFO unit test
```

There are 15 RTL modules and seven testbenches. Each RTL module has one source
file in `rtl/`; no duplicate phase snapshot or generated build directory is
needed in this tree.

## Architecture

The unified top contains the AXI front end and channel logic directly:

```text
mc16x2
|-- u_axi_sub                    mc_axi_sub (external AXI to CDC interface)
|-- u_axi_cdc                    mc_axi_cdc (AW/W/AR/B/R FIFOs)
|-- u_addr_decode                mc_addr_decode (dispatch and responses)
`-- g_channel[0:15]
    |-- g_pc[0:1].u_pc_core      mc_pc_core
    |   |-- mc_cmdq / mc_wdb / mc_rdb
    |   |-- mc_bank_state / mc_timing_check
    |   `-- mc_arbiter / mc_refresh_engine
    |-- u_ch_arb                 mc_ch_arb
    `-- u_dfi_fmt                mc_dfi_fmt
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

`mc_axi_sub` is instantiated as `u_axi_sub` inside `mc16x2`. All five AXI
channels connect through it to `mc_axi_cdc`, including AW/AR lock and
cache/protection attributes. `mc_addr_decode` contains both the address-field
extraction and an eight-state transaction FSM, without SystemVerilog functions
or a separate field-decoder module. AW/AR share descriptor capture, and masked
and completed write words share advancement logic. Hardware request validation
and error-response generation are intentionally omitted.

## AXI interface and address map

The fixed interface is 40 address bits, 256 data bits, 32 write strobes and
8-bit IDs. The aperture is **0x0000000000 through 0x003FFFFFFF** (1 GiB).
This deliberately replaces the older 32-byte-column map: one PC command
stores four bytes, so adjacent words must decode to distinct columns.

| Address bits | Field |
| --- | --- |
| `[1:0]` | Byte within a 32-bit PC word |
| `[6:2]` | Column |
| `[8:7]` | Bank |
| `[10:9]` | Bank group |
| `[24:11]` | Row |
| `[25]` | Pseudo-channel |
| `[29:26]` | Channel |
| `[39:30]` | Must be zero; checked upstream |

The upstream master must supply naturally aligned sizes of 1, 2, 4, 8, 16 or
32 bytes. INCR supports up to 256 beats, FIXED up to 16 beats, and WRAP supports
2, 4, 8 or 16 beats. Every burst must stay within one 4 KiB page and the 1 GiB
aperture. Only normal accesses are supported: AWLOCK and ARLOCK must be zero.
QoS/cache/protection attributes pass through CDC but do not alter scheduling,
caching or access permissions.

These are input requirements, not hardware checks. The simplified decoder
always returns OKAY and does not detect unsupported requests or produce
SLVERR/DECERR. An out-of-aperture address can alias into the implemented map.

AW and W can arrive independently. The backend retains one transaction until
completion, expands each AXI beat into its addressed 32-bit words, and waits
for each write's formatter capture or each read return before issuing another
word. Full-width beats therefore use eight word operations; a PHY/model must
implement this explicit single-word command contract. AXI strobes are inverted
into active-high inhibit masks. Zero-strobe words issue no memory command.
Inactive read byte lanes return zero.

B is generated after the advertised final W beat and all accepted word writes
have reached the formatter. R assembly, RID/RRESP and RLAST are held stable
under backpressure. Global serialization preserves dependencies and same-ID
ordering across all PCs without a return arbiter or reorder buffer. CDC FIFOs
can queue further requests, but memory execution is intentionally serialized;
this integration does not target full channel bandwidth.

The master must supply AWLEN+1 write beats, assert WLAST on the final beat, and
keep write strobes inside the requested byte lanes. The decoder uses AWLEN to
count beats; it does not inspect WLAST or validate strobes. It likewise uses the
saved AXI ID for responses without checking the RDB's returned ID. The serialized
backend relies on correctly ordered returns from the selected PC. Malformed
traffic has no defined recovery or error response.

`aclk` and `dfi_clk` may be asynchronous. Assert `aresetn` and `ctl_reset_n`
together, hold across both clocks, and release each synchronously to its domain.
The system must abort outstanding host transactions and flush pending PHY
returns during reset. Independent warm reset and recovery from late pre-reset
PHY returns are not implemented.

## Top-level interface

All decoded core logic uses `dfi_clk`. `ctl_reset_n` is active low; hold it low
across a rising edge to reset synchronous core state. The formatter and arbiter
also receive this reset. PHY reset sequencing is not implemented here.

The external interface consists of `aclk`/`aresetn`, `dfi_clk`/`ctl_reset_n`,
AXI `s_axi_*` signals, DFI channel signals and per-PC error outputs. Decoded
command, write-buffer and read-buffer signals are internal connections between
`u_addr_decode` and the channel cores; they are no longer top-level ports.

For channel `ch` and local PC `pc`, the flattened internal PC index is:

```text
p = 2*ch + pc
channel 0:  PC0 -> p=0,  PC1 -> p=1
channel 15: PC0 -> p=30, PC1 -> p=31
```

| Signal group | Meaning |
| --- | --- |
| `s_axi_aw*`, `s_axi_w*`, `s_axi_b*`, `s_axi_ar*`, `s_axi_r*` | External AXI request/response channels |
| `cmd_push_val[p]`, `cmd_push_entry[p]`, `cmdq_full[p]` | Internal decoded command ingress |
| `wdb_push_val[p]`, `wdb_push_data[p]`, `wdb_push_mask[p]`, `wdb_alloc_ptr[p]`, `wdb_full[p]` | Internal write payload allocation |
| `rdb_valid[p]`, `rdb_data[p]`, `rdb_axi_id[p]`, `rdb_ready[p]` | Internal per-PC read completions |
| `wr_done[p]` | Internal formatter write-completion indication |
| `dfi_row_val[ch]`, `dfi_row[ch]`, `dfi_col_val[ch]`, `dfi_col[ch]` | Shared channel commands |
| `dfi_wrdata[ch]`, `dfi_wrdata_mask[ch]`, `dfi_wrdata_en[ch]` | Channel write data and independent PC enables |
| `dfi_rddata[ch]`, `dfi_rddata_valid[ch]`, `dfi_rddata_en[ch]` | PHY read returns and PC read enables |
| `err_cmdq_overflow[p]`, `err_wdb_overflow[p]`, `err_ref_deadline_miss[p]` | Raw per-PC error indications |

See [`mc16x2.sv`](rtl/mc16x2.sv) for complete port widths and directions.

### Internal decoded command entry

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

### Internal handshake and DFI data behavior

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
  IDs are restored in DRAM issue order. The AXI backend serializes execution;
  tests injecting decoded requests directly must enforce their own dependencies.

## Testbenches

| File | Simulation top | Purpose |
| --- | --- | --- |
| [`tb_mc_axi_smoke.sv`](tb/tb_mc_axi_smoke.sv) | `tb_mc_axi_smoke` | One AXI write and readback, checked DFI memory and VCD waveform |
| [`tb_mc_axi.sv`](tb/tb_mc_axi.sv) | `tb_mc_axi` | Legal AXI bursts, conversion, ordering, CDC pressure and reset |
| [`tb_mc16x2.sv`](tb/tb_mc16x2.sv) | `tb_mc16x2` | Direct internal core stress across all channels, bypassing AXI |
| [`tb_mc_core.sv`](tb/tb_mc_core.sv) | `tb_mc_core` | One checked write/read with a focused waveform |
| [`tb_mc_dfi_fmt.sv`](tb/tb_mc_dfi_fmt.sv) | `tb_dfi_formatter` | Reset, field packing, PC routing and data strobes |
| [`tb_mc_async_fifo.sv`](tb/tb_mc_async_fifo.sv) | `tb_mc_async_fifo` | Reset, ordering, fill/full and drain/empty |

The formatter test uses the module name `tb_dfi_formatter`, which differs
from its filename.

### Simple AXI-to-DDR write/read smoke test

Run from the repository root (no UVM required):

```bash
make -C src_mc/sim smoke          # Verilator
make -C src_mc/sim questa-smoke   # Questa, with its license configured
```

The test instantiates the actual `mc16x2` RTL, including the asynchronous AXI
FIFOs, backend, all 32 PC cores and DFI formatters. It performs:

1. One single-beat, 256-bit AXI write to `40'h0000000800` with ID `8'h11`,
   all byte strobes enabled, `AWLEN=0` and `AWSIZE=5` (32 bytes).
2. Eight checked 32-bit DFI writes to channel 0, PC0, bank group/bank 0,
   row 1, columns 0 through 7. A small behavioral memory stores those words.
3. An OKAY AXI write response, with every stored memory word checked.
4. One single-beat AXI read of the same address with ID `8'h22`.
   The memory returns each requested word after five DFI clocks.
5. Comparison of the complete 256-bit AXI readback, RID, RRESP and RLAST.

The memory model obtains read data only from previously observed DFI writes;
it does not echo the expected pattern into the DUT. The pattern uses a different
value in each word to expose lane swaps. The test also checks command addresses,
word counts, data enables, write masks and controller errors. A timeout fails
the simulation if a handshake or memory return never completes.

The updated AXI tests also check all five channels across the instantiated
`u_axi_sub` interface, including reverse READY and response signals. Nonzero
QoS/cache/protection attributes are checked after CDC, and AW/AR decoded address
fields are checked when the backend consumes an address. The standalone smoke
test still performs only one write and one read.

Success prints `PASS: one AXI write and one AXI read; eight DDR writes and reads;
data matches.` The Verilator waveform is `/tmp/mc_axi_smoke/mc_axi_smoke.vcd`;
the Questa waveform is `/tmp/mc_axi_smoke/questa/mc_axi_smoke.vcd`.
Override `BUILD_DIR` to change the output location. In a waveform viewer, start
with `phase`, the AXI AW/W/B/AR/R signals, and channel 0's `dfi_row`, `dfi_col`,
write/read data and enable signals. The phases are RESET, WRITE,
WRITE_RESPONSE, READ, READ_RESPONSE and DONE.

The VCD now also includes the DUT-level `sub_*`, `m_*` and internal core buses.
For a live Questa simulation loaded with `vsim -voptargs=+acc`, source
[`mc_axi_smoke_wave.do`](sim/mc_axi_smoke_wave.do) to add grouped external AXI,
subordinate, CDC, backend, core, DFI and error signals. Run the simulation and
use `wave zoom full` to see the complete transaction.

Here “DDR to AXI” means the response to an AXI read request. The model implements
this RTL's simplified DFI word interface, not a vendor DDR device or PHY.
It deliberately models only the address region above and finishes before
refresh; use `tb_mc_axi` for broader traffic and corner cases.

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

The `tb_mc16x2` core regression holds AXI idle and uses testbench-only forces
on the internal decoded-command, write-payload and read-ready signals. It
observes internal queue/return outputs to preserve direct all-PC capacity,
parallelism and scheduler coverage after merging the tops. Normal AXI behavior
is checked separately by `tb_mc_axi` and `tb_mc_axi_smoke`.

The scoreboard records accepted decoded requests and WDB ownership. It compares
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

The AXI top implements burst handling, 256-to-32-bit conversion and serialized
response ordering on the existing single-word core. APB/CSR, programmable PHY
data offsets, initialization/update and low-power sequencing remain outside
this implementation. Simulation results do not establish synthesis timing
closure, structural CDC signoff or compliance with a selected HBM/PHY device.

## Running the integration regression

From the repository root:

```bash
verilator --binary --timing --assert -Wno-fatal --top-module tb_mc_axi -j 4 --Mdir /tmp/mc16x2_axi/axi src_mc/rtl/*.sv src_mc/tb/tb_mc_axi.sv
/tmp/mc16x2_axi/axi/Vtb_mc_axi +seed=1

verilator --binary --timing --assert -Wno-fatal --top-module tb_mc16x2 -j 4 --Mdir /tmp/mc16x2_axi/core src_mc/rtl/*.sv src_mc/tb/tb_mc16x2.sv
/tmp/mc16x2_axi/core/Vtb_mc16x2 +seed=1
```

Change `+seed=1` to `+seed=7` or `+seed=42` to repeat the seeded runs.

The AXI regression uses independent physical-word and byte-addressed reference
memories, public DFI pins, unrelated clocks, varying return latency and response
stalls. It covers all 32 PCs, every narrow size/lane, full-width beats, masks,
AW/W skew, queued addresses, the early-B/W-beat misassociation regression,
FIXED/INCR/WRAP, 256-beat transfers, repeated IDs, full B/R FIFOs, blocked command
and write buffers, and coordinated reset. It checks stable response payloads on
both sides of CDC. The PHY model flushes returns on reset. Invalid-request tests
were removed when the backend changed to the valid-input-only profile.

Before simplifying the decoder, the AXI and decoded-core regressions passed
seeds 1, 7 and 42 after integration, including invalid-request responses.
Lint completed with no errors; known
warnings cover unused attributes/fields, intentionally unconnected decode
outputs and existing mixed synchronous/asynchronous reset use.

After simplification, the valid-traffic AXI regression passed seeds 1, 7 and 42,
with 1,029 B/R checks per seed. The Verilator smoke test also passed. Lint
completed without errors; unused lock/WLAST/returned-ID signals are expected
because the backend no longer performs protocol or returned-ID validation.

After merging the two tops into `mc16x2`, the AXI and direct-core regressions
were rerun with seed 1 and passed. The simple AXI smoke test passed in both
Verilator and Questa. Top-level lint completed with no errors and the same
categories of warnings above.
