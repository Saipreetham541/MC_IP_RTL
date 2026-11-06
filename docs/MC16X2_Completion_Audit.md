# MC16X2 completion audit

**Historical assessment:** the AXI integration was subsequently implemented in
`src_mc/rtl/mc_addr_decode.sv` and `src_mc/rtl/mc16x2.sv`, using the user-selected
32-bit PC datapath and contiguous 1 GiB address map. See `src_mc/README.md` for
the current interface, limitations and regression commands. The findings below
record the pre-implementation review; APB/CSR work remains explicitly deferred.

Reviewed on 5 November 2026 against the working tree and the hierarchy supplied in chat.

The controller has an integrated decoded-command core with 32 pseudo-channels and 16 shared channel formatters. It is ready for system integration work, but it is not yet a complete AXI-accessible memory-controller IP. The immediate blockers are the AXI transaction backend, the unresolved transfer-width contract, memory dependencies and response ordering, and PHY control. APB/CSR is also needed to deliver the supplied hierarchy.

The repository does not establish a complete numbered Phase 5 acceptance plan. Calling this the start of Phase 5 is a reasonable project label, not a verified milestone. The root README describes the separate AXI-to-UCIe-FDI bridge; use `src_mc/` for this memory-controller assessment. UCIe FDI and the controller's PHY-facing interface are different interfaces.

## Files in the requested hierarchy

Paths below are relative to `src_mc/rtl/`. Replication counts are instance counts, not separate source files.

| File | Present | Current status and next work |
| --- | --- | --- |
| `mc16x2.sv` | Yes | Instantiates the 32 PC cores, 16 channel arbiters and 16 formatters. Add AXI and APB clock/reset/port groups, backend, CSR, PHY control and IRQ integration. |
| `mc_axi_sub.sv` | Yes | AXI signal passthrough only. No transaction conversion, burst execution, response generation or ordering. |
| `mc_addr_decode.sv` | Yes | Fixed address slices. Currently instantiated twice inside CDC, rather than beneath AXI subordinate as drawn. Settle ownership, aperture checking and per-beat decode. |
| `mc_axi_cdc.sv` | Yes | Five standalone AXI channel FIFOs plus AW/AR decode. Not instantiated by the current top. Integrate and verify all five channels and reset recovery. |
| `mc_pc_core.sv` x32 | Yes | Integrated scheduler. Add dependency protection here or enforce it upstream. Add configuration/control connections if runtime timing and PHY pauses are required. |
| `mc_cmdq.sv` | Yes | Integrated command-slot pool. Add sequence/dependency metadata if enforcing ordering in the core. |
| `mc_wdb.sv` | Yes | Integrated 16-slot, 32-bit payload store. Revisit width, ownership and release when the real PHY transfer contract is chosen. |
| `mc_rdb.sv` | Yes | Integrated 16-read capacity and issue-order ID restoration. Does not restore AXI request order or assemble 256-bit beats. |
| `mc_bank_state.sv` | Yes | Integrated bank/open-row state. Include initialization/reset/recovery state rules. |
| `mc_arbiter.sv` | Yes | Integrated age-based arbitration primitive. Measure its critical path during synthesis/STA. |
| `mc_timing_check.sv` | Yes | Integrated bring-up timing counters. Validate the complete timing matrix against the selected memory/PHY, including data latency and turnaround relationships. |
| `mc_refresh_engine.sv` | Yes | Integrated periodic request and deadline event. Validate interval, debt policy and behavior during PHY maintenance and recovery. |
| `mc_ch_arb.sv` x16 | Yes | Integrated independent row/column arbiters. Extend acceptance gating if the PHY path can stop accepting commands. |
| `mc_dfi_fmt.sv` x16 | Yes | Registered abstract command packing and PC lane routing. No programmable command-to-data offsets or complete PHY control. |
| `mc_dfi_if.sv` x16 | **No** | Implement the selected PHY interface boundary: initialization/readiness, update handshakes, transfer timing and safe command acceptance. Low-power features depend on scope. |
| `mc_csr.sv` | **No** | Implement register storage, control/status, error capture, interrupt status/mask/clear and configuration application. |
| `mc_apb_if.sv` | **No** | Implement an APB4 subordinate frontend for CSR accesses. No separate `apb4.sv` file is needed. |
| `mc_sync_dfi.sv` | **No** | Implement coherent APB-to-controller configuration transfers and controller-to-APB status/event transfers. |
| `mc_perf_mon.sv` | **No** | Implement accepted-operation, stall and refresh counters, with coherent snapshots. Required for the exact hierarchy, but not on the first functional read/write path. |

