# Current 16x2 core integration and regression

`rtl/mc16x2.sv` instantiates 32 real `mc_pc_core` modules, 16 `mc_ch_arb`
modules and 16 `mc_dfi_fmt` modules directly in channel/PC generate scopes.
Active RTL definitions live in `rtl/`, and testbenches live in `tb/`.
Compile the RTL files directly and select one testbench top. Build products and
waveforms are written under `/tmp/mc16x2_sim`, outside the source tree.

## Interface contract

This is the current decoded core integration, not a complete AXI/APB-facing IP.
The existing AXI passthrough/CDC blocks have no transaction-to-core backend, so
they are not given dummy connections. AXI bursts/response assembly, APB/CSR,
PHY initialization/update/low-power and programmable PHY offsets remain future
work. This regression does not establish full P5 or PHY-protocol signoff.

The top uses one `dfi_clk` and active-low `ctl_reset_n`. Hold reset across a
rising edge to reset synchronous core state; it also resets the formatter and
the existing asynchronous arbiter state. There is no sequenced PHY reset output.

PC port index is `2*channel + local_pc`, from 0 through 31. All packed arrays
use that order; channel DFI arrays run from 0 through 15.

| Command entry bits | Meaning |
| --- | --- |
| 35:28 | ID |
| 27 | Write=1, read=0 |
| 26:13 | Row |
| 12:11 | Bank group |
| 10:9 | Bank |
| 8:4 | Column |
| 3:0 | WDB allocation pointer for a write |

- Command/payload pushes are accepted at a rising edge only if the corresponding
  `cmdq_full`/`wdb_full` was low before that edge. These are push interfaces,
  rather than AXI valid/ready channels. Invalid full-buffer pushes assert the
  existing raw overflow outputs and do not allocate storage.
- Sample `wdb_alloc_ptr[p]` before a payload push edge. Store that pointer in
  the matching command. Payload and command can be accepted together, or the
  payload can be stored first. Do not reuse a live pointer or assume a command
  pointing to an empty slot reserves it against unrelated payload allocations.
- One WDB entry carries one 32-bit word plus four raw mask bits, not a 256-bit
  AXI beat. CMDQ/WDB/RDB depths remain 32/16/16 per PC.
- Each channel arbitrates row and column separately. Commands may issue on
  different buses for different PCs in the same cycle. Arbitration never
  couples the PC buffer state or returning data lanes.
- The formatter captures WR and its selected payload on the same edge. WDB
  storage is freed on that edge, after capture. This is a zero-additional-offset,
  one-word baseline; it does not implement configurable PHY write latency.
  Only the selected write lane is enabled; inactive write data/masks are zero.
- RD enable accompanies the formatted RD. Feed in-order returns per PC through
  `dfi_rddata`/`dfi_rddata_valid`. Both PC valid bits may be high together.
  The formatter's return register precedes the core RDB.
- Completion `rdb_valid/data/axi_id` obeys per-PC valid/ready and remains stable
  under backpressure. IDs are restored in DRAM issue order. This top does not
  add AXI request-order tracking or posted B responses.

## Run directly

Run these commands from the repository root. No project Makefile, filelist or
wrapper script is required. The RTL currently has no package/include compile
order dependency, so `src_mc/rtl/*.sv` supplies the sources directly.

```bash
mkdir -p /tmp/mc16x2_sim/obj
verilator --binary --timing --assert -Wno-fatal -j 2 \
  --top-module tb_mc16x2 \
  --Mdir /tmp/mc16x2_sim/obj -o sim \
  src_mc/rtl/*.sv src_mc/tb/tb_mc16x2.sv

/tmp/mc16x2_sim/obj/sim +seed=1
/tmp/mc16x2_sim/obj/sim +seed=7
/tmp/mc16x2_sim/obj/sim +seed=42
```

Verilator and its native C++ build dependencies are required. The commands
compile the SystemVerilog testbench with timing and assertions enabled. A
failing assertion, scoreboard check, coverage requirement or watchdog returns
a failure status.

For detailed lint:

```bash
verilator --lint-only --timing --Wall -Wno-fatal \
  --top-module tb_mc16x2 src_mc/rtl/*.sv src_mc/tb/tb_mc16x2.sv
```

## Remaining files

```text
src_mc/
  README.md
  IMPLEMENTATION_PLAN_P1_P4.md
  rtl/    15 unique RTL modules, including mc16x2
  tb/     tb_mc16x2.sv, tb_mc_core.sv,
          tb_mc_dfi_fmt.sv, tb_mc_async_fifo.sv
```

The full integration regression, simple waveform demo, formatter unit test and
async FIFO unit test have distinct purposes. The formatter test's module name
is `tb_dfi_formatter`; the other testbench tops match their filenames.

## Simple core waveform

