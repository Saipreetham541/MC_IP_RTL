# Phase 1 RTL optimization review and implementation plan

Reviewed against the eight RTL modules and `tb_mc_smoke.sv` in this directory on 30 October 2026. Production RTL has not been changed. Experimental variants and their testbenches were built separately in `/tmp/mc_optimization_review`.

## Recommendation

Proceed with the balanced arbiter, reuse of per-slot bank/row classification, RDB ID-storage consolidation, and selective datapath reset removal. Add parameter-derived timing-counter widths: this is a substantial opportunity missing from the supplied suggestions. Treat reduction syntax, `break`, shared expressions, and refresh-expression rewrites as cleanup unless synthesis demonstrates a benefit.

The supplied percentage improvements are not established physical PPA results. There is no target cell library, clock constraint, or physical implementation flow in this directory. The experiments below provide functional comparisons and generic synthesis evidence; actual delay, area, and power require the intended implementation flow.

## Experiments performed

Tools: Verilator 5.020 and Yosys 0.33. All experiments used default module parameters.

| Experiment | Original | Experimental variant | Interpretation |
|---|---:|---:|---|
| Arbiter generic cell count | 3,290 | 2,960 | Approximately 10.0% fewer generic cells |
| Arbiter longest combinational topological path, `ltp -noff` | 330 | 69 | Strong structural depth improvement; these are graph steps, not delay or MHz |
| RDB generic cell count, ID/pointer consolidation only | 1,683 | 1,413 | Approximately 16.0% fewer generic cells |
| RDB generic cell count, also replacing full detection | 1,683 | 1,396 | Approximately 17.1% fewer generic cells; full detection alone saved 17 cells relative to the consolidated variant |
| RDB flip-flop cells, combined variant | 796 | 659 | 137 fewer mapped generic FF cells in this flow |
| Timing-checker generic cell count, narrower counters | 4,355 | 2,723 | Approximately 37.5% fewer generic cells |
| Timing-checker flip-flop cells | 834 | 501 | Exactly 333 fewer counter bits at default timings |

Generic cell counts give every cell equal weight and are not silicon area. These are isolated module experiments, so their percentages must not be added or presented as whole-core savings. The arbiter path includes its counter-update feedback logic; it is not a measurement of the complete scheduler-to-channel path.

Functional checks:

- Original smoke test built and reached completion; it printed ACT, WR, RD, read completion, refresh PRE, and REF. It contains no self-checking end-to-end scoreboard, so completion is only a smoke result.
- Balanced arbiter matched the original grant vector, index, and valid for 20,000 cycles, including tied ages, saturation, denied grants, and randomized request/legality masks.
- Consolidated RDB with new full detection matched the original status and valid output data/ID for 30,000 cycles: 15,882 accepted issues, 992 issue-pointer wraps, 8,757 full cycles, 6,672 returns with no prior in-flight ID, and 7,112 simultaneous accepted issue/return/consume cases. Reset was also asserted during traffic. Invalid output payloads were not compared.
- Narrow timing counters matched all original legality outputs for 20,000 cycles with random loads, simultaneous command-input overrides, idle expiry, and reset. This checks equivalence to the RTL, not correctness against a DRAM device specification.
- Verilator lint reported 12 undriven testbench signals, including `wdb_raddr` and the DFI formatter outputs/enables. No formatter instance drives those signals in this testbench. Consequently the existing smoke test does not verify payload transmission or normal WDB release.

The experiments are simulations, not formal equivalence proofs. For Yosys parsing, the arbiter's aggregate array-reset assignment was expanded to an equivalent per-element loop in its scratch baseline and tree variant. Timing helper-function `return` statements were changed to equivalent function-name assignments in both synthesis variants. Simulation compared against the unchanged original RTL.

## Assessment of every supplied suggestion

### 1. Balanced arbiter: high priority, supported by experiment

Location: `mc_arbiter.sv:25`.