There are 19 unique module names in the supplied hierarchy: 14 have corresponding files and five are missing. The existing `mc_async_fifo.sv` is an additional required support file beneath `mc_axi_cdc`; retain it in the source manifest.

An additional `mc_axi_backend.sv` is recommended to keep transaction handling reviewable. Its name is optional, but its functionality is essential. The architecture drawing needs to show where this backend executes after clock crossing. Merely connecting the existing passthrough and CDC modules will not connect AXI requests to the PC queues.

## Critical functional gaps

### 1 AXI transaction backend and completion tracking

Build the controller-domain path from AW/W/AR FIFO outputs to the 32 command queues and write buffers, and from read/write completion events back to B/R FIFO inputs.

- Preserve AW/W association despite independent arrival and backpressure.
- Track burst length, size, address progression and WLAST. State the supported burst/alignment/narrow-access profile and return defined errors for unsupported legal requests.
- Route each expanded access to its channel and PC, with safe CMDQ/WDB admission and pointer ownership.
- Generate BID/BRESP and RID/RRESP/RLAST; hold response payloads stable while stalled.
- Define the write completion point. Track every constituent operation of a write before reporting completion according to that contract. The current core top has no external write-completion output.
- Preserve required response ordering across PCs and channels. An AXI ID alone is not a unique internal transaction tag when multiple requests with that ID are outstanding.
- Reserve response/assembly capacity before issuing work so the unbackpressured PHY return path cannot overflow.

For the first integration milestone, serialize transactions and support aligned single-beat full-width accesses. This simplifies correctness bring-up; it is not a substitute for burst support if the final requirements include it.

### 2 Resolve the 256-bit to 32-bit contract before building conversion

The AXI CDC carries 256-bit data and 32 strobes. Each PC currently consumes or returns one 32-bit word and four mask bits per command. The decoder reserves address bits `[4:0]` as a 32-byte offset, but each current command transfers only four bytes. The CDC's decoded outputs omit this offset, although its full address output retains it.

Choose and document the memory transaction/burst geometry, controller-to-PHY clock ratio, number of data phases, and byte-lane mapping. Possible implementations include a wider PC payload or properly scheduled multi-phase transfers. Do not assume eight independent DRAM commands or increment the column for each 32-bit slice without a matching address and memory-burst definition.

Specify conversion of AXI write strobes to the selected PHY mask polarity. The current test model uses mask bit 1 as write inhibit; the RTL forwards mask bits unchanged.

### 3 Enforce dependencies and ordering

The scheduler selects any legal slot. It has no older-request dependency test. For example, an older write waiting for payload can be bypassed by a younger read to the same location. Two writes can also execute in the wrong order when an earlier one is blocked.

Start with conservative upstream serialization, or add sequence tracking and overlap checks for read-after-write, write-after-read and write-after-write dependencies. Separately enforce same-ID response ordering, including requests routed to different PCs. RDB tracks DRAM issue order, not original AXI acceptance order.

The existing regression uses unique outstanding IDs within each PC. Its long seeded saturation phase generates reads, with writes covered in separate directed phases. Add mixed read/write hazards and repeated outstanding AXI IDs; the current passing regression does not close these gaps.

### 4 PHY readiness acceptance and timing

The current formatter registers commands and write data together. The top releases a WDB word on the granted WR, and RD enable accompanies RD. This is the existing simulation contract, not evidence of compatibility with a selected HBM3 PHY.