`tb_mc_core` runs reset, one write of
`32'h1234_ABCD` to row `14'h0123`, column `5'h04`, bank group/bank 0,
then one read of the same address. The test checks the write payload, mask,
WDB release and readback data/ID, then finishes before periodic refresh.
There are no artificial grant or read-consumer stalls. The clock period is 1 ns;
the DUT's normal timing delays remain in effect.

Compile and run the waveform demo directly:

```bash
mkdir -p /tmp/mc16x2_sim/smoke
verilator --binary --timing --assert -Wno-fatal --trace --trace-depth 1 -j 2 \
  --top-module tb_mc_core \
  --Mdir /tmp/mc16x2_sim/smoke -o sim \
  src_mc/rtl/*.sv src_mc/tb/tb_mc_core.sv
/tmp/mc16x2_sim/smoke/sim +vcd=/tmp/mc16x2_sim/smoke/tb_mc_core.vcd
gtkwave /tmp/mc16x2_sim/smoke/tb_mc_core.vcd
```

Tracing at depth 1 keeps the waveform focused on testbench-level signals.

Start with `clk`, `rst_n`, `phase` (ASCII format), `cmd_push_val`,
`cmd_push_entry`, `act_fire`, `wr_fire`, `rd_fire`, `wdb_rdata`,
`dfi_rddata_valid`, `dfi_rddata`, `rdb_valid`, `rdb_ready`, `rdb_data`,
`rdb_axi_id` and `read_done`. Display data and addresses in hexadecimal.
`phase` labels RESET, IDLE, WRITE, READ and DONE; the `*_fire` signals mark
accepted memory commands. The behavioral memory returns the stored word
`READ_LATENCY` (5) clocks after RD. This demo uses raw mask `4'b0000` and
does not model byte masking or the PHY formatter. The full regression below
retains stress, backpressure, multiple-address and refresh coverage.

## Checks in tb_mc16x2

The scoreboard records accepted host commands, per-slot payload ownership and
reference memory. It decodes public DFI command fields and compares write
payload/masks to the recorded requests. A separate PHY memory/return queue
produces read responses; the RDB scoreboard checks request IDs and expected
data. Internal DUT signals are observed only for grant/fairness assertions.

The explicit PHY model uses active-high byte inhibit (DM=1) when updating memory.
The DUT passes the mask bits without conversion. Row patterns exercise high
address bits, with all 16 banks and all 16 mask combinations required per PC.
Same IDs deliberately occur on different PCs while data patterns distinguish
the PCs/channels. Outstanding IDs within a PC are unique in this regression.

The regression requires:

1. Reset during in-flight reads, no stale completions, cleared outputs/status,
   and later recovery with persistent external memory.
2. WDB capacity 16 and CMDQ capacity 32 on every PC, deliberate overflow pulses,
   no invalid allocation, and correct status/slot release.
3. All-channel writes, raw data/mask checking, masked memory contents, WDB reuse,
   high row/address bits, and zero inactive write lanes.
4. RDB capacity 16 on every PC, two additional queued reads blocked until space,
   stable stalled responses, simultaneous PHY PC returns, and PC1 progress while
   PC0 stays stalled. Both PCs subsequently drain.
5. Row conflicts, PRE/ACT sequences, PC-select routing, independent row/column
   arbitration, same-cycle different-PC row/column issue and parallel channels.
6. Seeded queue saturation with randomized per-PC RREADY, per-PC return pointer
   wrap, more than 100 completed reads per PC, and refresh with queued work on
   every PC. The normal run completes over 1,000 reads per PC.
7. One-hot eligible grants, refresh priority whenever a refresh candidate is
   ready, and bounded waiting for continuously eligible channel candidates.
   This is a simulation check under the top's always-accepting formatter
   contract, not a formal or unconditional starvation proof.
8. Independent timing tracking for ACT/open-row state, tRCD, tRAS, tRP, tRC,
   tRRD, tFAW, tCCD, tWTR, tWR, tRTP and tRFC at the current default settings.
9. A write command waiting without payload, then correct completion when its
   reserved test slot receives data, followed by checked readback.
10. Complete request/return/buffer drain and per-channel contention, split-bus
    and dual-return coverage. `PASS` is printed only after these requirements.

Seeds 1, 7 and 42 were run. Scratch copies with channel 15's return lanes swapped
and with a fixed WDB read pointer were rejected by the scoreboard. Injected
faults are not retained in repository sources.

Measured main-epoch totals (before the final reset/recovery scenario):

| Seed | Checked writes | Checked read completions |
| --- | --- | --- |
| 1 | 528 | 34,334 |
| 7 | 528 | 34,327 |
| 42 | 528 | 34,329 |

The subsequent recovery scenario checks another write and two reads per PC.

Detailed lint retains unused-field/index-bit notices and mixed synchronous/
asynchronous reset-style notices inherited from the current core/arbiter
composition. Intentional blocking testbench scoreboard updates are annotated.
No undriven signals, missing ports, combinational loops or inferred latches were
reported. These simulation checks do not replace structural CDC analysis,
synthesis timing checks or verification against the selected memory/PHY.