The running maximum creates a dependency between iterations. A balanced tournament is a good way to expose five comparison levels for 32 requests. The structural and generic-cell results above support this change in the available flow. The claimed approximately 80% reduction in actual critical-path delay still needs target timing analysis.

Implementation requirements:

- Preserve eligibility as `req_valid & req_legal` and select the lowest slot index on equal ages. In a tree whose left subtree contains lower indices, the left candidate wins on `>=` when valid.
- Preserve no-request outputs: `grant_valid=0`, `grant_idx=0`, and `grant=0`.
- Preserve counter reset only on accepted grants, saturation, and aging only while eligible. A winner denied by the channel must continue aging as it does today.
- Parameterize the tree rather than copying a hardcoded 32-request implementation. Pad to the next power of two with invalid leaves. Either support one request with index width at least one everywhere, or explicitly reject it.
- Use generate-time constant indices, or ordinary assignments to procedural temporaries. Avoid declaration initializers such as `int l = 2*i` inside an `always_comb` loop; lifetime/initialization handling can differ across tools. Assign all used combinational nodes explicitly.

### 2. Counter saturation and grant-reset syntax: low priority

Location: `mc_arbiter.sv:60`.

`wait_ctr != {WIDTH{1'b1}}` and `!(&wait_ctr)` express the same all-ones detection for normal binary operation. Expect little or no hardware improvement from syntax alone.

Keep the accepted-winner reset branch. The supplied increment snippet is safe only as a replacement for the increment branch; removing the reset branch changes arbitration behavior. If changing `grant[i] && grant_ack` to an index comparison, use `grant_valid && grant_ack && (grant_idx == IDX_W'(i))` so the arbiter remains safe as a standalone module even if acknowledgement is asserted with no winner. Measure either form before preferring it for PPA.

### 3. Reuse per-slot row-hit and bank-open classification: high priority

Locations: `mc_pc_core.sv:261`, `mc_pc_core.sv:315`, and `mc_pc_core.sv:374`.

Compute combinational `slot_page_hit` and `slot_bank_open` alongside `slot_legal`, then select these bits using the winning index in dispatch. This removes the explicit dependency of dispatch classification on the wide winner mux followed by bank lookup and row comparison. The wide winner mux is still needed for output address, ID, and payload pointer.

Define invalid-slot classification deterministically and consume it only with `cmdq_grant_valid`. Keep these as same-cycle combinational results: registering them introduces stale bank/timing information. Compare mapped timing and fanout because synthesis may share existing logic and the new selected-bit mux also has a cost.

An alternative worth measuring is to precompute a small next-command kind per slot: ACT, PRE, RD, or WR. This can centralize the eligibility/dispatch decision, but is not automatically better than the two classification bits.

### 4. Refresh scan and acknowledgement reduction: useful cleanup

Locations: `mc_pc_core.sv:293` and `mc_pc_core.sv:321`.

Use `cmdq_grant_valid` instead of reducing the decoded `cmdq_grant`. They are equivalent by construction and the direct valid signal expresses the intent clearly. The arbiter's one-hot grant still serves its counter-reset logic.

Use `any_bank_open = |bank_is_open` and `pre_candidates = bank_is_open & legal_pre`; choose the lowest candidate. A `break` loop and the existing found-flag loop both describe a priority encoder. Neither spelling guarantees a faster implementation. Use an explicit hierarchical encoder only if the mapped path warrants it. Some synthesis tools have limited support for `break`, so retain a portable form when necessary.

### 5. Datapath reset removal: recommended with interface checks

Locations: `mc_cmdq.sv:48`, `mc_wdb.sv:60`, and `mc_bank_state.sv:31`.

At default widths, the proposed arrays contain 1,952 bits: 1,152 CMDQ bits, 576 WDB data/mask bits, and 224 open-row bits. Removing reset removes their per-bit reset requirement, not their storage. These resets are synchronous, so the implementation benefit may be smaller data-input reset logic rather than a change from resettable to plain flip-flop cells.