Obtain the intended PHY's interface and memory-device timing requirements before finalizing `mc_dfi_if`. Define initialization and training ownership, readiness, update request/acknowledge behavior, command/data offsets and transfer phases. Do not infer a generic DDR DFI protocol solely from the current signal names.

The top currently ties channel grant acknowledgments high. If initialization, update or downstream capacity blocks commands, qualify the grants that update PC state and ensure accepted commands and data are retained. Queues, bank state, timers, RDB reservations and WDB release must agree on the actual acceptance edge. WDB may be released at capture if downstream storage safely retains the complete delayed payload.

Validate the timing matrix against the chosen device, including read-to-write turnaround, write recovery relative to actual data, and any bank-group or shared-channel constraints. Current timing values are bring-up parameters; simulation does not prove device compliance.

### 5 Address aperture and reset recovery

`mc_addr_decode` ignores address bits `[39:33]`. Distinct addresses can therefore alias if the system does not restrict the aperture. Define base/size checking and out-of-range AXI responses, and decode burst addresses after progression rather than relying only on the starting address.

Define reset ownership for `aclk`, `dfi_clk` and `pclk`; synchronize reset release in each domain. The asynchronous FIFO has independently resettable pointer domains but no coordinated flush protocol. Resetting only one side during traffic requires an explicit system recovery contract.

Prevent old PHY returns from being associated with requests issued after controller reset. The existing regression clears its PHY return model during reset; it does not prove that a late external return is safely handled. Define how accepted AXI requests complete or are invalidated during recovery.

## APB4 and the minimum control subsystem

Implement APB4 inside `mc_apb_if.sv`, beneath `mc_csr.sv`, as the hierarchy requests. An APB interface is not intrinsically necessary for a fixed-parameter decoded-core simulation; it is needed for this requested software-controlled architecture. APB3 could be an explicitly agreed reduced profile, but APB4 is the recommended target here.

Use a 32-bit CSR data path with PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY and PSLVERR, plus APB4 PSTRB and PPROT with documented handling. Decode completed transfers correctly, honor byte write strobes, support back-to-back transfers and define invalid-address/read-only-write behavior.

Minimum recommended CSR groups, with offsets to be defined in a reviewed register map:

| Group | Minimum purpose |
| --- | --- |
| Identification | IP version and supported configuration/features |
| Control | Controller enable and controlled quiesce; defined recovery/start behavior |
| Status | PHY ready, initialization state, busy/idle and configuration pending/applied |
| Errors and IRQ | Sticky per-PC CMDQ/WDB overflow and refresh deadline events; interrupt mask and write-one-to-clear semantics; PHY errors if available |
| Timing and refresh | Either documented read-only build-time values, or writable shadow values with a safe apply handshake |
| PHY configuration | Required transfer offsets and initialization/update controls for the selected PHY |
| Performance | Accepted reads/writes, stalls and refresh counts; snapshot/clear controls |

The current timing and refresh values are module parameters. Writing new CSR registers will not change them until ports and runtime configuration logic are added through `mc_pc_core`, `mc_timing_check` and `mc_refresh_engine`. If fixed timings satisfy the first release, expose them read-only and defer runtime programmability explicitly.

Use a request/acknowledge mailbox or another coherent transfer for configuration bundles in `mc_sync_dfi`. A separate two-flop synchronizer on every bit does not provide an atomic configuration update. Apply changed timing only at a defined safe state, return acknowledgment after application, and snapshot multibit counters before APB reads. Capture short error pulses in the source domain so APB cannot miss them. Define set-versus-clear priority for simultaneous error events and software clears.

`mc_sync_dfi` is for control/status CDC. Do not asynchronously synchronize every signal on a PHY datapath that operates in `dfi_clk`.

APB signal reference: [Arm AMBA APB Protocol Specification](https://www.eecs.umich.edu/courses/eecs373/readings/IHI0024C_amba_apb_protocol_spec.pdf). PHY contract reference: [DFI Group interface overview](https://ddr-phy.org/); the actual selected HBM3 PHY documentation remains necessary.

## Recommended order of work

1. **Freeze the integration contract.** Choose the AXI feature profile, address aperture, memory burst/data geometry, PHY interface, reset policy and ordering policy. Define typed request/response records and accepted-operation events. A shared package is useful but optional.
2. **Complete one full-width AXI write/read path.** Implement the backend with conservative serialization, correct width handling, responses and address errors. Integrate the existing AXI CDC. Demonstrate byte masks and response backpressure.
3. **Add APB4 CSR and coherent CDC.** Create `mc_apb_if.sv`, `mc_csr.sv` and `mc_sync_dfi.sv`, with a register map and configuration/error/IRQ tests.
4. **Complete the selected PHY boundary.** Create `mc_dfi_if.sv`, extend formatter timing as required, and integrate readiness/update/acceptance controls. A behavioral PHY can support a simulation milestone; hardware completion needs the actual PHY contract.
5. **Add required concurrency and bursts.** Introduce internal tags, ordering/dependency tracking, response assembly and fair return arbitration. Exercise cross-PC/channel requests, repeated IDs, mixed reads/writes and full-buffer pressure.
6. **Finish observability and verification.** Add `mc_perf_mon.sv`, then close all-channel tests, reset/CDC tests, lint, synthesis, STA and CDC/RDC review. Low power, ECC, BIST, advanced QoS and extra debug are scope-dependent; do not silently add them as prerequisites for a basic functional release.

For a Phase 5 control-subsystem milestone, items 3 and the necessary parts of 4 form a useful deliverable. They do not eliminate the AXI/backend work in items 1, 2 and 5.

## Verification and release files to add

These names are proposed, not existing deliverables:

- `docs/MC16X2_Register_Map.md`: addresses, reset values, RO/RW/W1C behavior, strobes, safe update and CDC semantics.
- `docs/MC16X2_Interface_Contract.md`: AXI support profile, address map, transfer geometry, PHY timing and reset/ordering rules.
- `src_mc/tb/tb_mc_axi_backend.sv`: AW/W skew, conversion, masks, bursts, errors, response stalls and ordering.
- `src_mc/tb/tb_mc_axi_cdc.sv`: all five channels with unrelated clock ratios, FIFO pressure and defined reset recovery.
- `src_mc/tb/tb_mc_csr.sv`: APB setup/access, waits, back-to-back accesses, partial writes, errors, sticky events and IRQ behavior.
- `src_mc/tb/tb_mc_sync_dfi.sv`: atomic apply, acknowledgment, event capture and snapshots across asynchronous clocks.
- `src_mc/tb/tb_mc_dfi_if.sv`: readiness, initialization/update pauses, command/data alignment and return routing.
- `src_mc/tb/tb_mc_soc.sv`: APB configuration followed by AXI accesses through CDC and the core into a checked PHY/memory model.
- Synthesis/STA constraints and CDC/RDC setup appropriate to the target technology, clocks and PHY interface. Record measured results before claiming 1 GHz closure.

Update `src_mc/README.md` after integration. Its present file list omits the existing `tb_mc_channel_integration.sv`; avoid treating documentation counts as a compile manifest.

## Fresh verification performed for this audit

- Verilator 5.020 core lint completed with no errors. Warnings include unused signals/fields, intentionally unconnected decoder byte offsets, and mixed synchronous/asynchronous reset use.
- Separate `mc_axi_cdc` lint completed with no errors; warnings include unconnected byte-offset outputs and unused upper address bits.
- Built `tb_mc16x2` against all current `src_mc/rtl/*.sv` with `--binary --timing --assert -Wno-fatal`.
- Re-ran seeds 1, 7 and 42; all three printed PASS for 32 PCs, 16 channels, bank/row/mask coverage, buffer capacity, stalls, reset, timing and refresh under load.
- Existing regression source and scope were reviewed; no new functional tests, synthesis, STA, structural CDC or vendor PHY compliance checks were performed.

Reproduction from the repository root:

```bash
verilator --lint-only --timing -Wall -Wno-fatal --top-module mc16x2 src_mc/rtl/*.sv
verilator --lint-only --timing -Wall -Wno-fatal --top-module mc_axi_cdc src_mc/rtl/mc_axi_cdc.sv src_mc/rtl/mc_addr_decode.sv src_mc/rtl/mc_async_fifo.sv
verilator --binary --timing --assert -Wno-fatal --top-module tb_mc16x2 -j 4 --Mdir /tmp/mc_finish_review_obj src_mc/rtl/*.sv src_mc/tb/tb_mc16x2.sv
/tmp/mc_finish_review_obj/Vtb_mc16x2 +seed=1
/tmp/mc_finish_review_obj/Vtb_mc16x2 +seed=7
/tmp/mc_finish_review_obj/Vtb_mc16x2 +seed=42
```

Evidence logs for this run are `/tmp/mc_finish_core_lint.log`, `/tmp/mc_finish_cdc_lint.log`, `/tmp/mc_finish_review_build.log`, and `/tmp/mc_finish_review_seed{1,7,42}.log`. The `/tmp` evidence is temporary; archive it with release results if needed.

This audit adds documentation only. Existing RTL edits were preserved.

## Top-level integration update

The AXI wrapper and decoded channel core have since been merged into the single
`src_mc/rtl/mc16x2.sv` module. The separate RTL `mc_top.sv` has been removed;
AXI CDC, dispatch, all 32 PC cores and 16 channel formatters now reside under
`mc16x2`. The candidate review below is historical.

## Follow-up review of the supplied mc_top candidate

The subsequently supplied `Pasted text.txt` declares `mc_top` and alias wrapper `mc_p4_top`. This is a separate single-channel candidate, not the current repository `mc16x2` top. It adds AXI CDC, simultaneous AW/W dispatch into two PC cores, posted B response generation and a two-PC read-return mux. This changes the candidate's backend status to partially implemented; the repository audit above still describes its existing top.

The candidate elaborates with the current RTL in Verilator, with warnings. It is not ready to replace the 16-channel top:

- Lines 379-386 keep only `m_wdata[31:0]` and `m_wstrb[3:0]`. Upper 224 data bits and 28 strobes are discarded.
- Lines 365-391 consume one AW with one W and generate an OKAY B response, without using AWLEN or WLAST. A focused simulation confirmed a two-beat burst receives its B response before the final beat is sent; the final beat subsequently pairs with the next AW and is dispatched under that next request's ID.
- Lines 757-762 zero-extend a 32-bit result into 256 bits and always assert RLAST. ARLEN, ARSIZE and ARBURST do not control response assembly or beat count.
- Decoded channel selects are unused. The candidate neither checks the selected channel nor routes among 16 channels. Address byte offsets are also not used for lane selection.
- Raw AXI write strobes are passed to the core mask without conversion. This disagrees with the repository test memory's active-high write-inhibit mask convention; establish the target PHY mask convention and convert accordingly.
- Same-address dependencies and same-ID response order are not enforced. Posted B responses require a defined buffering and subsequent-access hazard policy.
- The return mux has no lock on a selected response while the R CDC FIFO is full; a newly valid preferred PC can change the internal offered ID/data before acceptance. Add a holding register or retained selection for a stable valid/ready interface.
- Top-level width parameters do not make the fixed-width `mc_axi_cdc` and `mc_dfi_fmt` instances parameterized. Either constrain the supported configuration or parameterize the complete path.
- APB/CSR, coherent control CDC, PHY initialization/update, data offsets and performance monitoring remain absent. The header's DFI 5.0 claim is not established by command packing and register boundaries.

Use the dispatch and return logic as a starting point for `mc_axi_backend`, then integrate a corrected backend with the existing 32-PC core. Keep one global AXI frontend/CDC when the architecture has one host port; channel replication belongs after decode/routing.

Follow-up evidence is in `/tmp/mc_pasted_top_lint.log`, `/tmp/tb_pasted_review.sv`, `/tmp/mc_pasted_review_build.log` and `/tmp/mc_pasted_review_run.log`. The focused diagnostic checks the burst failure described above; it is not an end-to-end memory-controller regression. No candidate or repository RTL was changed.