Retain reset on `valid_reg` and `bank_is_open`. Split datapath writes into blocks without reset assignments, while retaining the intended write conditions:

```systemverilog
// Example: datapath has no reset value, but does not write during reset.
always_ff @(posedge clk)
  if (rst_n && push_val && !cmdq_full)
    entries[free_idx] <= push_entry;
```

For `open_row`, preserve `rst_n && !cmd_preall_en && cmd_act_en`; the original PREALL-over-ACT priority must survive the split. WDB needs its corresponding accepted-push condition.

Qualification is an interface contract, not true for every raw output bit: CMDQ entries, WDB reads, and open rows are exposed directly. After removal, invalid data can be unknown or stale. Verify all consumers qualify use with valid/open state, and compare behavior only where the data is meaningful. Keep control outputs known after reset. The reset signal may remain in shared write-enable logic; this does not remove all reset-related routing.

Do not promise RAM inference: CMDQ exposes all entries simultaneously, and the bank table supplies many parallel lookups, which do not fit a simple small-port RAM. WDB is a more plausible distributed-memory candidate on a suitable FPGA. Asynchronous read ports also constrain the available memory primitives. See the primary [Yosys memory inference documentation](https://yosyshq.readthedocs.io/projects/yosys/en/v0.50/using_yosys/synthesis/memory.html#memory-kind-selection).

### 6. First-free encoders: low priority unless measured critical

Locations: `mc_cmdq.sv:35` and `mc_wdb.sv:46`.

Replacing `free_found` with `break` retains lowest-free-index priority, but the temporary variable is combinational logic, not an extra state register. It is not evidence of an area saving. Preserve allocation and simultaneous push/pop behavior. Only restructure into a tree or grouped encoder if synthesis identifies allocation as a problem.

### 7. RDB ID consolidation: recommended and experimentally supported

Location: `mc_rdb.sv:30`.

`id_rd_ptr` and `data_wr_ptr` reset together and advance under exactly the same condition, so they remain equal. Use `data_wr_ptr` to track the oldest in-flight read, remove `id_rd_ptr` and `ret_id_fifo`, and read `id_fifo[data_rd_ptr]` for the response ID.

The safety argument is that full detection reserves storage until AXI consumes a response, not merely until DFI returns it. An unconsumed ID cannot be overwritten by a newly accepted read. Preserve that reservation rule.

This removes 128 declared ID-storage bits plus a 5-bit pointer at default parameters. The supplied claim that it eliminates the response ID mux is imprecise: an ID mux is still needed, now reading the retained ID array. It eliminates the intermediate ID-copy storage and associated selection/write logic. The generic experiment saved 137 FF cells because mapped implementation details also changed; 133 is the explicit RTL-state reduction.

Preserve the existing treatment of an unsolicited return and of an issue plus return when no older read is in flight. Adding zero-latency bypass behavior would be a separate functional change.

### 8. RDB full comparator: recommended for the supported geometry

Location: `mc_rdb.sv:42`.

The wrap-bit inequality plus low-address equality is equivalent to the current subtraction-based full check for a power-of-two FIFO using an extra wrap bit. The isolated follow-up synthesis saved 17 generic cells after ID consolidation.

Add elaboration guards for `RDB_DEPTH >= 2`, power-of-two depth, and consistent `RDB_ADDR_W`. The original address truncation already assumes power-of-two depth; arbitrary non-power-of-two depths require explicit pointer wrapping and a different full scheme.

### 9. Timing counter enables and shared legality terms: conditional benefit

Locations: `mc_timing_check.sv:68`, `mc_timing_check.sv:90`, and `mc_timing_check.sv:119`.

Explicit nonzero decrement enables are reasonable. Writing zero to a register already holding zero does not itself toggle its Q output, although its clock load remains active. Existing saturating arithmetic may already be recognized as enable/hold behavior by synthesis. Therefore the rewrite alone does not establish a dynamic-power saving.

Actual ICG insertion requires a configured synthesis flow and appropriate cells; use library-aware clock gating, with reset and load events included in enable behavior. Do not gate clocks with raw RTL logic. FPGA clock-enable inference is distinct from ASIC ICG insertion. The primary [Yosys clock-gating documentation](https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd/index_passes_techmap.html#clockgate-extract-clock-gating-out-of-flip-flops) describes this as an explicit transformation of FF groups with common clock and enable.

Factoring common legality expressions and using a reduction of per-bank `rp_zero` signals improves readability, but tools commonly share identical combinational expressions already. When replacing `legal_ref`, retain **both** `!refresh_busy` and `(cnt_rrd == 0)` in addition to all-bank tRP expiry; omitting tRRD would change behavior.

### 10. Refresh expression and testbench clock: low priority cleanup

Locations: `mc_refresh_engine.sv:16` and `tb_mc_smoke.sv:105`.

The proposed refresh equations preserve set-over-clear priority on coincident expiry/acknowledgement and the deadline-miss pulse. The existing down-counter zero test is already sensible. Whether an up-counter or down-counter maps better is technology dependent; the supplied universal gate-size comparison is too strong.

A blocking assignment is conventional for the testbench oscillator. It may reduce simulator event scheduling, but is not a hardware optimization, and any wall-clock improvement needs measurement. Check event-region races when changing the clock scheduling; retain stimulus on the opposite clock edge or use clocking blocks.

## Additional opportunities

### A. Parameter-derived timing-counter widths: high priority

Each counter loads `T_x - 1` and saturates at zero, so a positive fixed timing parameter requires `max(1, $clog2(T_x))` bits. This is different from counters that must store `T_x` itself.

| Counter | Current bits per counter | Default required bits | Instances |
|---|---:|---:|---:|
| tRCD | 8 | 5 | 16 |
| tRAS | 8 | 6 | 16 |
| tRP | 8 | 4 | 16 |
| tRC | 8 | 6 | 16 |
| tWR | 8 | 5 | 16 |
| tRTP | 8 | 3 | 16 |
| tRRD | 8 | 3 | 1 |
| tCCD | 8 | 2 | 1 |
| tWTR | 8 | 3 | 1 |
| tRFC | 10 | 9 | 1 |
| tFAW | 8 | 5 | 4 |

Total: 834 to 501 bits, saving 333. The available synthesis experiment retained this full saving. Use correctly sized load/decrement expressions and preserve the tFAW shift/decrement ordering. Reject zero timing parameters, or define a separate zero-delay contract; the present `T_x-1` implementation underflows for zero.

The refresh interval needs only 12 bits for the default value 3900, rather than 13. Derive its internal width from `T_REFI` and validate the parameter; this is a small extra saving.

### B. Measure one-hot winner selection

The arbiter already produces a one-hot grant. A masked-OR selection of needed winner fields could replace binary-indexed selection. It may improve mapping or worsen fanout and wiring; compare against the binary mux after the tree/classification changes. Do not duplicate the full command payload at every tournament node without measuring area.

### C. Optional full-buffer replacement on simultaneous consume

CMDQ, WDB, and RDB currently refuse a push/issue when full even if a slot is consumed on that edge. Supporting replacement can remove a boundary bubble under sustained load. This is an interface/throughput change, not equivalent cleanup. CMDQ/WDB must allocate the retiring slot, and producers must receive an acceptance contract that permits the transfer. RDB admission must remain consistent with scheduler legality. Avoid introducing a long path from downstream ready/grant back into admission; measure benefit before adding it.

### D. Scheduling-policy experiments, only after equivalent improvements

Give row-hit traffic preference, potentially with an age threshold to prevent prolonged delay, if workload measurements show repeated PRE/ACT work while useful row hits wait. This changes scheduling policy and can trade fairness for bandwidth. Validate required transaction ordering and same-address read/write dependencies before enabling additional reordering; the files here do not establish an external dependency-management contract. Do not shrink age counters or remove timing constraints just to save gates.

## Implementation sequence and acceptance criteria

1. **Establish a reliable baseline.** Record intended ASIC/FPGA target, clock/I/O constraints, library/device, and synthesis settings. Repair the smoke-test formatter connection or explicitly model its payload read/release behavior. Add self-checking scoreboards for reads and writes, error checks, and a timeout. Cover grant denial, refresh overlap, WDB readiness, RDB backpressure, and reset during activity. Confirm timing constraints against the intended DRAM specification separately from optimization equivalence.
2. **Land the RDB simplification independently.** Consolidate IDs/pointers, then change full detection with geometry guards. Verify occupancy reservation, response ID/data stability while stalled, full/empty transitions, wraparound, simultaneous events, and the existing empty-return behavior. Compare valid outputs against the baseline; use formal equivalence or an inductive pointer/occupancy proof where available.
3. **Narrow timing counters.** Introduce per-parameter widths and sized arithmetic; preserve load priority, spacing, and tFAW semantics. Test defaults plus `T=1`, powers of two, adjacent values, and maximum supported timings. Re-run synthesis to confirm FF and arithmetic savings in the target flow.
4. **Implement the generic tournament arbiter.** Retain the exact existing policy. Test no winner, one winner, equal maximum ages, saturation, accepted/denied grants, illegal requests, and supported request counts including non-power-of-two counts. Check one-hot/index consistency. Compare target timing through the grant-to-counter-update path as well as selection outputs.
5. **Reuse slot classification and simplify dispatch.** Select precomputed classification bits, replace the acknowledgement reduction, and simplify refresh candidate signals. Compare the accepted ACT/PRE/RD/WR/REF trace cycle by cycle against the baseline under identical grants/inputs. Check address/ID/pointer fields as well as command type. Measure the complete scheduler/channel/state-update path and fanout.
6. **Remove selected datapath resets.** Keep valid/open reset and exact write priority. Run reset/unknown-state checks with a four-state simulator or equivalent formal treatment; the current two-state Verilator runs cannot establish X safety. Confirm invalid data never determines a valid command. Compare reset/control logic and inferred storage; preserve any required externally observable reset values.
7. **Apply target-aware power optimization.** Compare explicit decrement enables and configured ICG/FPGA enable inference after narrowing counters. Include functional reset/load behavior, scan/test requirements where applicable, and realistic activity traces covering idle, sustained traffic, refresh, and backpressure. Retain changes only when activity-based power and timing support them.
8. **Evaluate optional architecture changes separately.** Benchmark row-hit rate, accepted column commands per cycle, latency distribution, starvation/fairness, full-buffer bubbles, and read/write ordering. Try winner-mux alternatives and scheduling/admission changes individually so their effects remain attributable.

Keep equivalent refactors in separate reviewable changes. After each, require functional checks and no unintended latch/undriven warnings, then record target mapped area, timing slack, FF/memory counts, and any relevant power result under identical settings. No final MHz, silicon-area percentage, or power percentage should be claimed from the generic experiments alone.

## Local evidence and reproduction

Scratch directory: `/tmp/mc_optimization_review`.

- `lint.log`, `smoke.log`, and `smoke_build.log`: unchanged baseline checks.
- `mc_arbiter_base.sv`, `mc_arbiter_tree.sv`, `tb_arb_compare.sv`, and `arb_*_synth.log`: arbiter comparison.
- `mc_rdb_opt.sv`, `mc_rdb_idonly.sv`, `tb_rdb_compare.sv`, and `rdb_*_synth.log`: RDB comparisons.
- `mc_timing_base.sv`, `mc_timing_narrow.sv`, `tb_timing_compare.sv`, and `timing_*_synth.log`: counter-width comparison.

Generic synthesis used `read_verilog -sv <file>; synth -top <module>; stat`, plus `ltp -noff` for the arbiter. Simulation used `verilator --binary --timing -Wno-fatal --top-module <testbench>` with separate build directories. The experimental sources are feasibility prototypes, not production patches; scratch files may be removed by system temporary-file cleanup.
