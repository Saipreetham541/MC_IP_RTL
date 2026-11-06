# MC16X2 HBM3 Memory Controller IP
# Phase 1 — Single Pseudo-Channel Core Bring-Up

**Engineering Design & Implementation Report**  
**Sprint reporting window:** October 12–30, 2026  
**Architectural baseline requested:** MC16X2 Microarchitecture Specification, Rev 0.4; JESD238 HBM3 / DFI 5.0  
**Implementation reviewed:** `mc_pc_core` and seven leaf modules  
**Evidence review and simulation replay:** November 4, 2026  
**Repository baseline:** `980a443e9813e2eb481cc8805263a929b03b62b1`, including the existing working-copy `mc_arbiter.sv` changes

## Report basis and evidence conventions

This report organizes the engineering work into the requested three-week sprint narrative and checks its mechanisms against the available RTL, historical snapshots, and a fresh single-PC simulation. The supplied brief establishes the intended Rev 0.4 architecture. The actual Rev 0.4 specification document was not present among the supplied files or located in the project tree; clause-by-clause conformance therefore remains open. Timing values below are verified RTL defaults and supplied design requirements, rather than independently certified device timing limits.

The chronological headings describe the requested work breakdown. Available Git evidence records the first `Phase_1` snapshot on October 26, the inline-decrement refactor on November 2, and the current `tb_mc_core` on November 3. Those later artifacts substantiate the technical evolution but do not prove that every change was completed by October 30. Where an earlier failing revision or dated daily record is absent, the report identifies the work as a supplied sprint activity rather than inventing a historical result.

| Evidence class | Meaning in this report |
| --- | --- |
| Architectural requirement | Geometry, clocking, address map, and phase boundaries supplied in the brief; cross-checked against RTL where available |
| Inspected implementation | Behavior directly established by the current source files |
| Historical implementation | Behavior established by a named Git snapshot or diff |
| Replayed verification | Results produced on November 4 using the current working copy |
| Design target or follow-up | A proposed improvement, required check, or physical objective without signoff evidence |

The standards provide context for the architectural intent. The JEDEC-authored HBM3 standard describes independent channels, 64-bit channel data, 32-bit pseudo-channel operation, and separate row/column command interfaces. The project’s single-word behavioral model does not implement the complete HBM3 burst interface. See the [JEDEC JESD238A public preview](https://store.accuristech.com/products/preview/2522825). DFI specifies a controller-to-PHY interface; the custom packed buses in this repository require a PHY-specific integration contract before full interface conformance can be asserted. See the [DFI Group](https://ddr-phy.org/).

## 1. Executive summary and architectural context

Phase 1 establishes the scheduling and storage kernel for one HBM3 pseudo-channel. `mc_pc_core` accepts decoded memory commands and separately allocated write payloads, prepares DRAM rows, selects timing-legal commands out of order, reserves read-return capacity, and services periodic refresh. Every irreversible scheduler action is tied to a downstream grant.

The kernel comprises seven leaf modules: `mc_refresh_engine`, `mc_bank_state`, `mc_timing_check`, `mc_cmdq`, `mc_arbiter`, `mc_wdb`, and `mc_rdb`. They are discussed as six foundational design areas because the two data buffers form one area. The current implementation supports one selected command per PC per cycle, with independent row and column request interfaces for subsequent channel-level arbitration.

The fresh smoke replay passed one ACT → WR → RD → read-completion sequence. It returned `32'h1234_ABCD` with ID `8'h21`, released the write slot, and drained the command and response buffers. Measured command separations were 18 cycles from ACT to WR and 8 cycles from WR to RD. These results establish focused functional bring-up. They do not establish 1 GHz physical timing closure, exhaustive timing verification, or complete HBM3/DFI compliance.

### 1.1 Full-IP organization: 32 scheduling domains, 16 shared interfaces

MC16X2 is organized as **16 channels × 2 pseudo-channels = 32 independent scheduling domains**. Each PC owns its command pool, payload and response storage, bank-state table, timing state, refresh request, and scheduling arbiter. Two sibling PCs share one per-channel command/data interface and its channel arbiter/formatter.

The architectural names `dfi_row_ch<N>` and `dfi_col_ch<N>` identify the shared row and column buses of channel N. The current integrated source uses channel-indexed arrays such as `dfi_row[ch]` and `dfi_col[ch]`. They represent the same topology; there are 16 per-channel interface instances, rather than 32 independent PHY-facing interfaces.

| Resource | Per PC | Per channel / full IP |
| --- | --- | --- |
| Scheduling domain | One | Two per channel; 32 total |
| Bank organization | 4 BG × 4 BA = 16 banks | 32 banks across both PC state tables |
| Command queue | 32 × 36-bit entries | 64 entries per channel |
| Write data buffer | 16 × (32 data + 4 mask) bits | Two independent buffers |
| Read completion capacity | 16 outstanding reads | Two independent reservation domains |
| Data lane | 32 bits | 64 bits: PC0 `[31:0]`, PC1 `[63:32]` |
| Byte mask | 4 bits | 8 bits: PC0 `[3:0]`, PC1 `[7:4]` |
| Shared row command | Candidate fields before arbitration | 22-bit packed bus, including 1-bit `pc_sel` |
| Shared column command | Candidate fields before arbitration | 12-bit packed bus, including 1-bit `pc_sel` |

The inspected formatter packs the buses as follows:

```systemverilog
dfi_row <= {row_pc_sel, row_cmd[2:0], row_bg[1:0], row_ba[1:0], row_addr[13:0]};
dfi_col <= {col_pc_sel, col_cmd[1:0], col_bg[1:0], col_ba[1:0], col_addr[4:0]};
```

The row selector occupies bit 21; the column selector occupies bit 11. Data lanes and the two per-PC enable/return-valid bits preserve the same PC ordering. IDs and WDB pointers remain controller-side metadata; they are not transmitted as DRAM address fields. Packing is corroborated by [the formatter source][rtl-fmt].

### 1.2 Clocking and phase boundaries

| Domain | Intended frequency | Period | Architectural responsibilities |
| --- | ---: | ---: | --- |
| `aclk` | 500 MHz | 2 ns | AXI ingress, host-side transaction handling and response delivery |
| `pclk` | 50 MHz | 20 ns | APB/CSR programming and status access |
| `dfi_clk` | 1 GHz | 1 ns | PC scheduling, bank/timing state, channel arbitration and formatting |

These are three asynchronous domains in the architectural brief. A nominal 2:1 frequency relationship between `dfi_clk` and `aclk` does not establish synchronous phase alignment. AXI CDC and control/status crossings need explicit transfer protocols and reset treatment.

All Phase 1 state advances on the core port `clk`, connected to `dfi_clk` at integration. The core does not expose `aclk` or `pclk`, and no CDC is performed inside `mc_pc_core`. The current full-IP top accepts decoded single-word traffic; its standalone AXI/CDC support modules and planned APB subsystem do not establish a completed three-domain controller.

```text
                    aclk: 500 MHz                         dfi_clk: 1 GHz
 AXI4 host ──> AXI front end / CDC / address decoder ──> decoded PC traffic
                    Phase 3                                      |
                                                                 v
                  +------------- mc_pc_core / Phase 1 ----------------+
                  |                                                   |
 commands ------> | CMDQ (32 slots) ---> per-slot classify + legality   |
                  |                         |                         |
 payload -------> | WDB (16 slots) ------> credit arbiter (32-way)      |
                  |                         |                         |
                  | bank state <---- granted-command commit           |
                  | timing     <---- granted-command commit           |
                  | refresh -------> PRE-drain / REF priority         |
                  |                         |                         |
 completions <--- | RDB <--- PHY data + IDs recorded at granted RD     |
                  +-------------------------|-------------------------+
                                            | row / column candidates
                                            v
                                Channel arbiter, Phase 2
                                   ^                  |
                                   | matching grants  v
                                DFI formatter / PHY-facing path, Phase 4
                                            |
                                    shared channel interface

 pclk: 50 MHz ──> planned APB / CSR plane ──> explicit CDC to core controls/status
```

The block diagram shows architectural boundaries. In the unit test, an always-accepting grant model and a behavioral read-return model replace the downstream channel/PHY path.

### 1.3 Static 40-bit AXI4 address map

| Field | AXI address bits | Width | Meaning |
| --- | --- | ---: | --- |
| Unused upper bits | `[39:33]` | 7 | Not consumed by the inspected decoder |
| `CH_SEL` | `[32:29]` | 4 | Select one of 16 channels |
| `PC_SEL` | `[28]` | 1 | Select PC0 or PC1 within the channel |
| `ROW` | `[27:14]` | 14 | Row address |
| `BG` | `[13:12]` | 2 | Bank group |
| `BA` | `[11:10]` | 2 | Bank within group |
| `COL` | `[9:5]` | 5 | Column field |
| `Byte_Offset` | `[4:0]` | 5 | Byte position within a 32-byte address block |

```text
39      33 32     29 28 27           14 13 12 11 10 9       5 4       0
+---------+---------+--+---------------+-----+-----+---------+---------+
| unused  | channel |PC|      row      | BG  | BA  | column  | byte off|
+---------+---------+--+---------------+-----+-----+---------+---------+
```

[The decoder][rtl-decode] directly assigns these slices. Without an upper-address aperture check, addresses differing only in `[39:33]` alias. The Phase 1 interface has already removed channel, PC, and byte-offset fields. Its 32-bit payload is one word; AXI burst handling and 256-to-32-bit conversion must be specified upstream. A 5-bit byte offset does not make the current PC datapath a complete 32-byte transaction engine.

### 1.4 Complete `mc_pc_core` signal interface

Directions below are relative to `mc_pc_core`. Widths are the default elaborated widths. All interfaces are in the DFI clock domain after upstream CDC. The authoritative declarations are in [the core source][rtl-core].

| Signal | Direction | Width | Connection | Functional description |
| --- | --- | ---: | --- | --- |
| `clk` | In | 1 | DFI clock distribution | Core state clock, nominally 1 GHz |
| `rst_n` | In | 1 | Controller reset distribution | Active-low reset; synchronous in most leaves; current arbiter also asserts asynchronously |
| `cmd_push_val` | In | 1 | Upstream decoder/backend | Request to enqueue one decoded command; accepted when `!cmdq_full` |
| `cmd_push_entry` | In | 36 | Upstream decoder/backend | Packed ID, operation, row/BG/BA/column and WDB pointer |
| `cmdq_full` | Out | 1 | Upstream decoder/backend | Command admission backpressure |
| `wdb_push_val` | In | 1 | Upstream write-data backend | Request to allocate one payload; accepted when `!wdb_full` |
| `wdb_push_data` | In | 32 | Upstream write-data backend | PC write word |
| `wdb_push_mask` | In | 4 | Upstream write-data backend | Raw per-byte mask, passed through without interpretation |
| `wdb_alloc_ptr` | Out | 4 | Upstream command/data association | Lowest free WDB location; meaningful for allocation while not full |
| `wdb_full` | Out | 1 | Upstream write-data backend | Payload admission backpressure |
| `wdb_raddr` | In | 4 | Downstream write-data selector | Select stored payload for the accepted WR |
| `wdb_rdata` | Out | 32 | Downstream formatter/data path | Combinational selected payload |
| `wdb_rmask` | Out | 4 | Downstream formatter/data path | Combinational selected mask |
| `wdb_pop_val` | In | 1 | Downstream payload-capture completion | Release a payload slot after safe capture/transmission |
| `wdb_pop_ptr` | In | 4 | Downstream payload-capture completion | WDB slot being released |
| `dfi_rddata_valid` | In | 1 | Downstream formatter return path | One valid PC read-return word |
| `dfi_rddata` | In | 32 | Downstream formatter return path | Returned PC data, ordered by granted RD issue |
| `rdb_valid` | Out | 1 | Upstream read-response backend | Completion ID/data are available |
| `rdb_ready` | In | 1 | Upstream read-response backend | Consume current completion when also valid |
| `rdb_data` | Out | 32 | Upstream read-response backend | Oldest buffered returned word |
| `rdb_axi_id` | Out | 8 | Upstream read-response backend | ID associated with that word |
| `row_req_val` | Out | 1 | Channel row arbiter | Valid row candidate |
| `row_req_is_ref` | Out | 1 | Channel row arbiter | Refresh-service priority; covers refresh PRE and REF |
| `row_req_cmd` | Out | 3 | Channel row arbiter/formatter | NOP=`000`, ACT=`001`, PRE=`010`, REF=`100` |
| `row_req_addr` | Out | 14 | Channel row arbiter/formatter | Row address for ACT; default zero for PRE/REF |
| `row_req_bg` | Out | 2 | Channel row arbiter/formatter | Selected bank group |
| `row_req_bank` | Out | 2 | Channel row arbiter/formatter | Selected bank within group |
| `ch_arb_row_grant` | In | 1 | Channel row arbiter | Acceptance of this cycle’s row candidate |
| `col_req_val` | Out | 1 | Channel column arbiter | Valid column candidate |
| `col_req_cmd` | Out | 2 | Channel column arbiter/formatter | NOP=`00`, RD=`01`, WR=`10` |
| `col_req_addr` | Out | 5 | Channel column arbiter/formatter | Column address |
| `col_req_bg` | Out | 2 | Channel column arbiter/formatter | Selected bank group |
| `col_req_bank` | Out | 2 | Channel column arbiter/formatter | Selected bank within group |
| `col_req_wdb_ptr` | Out | 4 | Downstream write-data selector | WDB slot for WR; not a DRAM address field |
| `col_req_axi_id` | Out | 8 | Read issue tracker / controller metadata | Command ID; recorded by RDB on accepted RD |
| `ch_arb_col_grant` | In | 1 | Channel column arbiter | Acceptance of this cycle’s column candidate |
| `err_cmdq_overflow` | Out | 1 | Error/status collection | Combinational attempted command push while full |
| `err_wdb_overflow` | Out | 1 | Error/status collection | Combinational attempted payload push while full |
| `err_ref_deadline_miss` | Out | 1 | Interrupt/status collection | Registered one-cycle refresh deadline event |

There is no external PC-select port on the PC core: the enclosing channel knows which instance is PC0 or PC1 and adds the selector after arbitration. There is also no AXI B response, CSR interface, or internal `rdb_full` output at this boundary.

## 2. Chronological engineering sprint log

| Reporting period | Engineering focus | Technical exit artifact | Historical qualification |
| --- | --- | --- | --- |
| Week 1: Oct 12–16 | Microarchitecture decomposition and leaf RTL | Queue, buffers, bank table, timers, refresh and arbiter contracts | Supplied work allocation; leaf implementation visible in Oct 26 snapshot |
| Week 2: Oct 19–24 | Synthesizability, coding portability and path review | Inline decrement form, reset/port review, closure action list | Exact helper-to-inline diff committed Nov 2; earlier punctuation failures not preserved |
| Week 3: Oct 26–30 | PC integration and smoke-test diagnosis | Granted-commit integration and corrected self-checking unit-test architecture | Oct 26 smoke preserved; current corrected test committed Nov 3 |

### 2.1 Week 1 — October 12–16: microarchitecture and leaf RTL

#### 2.1.1 `mc_refresh_engine.sv`: periodic service with persistent request

[The refresh engine][rtl-refresh] implements a 13-bit periodic down-counter with `T_REFI = 3900`. At 1 ns per cycle, the configured interval is 3.9 μs. Reset and periodic expiration load `T_REFI - 1 = 3899`. From a reload edge, 3899 decrement edges reach zero and the next edge processes expiration, producing exactly 3900 edge intervals between expiration events.

`ref_req` is a retained request. Reaching zero asserts it; normal countdown cycles do not clear it. The core may therefore spend many cycles waiting for tRAS/tWR/tRTP, precharging banks, or losing channel arbitration without losing the pending service indication. `ref_ack` is asserted only when REF actually receives the row grant.

```systemverilog
// Extract of the implemented priority ordering inside always_ff.
ref_deadline_miss <= 1'b0;
if (ref_ack)
  ref_req <= 1'b0;

if (refi_counter == 13'd0) begin
  refi_counter <= T_REFI - 13'd1;
  ref_req <= 1'b1;
  if (ref_req && !ref_ack)
    ref_deadline_miss <= 1'b1;
end else begin
  refi_counter <= refi_counter - 13'd1;
end
```

The later nonblocking assignment wins if acknowledgment and expiration coincide: the old refresh is acknowledged and a new request remains asserted. If an earlier request is still pending at the next expiration without acknowledgment, `ref_deadline_miss` pulses for one cycle. Repeated unserviced windows produce repeated pulses.

This is a one-bit pending-service mechanism, **not a multi-refresh debt counter**. It preserves one request through draining and detects overdue service; it cannot count multiple missed obligations. Recovery from repeated deadline misses requires a system policy or a future counted-debt implementation. `T_REFI` must also be nonzero to avoid reload underflow. The engine is finite-width synchronous sequential logic with no simulation-only construct.

#### 2.1.2 `mc_bank_state.sv`: 16-bank open-row table

[The bank table][rtl-bank] stores `bank_is_open[15:0]` and sixteen 14-bit `open_row` elements. The bank index is a wiring concatenation:

```systemverilog
wire [BANK_IDX_W-1:0] flat_update_bank = {update_bg, update_bank};
```

At default geometry, BG selects the upper two bits and BA selects the lower two. Bank identity is therefore `4*BG + BA`. A granted ACT sets the open bit and replaces the row; a granted PRE clears the open bit. `cmd_preall_en` has priority and clears all open bits. The core connects it to `ref_ack`, conservatively closing the table on all-bank REF. Physical refresh preparation still uses individually granted PRE commands before REF.

| Bank observation for a queued command | Classification | Next required operation |
| --- | --- | --- |
| Open and stored row equals requested row | Page hit | RD or WR, subject to column timing and buffer capacity |
| Closed | Bank closed | ACT, subject to activation timing |
| Open with a different stored row | Page conflict | PRE, followed later by ACT and RD/WR |

PRE need not erase the remembered row: `bank_is_open` qualifies its validity. Reset clears open bits and uses a static loop to initialize rows. The small table and bounded loops are synthesizable; many parallel scheduler lookups favor registers/multiplexers rather than a simple single-port RAM.

#### 2.1.3 `mc_timing_check.sv`: command-spacing legality at 1 GHz

[The timing checker][rtl-timing] separates timing from open-row state. It consumes accepted command pulses, tracks minimum-spacing counters, and exposes one legality bit per bank for ACT/PRE/RD/WR plus one PC-wide REF legality bit. The core combines these timing permissions with bank state and resource readiness.

| Constraint | Default cycles / ns | Instances | Storage width | Loaded by accepted event | Blocks while nonzero |
| --- | ---: | ---: | ---: | --- | --- |
| tRCD | 18 | 16 | 8 bits | ACT to bank | RD/WR to that bank |
| tRAS | 34 | 16 | 8 bits | ACT to bank | PRE to that bank |
| tRP | 14 | 16 | 8 bits | PRE to bank | ACT to that bank; REF checks all banks |
| tRC | 50 | 16 | 8 bits | ACT to bank | Next ACT to that bank |
| tWR | 18 | 16 | 8 bits | WR to bank | PRE to that bank |
| tRTP | 8 | 16 | 8 bits | RD to bank | PRE to that bank |
| tRRD | 6 | 1 | 8 bits | Any PC ACT | Next ACT; also checked for REF in this RTL |
| tCCD | 4 | 1 | 8 bits | Any PC RD/WR | Next RD/WR |
| tWTR | 8 | 1 | 8 bits | Any PC WR | Next RD |
| tRFC | 350 | 1 | 10 bits | REF | All ACT/PRE/RD/WR and another REF |
| tFAW | 32 | 4 stages | 8 bits each | ACT inserts new timer | Fifth ACT while oldest of last four is active |

The inventory is **104 timers: `6×16 + 4 + 4`**. The supplied count of 102 is an arithmetic inconsistency. There are 103 eight-bit timers and one ten-bit timer, totaling 834 timer-state bits; this excludes the refresh-interval counter and other controller state.

For each bank `b`, the inspected legality equations are:

```text
legal_act[b] = zero(rp[b], rc[b], rrd, faw_timer[3]) AND !refresh_busy
legal_pre[b] = zero(ras[b], wr[b], rtp[b])          AND !refresh_busy
legal_rd[b]  = zero(rcd[b], ccd, wtr)              AND !refresh_busy
legal_wr[b]  = zero(rcd[b], ccd)                   AND !refresh_busy
legal_ref   = zero(all rp[], rrd)                 AND !refresh_busy
refresh_busy = (cnt_rfc != 0)
```

`zero(...)` means every listed counter equals zero. `legal_ref` does not itself establish that banks are closed; the core separately requires `any_bank_open == 0`. Likewise, ACT legality does not independently test whether a bank is open.

**Exact counter boundary.** If an ACT commits at edge `k`, tRCD loads 17 after that edge. The counter is 1 after `k+16`, zero after `k+17`, and the next accepting edge is `k+18`. Loading `T_PARAM - 1`, combined with pre-edge legality sampling, therefore yields a minimum separation of exactly `T_PARAM` edges.

```text
Edge                      k       k+1       ...      k+16    k+17    k+18
Accepted command          ACT                                      WR/RD
tRCD after edge           17       16       ...        1       0
Column eligibility        blocked until zero is visible before the accepting edge
ACT-to-column separation                                           18 cycles
```

Every active counter saturates at zero. Default decrements appear before command-specific loads in the same sequential block, so later loads override the decrement on an issue edge. Zero timing parameters are unsupported by the current `T-1` arithmetic.

**Four-activate window.** `faw_timer[0]` is the newest ACT and `[3]` the oldest retained ACT. Each cycle decrements every nonzero entry. On ACT, the previous entries shift toward index 3 using their decremented values, and index 0 loads 31. With ACTs at cycles 0, 6, 12, and 18, the first activation remains in the four-entry window until cycle 32; the fifth ACT is blocked until that boundary. The window stores residual lifetimes, rather than absolute timestamps.

These are compact, synthesizable finite counters. Their defaults implement the supplied bring-up timing model. Device-specific speed bins, temperature refresh rules, data/burst offsets, and any bank-group-specific distinctions still require comparison with the actual Rev 0.4 and chosen DRAM/PHY specifications. In particular, tWR here starts at WR issue; translating a device requirement referenced to write-data completion requires the corresponding PHY latency model.

#### 2.1.4 `mc_cmdq.sv`: a 32-entry out-of-order command pool

[CMDQ][rtl-cmdq] stores metadata separately from payloads. Its default entry is exactly 36 bits:

| Entry bits | Field | Width |
| --- | --- | ---: |
| `[35:28]` | `axi_id` | 8 |
| `[27]` | `is_write` | 1 |
| `[26:13]` | `row` | 14 |
| `[12:11]` | `bg` | 2 |
| `[10:9]` | `bank` | 2 |
| `[8:4]` | `col` | 5 |
| `[3:0]` | `wdb_ptr` | 4 |

```systemverilog
{axi_id[7:0], is_write, row[13:0], bg[1:0], bank[1:0], col[4:0], wdb_ptr[3:0]}
```

A combinational lowest-free-index search produces `free_idx`. An accepted push sets that slot’s valid bit and stores the entry. `slot_valid` and all `slot_data` elements are exposed in parallel, allowing the core to inspect all 32 requests rather than waiting for a FIFO head to become legal.

ACT and PRE are preparatory operations. They leave the command resident so the same transaction can later advance through PRE → ACT → column command. Only an accepted column operation retires the entry:

```systemverilog
// mc_pc_core connection to mc_cmdq
.pop_val (col_req_val && ch_arb_col_grant),
.pop_idx (cmdq_grant_idx)
```

`cmdq_full = &valid_reg`; `cmdq_overflow = push_val && cmdq_full`. A full queue rejects a push even if a pop occurs at the same edge, introducing a conservative boundary bubble. When not full, simultaneous pop and push target the occupied retiring slot and a previously free slot respectively. The metadata array and fixed-bound loops are synthesizable; parallel visibility limits conventional RAM inference.

#### 2.1.5 `mc_arbiter.sv`: eligible-age arbitration and acceptance acknowledgment

[The reusable arbiter][rtl-arb] defaults to `NUM_REQ=32` and `CREDIT_CTR_WIDTH=8`. Eligibility is `req_valid & req_legal`. The ascending-index selection scan replaces the winner only for a strictly greater age, so equal-age eligible requests favor the lowest index. In the core, `.req_priority('0)` disables the current arbiter’s additional priority class; refresh priority is handled by core dispatch.

For an occupied slot, the age counter behaves as follows:

| Condition | Age update |
| --- | --- |
| Slot invalid | Clear to zero |
| `grant[i] && grant_ack` | Clear to zero: selected work actually issued |
| Eligible, with no accepted grant | Increment unless already 255 |
| Occupied but illegal | Hold |

```systemverilog
if (!req_valid[i])
  wait_ctr[i] <= '0;
else if (grant[i] && grant_ack)
  wait_ctr[i] <= '0;
else if (eligible[i] && wait_ctr[i] != {CREDIT_CTR_WIDTH{1'b1}})
  wait_ctr[i] <= wait_ctr[i] + 1'b1;
```

An internally selected winner denied by the channel continues aging while eligible. A refresh-preempted candidate receives no acknowledgment, retaining or increasing its age rather than falsely appearing serviced. An accepted ACT or PRE also resets the selected slot’s age even though its command remains queued; this policy ages the wait for the next schedulable operation, rather than preserving total transaction age until completion.

Saturation bounds hardware cost and avoids wraparound reversal of priority. Aging improves progress under normal service conditions, but a universal transaction-latency bound requires assumptions about legality, refresh occupancy, downstream acceptance, and the traffic policy. It also does not resolve same-address dependencies.

The sequential counters are synthesizable. The current maximum-selection loop has an iteration dependency, making arbitration depth a timing-closure concern discussed in Week 2.

#### 2.1.6 `mc_wdb.sv` and `mc_rdb.sv`: decoupled payload and response storage

**Write data buffer.** [WDB][rtl-wdb] is a 16-entry random-access pool containing one 32-bit word and four raw mask bits per slot. Lowest-free allocation yields `wdb_alloc_ptr`, which the producer copies into the corresponding write command. `wdb_data_rdy[15:0]` directly exposes occupied slots. A page-hit WR is eligible only when its referenced slot is valid.

`wdb_raddr` selects data/mask combinationally, allowing downstream logic to capture the payload on the accepted WR edge. `wdb_pop_val` and `wdb_pop_ptr` release ownership once capture is safe. Full/overflow behavior mirrors CMDQ: push while full is rejected and reported; same-edge consumption does not bypass full admission.

The producer must allocate a payload and its pointer consistently. Merely putting a future pointer into CMDQ does not reserve that empty WDB slot against another allocation. Delayed payload arrival needs upstream ownership or reservation discipline. The core can prepare rows early, but does not supply an independent reservation protocol.

**Read data buffer.** [RDB][rtl-rdb] separates two logical FIFO stages:

```text
granted RD + AXI ID ──> id_fifo ──> oldest in-flight ID ──┐
                                                        +──> {data_fifo, ret_id_fifo}
PHY return, in issue order ──────────────────────────────┘                |
                                                           rdb_valid/ready completion
```

`id_wr_ptr` advances at accepted RD; `id_rd_ptr` advances when a valid return consumes an in-flight ID. The returned data and that ID are written together to `data_fifo` and `ret_id_fifo`. `data_wr_ptr` counts paired returns, and `data_rd_ptr` counts consumed completions. Five-bit pointers contain the four-bit storage index plus a wrap bit at depth 16.

The central capacity invariant is:

```systemverilog
wire [RDB_ADDR_W:0] outstanding_cnt = id_wr_ptr - data_rd_ptr;
assign rdb_full = (outstanding_cnt == RDB_DEPTH[RDB_ADDR_W:0]);
```

Thus `outstanding_cnt = PHY-in-flight reads + locally buffered completions`. Reserving capacity at RD issue prevents overflowing a return buffer that cannot backpressure the PHY. With 16 outstanding reads, no further RD issues until a completion is consumed, even if some returns have not yet arrived. While `rdb_ready=0`, the response read pointer holds and valid ID/data remain stable.

Return ordering must be preserved independently within each PC. RDB restores the ID associated with DRAM issue order; it does not implement AXI acceptance-order reconstruction. An unsolicited return is ignored when the in-flight ID FIFO is empty. A first issue and return on the same edge with no older ID do not have a zero-latency bypass. The current pointer indexing assumes power-of-two depth. These interface assumptions are essential to its lossless-flow-control argument.

Both buffers use finite arrays and sequential ownership/pointer updates. WDB’s asynchronous read and RDB’s exposed head data constrain memory mapping; synthesizability does not imply any particular SRAM macro inference.

### 2.2 Week 2 — October 19–24: RTL quality and synthesizability refinements

#### 2.2.1 Inline saturating decrement: semantic preservation and portability

The historical Phase 1 checker uses `dec8` and `dec10` helper functions. Commit `01d527f` replaces them with explicit ternary expressions, including the decremented source values used during tFAW shifts. This is directly supported by the Git diff, although its commit date is November 2.

```systemverilog
// Before: historical Phase_1/mc_timing_check.sv
function automatic [7:0] dec8(input logic [7:0] val);
  return (val > 8'd0) ? (val - 8'd1) : 8'd0;
endfunction

// Inside always_ff:
cnt_rrd <= dec8(cnt_rrd);
cnt_rfc <= dec10(cnt_rfc);
```

```systemverilog
// After: current implementation, representative assignments
cnt_rrd <= (cnt_rrd > 8'd0) ? (cnt_rrd - 8'd1) : 8'd0;
cnt_rfc <= (cnt_rfc > 10'd0) ? (cnt_rfc - 10'd1) : 10'd0;

for (int i = 0; i < TOTAL_BANKS; i++) begin
  cnt_rcd[i] <= (cnt_rcd[i] > 8'd0) ? (cnt_rcd[i] - 8'd1) : 8'd0;
  // Same form for ras, rp, rc, wr and rtp.
end

// During an ACT, preserve decrement while shifting the old window entries.
faw_timer[3] <= (faw_timer[2] > 8'd0) ? (faw_timer[2] - 8'd1) : 8'd0;
```

The refactor makes widths, zero saturation, and load/decrement ordering locally visible across all **104 timer registers**. It avoids helper-return parsing differences in restricted front ends and simplifies code inspection. Automatic combinational functions are themselves synthesizable in capable SystemVerilog tools; removing them does not inherently reduce gates or improve frequency. Physical benefit must be measured separately.

#### 2.2.2 1 GHz critical-path analysis and the “less than six levels” target

At a 1 ns clock period, launch/capture overhead, skew, uncertainty and interconnect consume part of the cycle. The usable logic delay is therefore less than 1 ns. The main scheduler path is structurally:

```text
bank / timer / buffer registers
    → indexed bank and row lookup + timer-zero evaluation
    → per-slot ACT/PRE/RD/WR eligibility
    → 32-request age arbitration
    → winning 36-bit metadata selection
    → repeated winner bank/row classification + dispatch
    → channel arbitration / grant
    → state, timer, queue and age-update enables
```

The exact endpoint depends on the integrated implementation; the standalone test replaces channel arbitration with direct acceptance. A critical-path claim must include both request generation and the grant-to-commit feedback path.

A balanced 32-way tournament needs `log2(32)=5` **compare/select stages**. A node should compare candidate validity, priority if used, age, then index; on equal ages it must retain the lower index. Those five stages are an architectural depth measure. An eight-bit comparator and its select mux may map to multiple cell levels, and legality, metadata muxing, dispatch, channel arbitration and routing add further delay.

The inspected arbiter is an ascending running-maximum scan, not an explicit balanced tree. Synthesis may transform it, but the source alone does not establish that transformation. Consequently, **“less than six logic levels” is a closure objective, not a demonstrated property of the complete path**, and even a five-stage arbitration tree cannot establish it for the entire scheduler.

| Path concern | Engineering action | Evidence needed |
| --- | --- | --- |
| Dependent 32-entry max scan | Implement/measure a balanced tournament preserving tie policy | Equivalence plus mapped timing |
| Winner mux followed by repeated row comparison | Reuse per-slot page-hit/bank-open classification or command kind | Accepted-command trace equivalence and path comparison |
| Dynamic bank indexing and row-table fanout | Share predecode where beneficial; inspect placement/fanout | Mapped netlist and timing reports |
| First-free / refresh priority scans | Measure hierarchical encoder alternatives if critical | Allocator and refresh path reports |
| Large timer/control fanout | Localize common terms and examine buffering | Fanout, slew, congestion and slack |
| WDB data capture path | Check pointer-to-data mux delay separately from scheduler control | Formatter data setup timing |

**Resource gating at the correct scheduling stage.** The core computes payload/response readiness but consumes it only for page hits:

```systemverilog
data_buf_ok = slot_entry.is_write
            ? wdb_data_rdy[slot_entry.wdb_ptr] : !rdb_full;

if (!slot_valid[i])
  slot_legal[i] = 1'b0;
else if (bank_is_open[b_idx] && open_row[b_idx] == slot_entry.row)
  slot_legal[i] = data_buf_ok &&
                (slot_entry.is_write ? legal_wr[b_idx] : legal_rd[b_idx]);
else if (!bank_is_open[b_idx])
  slot_legal[i] = legal_act[b_idx];
else
  slot_legal[i] = legal_pre[b_idx];
```

ACT/PRE preparation may overlap write-data arrival or the wait for RDB space. This reduces avoidable scheduling stalls without consuming absent payloads or unreserved read-return capacity. It may still activate a row that waits for data or is later displaced; performance depends on workload and scheduling policy.

#### 2.2.3 Port syntax, reset initialization and lint review

The intended ANSI module form separates parameter and port lists and terminates the port list once:

```systemverilog
module example #(
  parameter int DEPTH = 16
) (
  input logic clk,
  input logic rst_n
);
  // Implementation.
endmodule
```

For parameterized modules, `) (` is the correct boundary, and `);` closes the ports. Commas must separate successive port declarations and named instance connections. All seven leaf modules and the core parse in the fresh Verilator build. Earlier malformed-header revisions were not preserved in the inspected history, so the specific punctuation repairs are recorded as supplied sprint cleanup rather than reproduced failures.

Unpacked array reset assignment needs an assignment pattern or element-wise loop. A packed-vector reset alone is not a portable replacement for an unpacked array reset:

```systemverilog
// Aggregate form retained in the current mc_arbiter:
wait_ctr <= '{default: '0};

// Static loop form used for current bank rows and CMDQ entries:
for (int i = 0; i < TOTAL_BANKS; i++) open_row[i] <= '0;
for (int i = 0; i < CMDQ_DEPTH; i++) entries[i] <= '0;
```

Both describe finite hardware initialization in supporting synthesis tools. Static loops improve compatibility with restricted parsers. Neither implies runtime software iteration. Resetting wide data arrays also has implementation cost; removing such resets is a separate change that must preserve valid-bit qualification and externally required reset behavior.

The current arbiter includes a priority input absent from the original Oct 26 primitive. Its core instance explicitly ties it off:

```systemverilog
.req_valid    (slot_valid),
.req_legal    (slot_legal),
.req_priority ('0),
.grant_ack    (cmdq_arb_ack),
```

The unsized fill literal adapts to the formal vector width. This keeps all CMDQ requests in the same priority class and avoids an unconnected input. Port alignment improves reviewability; the explicit connection determines behavior.

The November 4 `--Wall` lint run completed with five warnings: two unused waveform/test signals, unused metadata fields in legality evaluation, the behavioral clock’s blocking assignment, and mixed synchronous/asynchronous reset use. No latch, undriven-signal, missing-port or combinational-loop warning appeared in this invocation. The current working-copy arbiter uses `posedge clk or negedge rst_n`, while the other core leaves use synchronous active-low reset. Reset-style consistency and release synchronization remain integration decisions; the core’s synchronous-reset comment does not fully describe the present working copy.

### 2.3 Week 3 — October 26–30: core integration and self-checking simulation

#### 2.3.1 Integration of all seven leaf modules

`mc_pc_core` evaluates all 32 occupied CMDQ slots against the live bank, timing, WDB and RDB state every cycle. The arbiter selects one eligible slot. Dispatch then emits its next required operation: page hit → column command; closed bank → ACT; row conflict → PRE.

The core intentionally separates **candidate selection** from **accepted command commit**:

```systemverilog
assign issue_act = row_req_val && (row_req_cmd == ROW_CMD_ACT)
                 && ch_arb_row_grant;
assign issue_pre = row_req_val && (row_req_cmd == ROW_CMD_PRE)
                 && ch_arb_row_grant;
assign issue_rd  = col_req_val && (col_req_cmd == COL_CMD_RD)
                 && ch_arb_col_grant;
assign issue_wr  = col_req_val && (col_req_cmd == COL_CMD_WR)
                 && ch_arb_col_grant;

assign cmdq_arb_ack = (|cmdq_grant) && !ref_req &&
                     ((row_req_val && ch_arb_row_grant) ||
                      (col_req_val && ch_arb_col_grant));
```

| Accepted operation | Bank-state update | Timing loads | Queue/buffer action |
| --- | --- | --- | --- |
| ACT | Open selected bank at requested row | tRCD, tRAS, tRC, tRRD, tFAW | Keep CMDQ entry; acknowledge arbiter operation |
| PRE | Close selected bank | Selected-bank tRP | Keep CMDQ entry; acknowledge normal arbitration if not refresh |
| RD | No open-row change | tCCD, selected-bank tRTP | Pop CMDQ; reserve RDB ID/capacity; acknowledge arbiter |
| WR | No open-row change | tCCD, tWTR, selected-bank tWR | Pop CMDQ; downstream safely captures/releases WDB; acknowledge arbiter |
| REF | Clear all open-bank bits via `ref_ack` | tRFC | Acknowledge refresh; keep queued normal commands |

Bank update BG/BA/row come from the row candidate. The timing checker’s `active_bank_idx` selects row fields when `row_req_val` is high, otherwise column fields. This is valid because this core emits only one row-or-column candidate at a time.

#### 2.3.2 Automatic top-priority refresh draining

Pending refresh preempts normal command dispatch, including otherwise legal columns. This stops new operations from extending the drain interval. Each cycle the core scans for the lowest-index bank that is both open and legally prechargeable, returning `refresh_pre_bank_idx` and `refresh_pre_valid`.

```text
ref_req=1
   |
   +-- any_bank_open=1 -- legal PRE candidate? -- yes --> row PRE, is_ref=1
   |                                               grant --> close that bank
   |                                               deny  --> retry without commit
   |                         no --> wait for recovery counters
   |
   +-- any_bank_open=0 -- legal_ref=1 --> row REF, is_ref=1
                                grant --> ref_ack, load tRFC, clear pending request
                                deny  --> request remains pending
```

The scan may bypass a lower-index open bank whose PRE is still illegal and close another ready bank first. At most one bank closes per granted PRE. REF waits for every open bit to clear and for every tRP counter to expire. The core does not issue a physical PREALL command: timing checker `issued_preall` is tied low. Bank-state `cmd_preall_en=ref_ack` is a defensive state cleanup at accepted REF after individual draining has already closed the banks.

After REF, tRFC blocks all normal commands. Losing arbitration never advances the drain state, reloads timing, or clears `ref_req`. The fresh short smoke test ends before the 3900-cycle interval, so this refresh path is established here by source inspection rather than that replay.

#### 2.3.3 Root cause of the original `tb_mc_smoke` problem

The Oct 26 `Phase_1/tb_mc_smoke.sv` declares PHY-facing row/column/data signals but instantiates no DFI formatter to drive them. Its release path nevertheless depends on a formatter output:

```systemverilog
// Historical testbench: no instance drives dfi_wrdata_en_ch0.
assign wdb_pop_val = |dfi_wrdata_en_ch0;
assign wdb_pop_ptr = write_ptr;
```

With four-state uninitialized `logic`, the undriven enable is unknown, so the reduction does not produce a known asserted release. In a two-state simulation it may become zero, concealing the X symptom while still failing to release ownership. `wdb_raddr` is also undriven. As a result, printed ACT/WR/RD activity or eventual `$finish` cannot establish correct payload selection or WDB recycling.

The failure is a testbench integration defect: a transaction side effect was sourced from an absent component. The historical test also returns a fixed `32'hCAFE_1234`, uses a different read column and ID, and has no end-to-end data scoreboard. It can demonstrate control activity without proving write/read data integrity.

#### 2.3.4 Corrected `tb_mc_core` architecture

[The current testbench][tb-core] directly models the unit boundary. It grants row and column requests whenever reset is released, always accepts RDB completions, and explicitly provides write-payload capture/release:

```systemverilog
assign row_req_grant = rst_n && row_req_val;
assign col_req_grant = rst_n && col_req_val;
assign wr_fire = col_req_grant && (col_req_cmd == COL_CMD_WR);

assign wdb_raddr   = col_req_wdb_ptr;
assign wdb_pop_val = wr_fire;
assign wdb_pop_ptr = col_req_wdb_ptr;
```

A granted write captures `wdb_rdata` into `memory_word` at the same edge that releases the slot. A granted read starts `return_delay=READ_LATENCY`, where `READ_LATENCY=5`. The model drives the saved word and valid when the delay reaches its terminal count.

| Item | Test setting |
| --- | --- |
| Clock | `always #0.5 clk = ~clk`, 1 ns period |
| Address | BG 0, BA 0, row `14'h0123`, column `5'h04` |
| Write payload | `32'h1234_ABCD` |
| Write mask | `4'b0000`, checked as a raw value |
| Write / read ID | `8'h11` / `8'h21` |
| Read model | One word; five-cycle delay to drive return valid |
| Completion consumer | Always ready after reset |
| Watchdog | 200 cycles |
| Waveform | `tb_mc_core.vcd`, optionally overridden by `+vcd=<path>` |

The model does not implement masked byte updates, bursts, PHY training, programmable data offsets or multiple concurrent memory locations. Its one-word scope is appropriate for this focused core bring-up.

The 64-bit ASCII waveform label `phase` tracks:

```text
RESET → IDLE → WRITE → IDLE → READ → DONE
0 ns    4 ns    8 ns   31 ns   35 ns   46 ns
```

Clocked `$fatal` checks reject unexpected error flags, row/column addresses, command order, duplicate operations, write data/mask/ID/pointer mismatch, and returned data/ID mismatch. The stimulus additionally checks WDB release after WR and checks complete drain at the end. Assertions run throughout the short scenario, but the current test contains **no explicit elapsed-cycle assertions for tRCD, tCCD or tWTR**. Those spacings must be measured independently or checked by an additional monitor.

The implemented readback check illustrates the distinction between a self-checking result and a printed transaction trace:

```systemverilog
if (read_done) begin
  if (!read_seen || return_seen ||
      rdb_data !== TEST_DATA || rdb_axi_id !== READ_ID)
    $fatal(1, "Readback data or ID mismatch");
  return_seen <= 1'b1;
end
```

The case-inequality comparisons also reject unknown payload/ID bits in a four-state simulator. The two-state Verilator replay verifies their binary values; it does not establish four-state X propagation behavior.

#### 2.3.5 Replayed waveform and measured timing

The November 4 replay used Verilator 5.020 with timing, tracing and assertion support. The test completed successfully. The VCD uses 1 ps resolution; the following table records actual sampling edges. Console `$time` output in this run shows integer-nanosecond values, so the VCD is the timing reference.

| Event | VCD edge / transition | Observation |
| --- | ---: | --- |
| Granted ACT | 12.5 ns | Bank 0 opens row `0123` |
| Granted WR | 30.5 ns | 18 cycles after ACT; data `1234_ABCD`, mask `0`, ID `11` |
| Granted RD | 38.5 ns | 8 cycles after WR; ID `21` |
| Model drives return-valid/data | 43.5 ns, after edge | Five cycles after RD |
| RDB samples return-valid/data | 44.5 ns | One edge after the model’s nonblocking drive |
| Consumer accepts RDB completion | 45.5 ns | Data `1234_ABCD`, ID `21` |
| Phase reaches DONE | 46.0 ns | Final drain check follows four additional cycles |

```text
Accepted-command edge      12.5                 30.5       38.5
                           ACT ----18 cycles---- WR --8---- RD
                              tRCD=18                max(tCCD=4,tWTR=8)

Read-return sequence       38.5       43.5       44.5       45.5 ns
                           RD --5--> drive --1--> capture --1--> consume
                                             RDB output valid after capture
```

The measured ACT→WR spacing meets the configured tRCD exactly. WR→RD meets both the four-cycle tCCD and eight-cycle tWTR, with tWTR controlling this case. The model’s five-cycle return delay is not the entire RD-to-consumer latency: sequential drive/capture and completion presentation add two edge intervals in this test.

The test’s final conditions require ACT, WR, RD and return to have been seen; CMDQ valid bits and WDB ready bits to be zero; and no RDB completion to remain. A PASS proves those checks for this stimulus. It does not exercise denied grants, refresh, full buffers, arbitrary response stalls, or multiple same-address outstanding requests.

Replayed evidence is retained in [the test log][evi-log], [the waveform][evi-vcd], [the lint log][evi-lint] and [the timing/source manifest][evi-json]. The manifest records hashes of all nine compiled sources, including the pre-existing working-copy arbiter changes.

## 3. Key takeaways, architectural corner cases and engineering learnings

### 3.1 Speculative request and granted commit must remain separate

A candidate is a request for shared command bandwidth. It has no DRAM effect until the downstream arbiter accepts it. Updating bank state on an ungranted ACT would manufacture a false open row; reloading timing on a denied command would measure spacing from an event that never occurred. Popping CMDQ on an ungranted column loses the transaction, and resetting age on selection deprives a denied request of its accumulated priority.

The implemented contract is therefore consistent across state domains: granted ACT/PRE drive bank updates, granted commands load timers, granted RD/WR pop CMDQ, granted RD reserves an ID, and accepted normal operations acknowledge arbitration. WDB release is separately tied to safe payload capture. Refresh acknowledgment is an accepted REF, never mere REF candidacy.

If downstream buffering is added, the meaning of “grant” must remain explicit. Either it guarantees the effective command issue edge, or timing must be referenced to a later confirmed issue event. Silent insertion of variable acceptance-to-PHY latency would invalidate the current spacing model.

### 3.2 Decoupled command/data buffering improves progress under a precise ownership contract

CMDQ carries a four-bit WDB pointer rather than a 32-bit payload or a 256-bit AXI-side beat. Small metadata entries can be inspected in parallel, while payload storage remains independently allocated. Row preparation can proceed before data arrives; a missing payload blocks only that write’s final column command. Another eligible request may still issue.

RDB reserves capacity from RD issue through consumer acceptance. Counting only completed data would undercount PHY-in-flight reads and permit an overflow that cannot be corrected by deasserting ready toward the PHY. The implemented `id_wr_ptr - data_rd_ptr` invariant avoids that failure under the stated ordered-return and admission assumptions.

Neither structure eliminates all blocking. Full resources, shared-bank conflicts and ordering restrictions still limit progress. WDB pointer ownership must survive delays, and response storage must not be reused until its consumer accepts the result. Reset during in-flight traffic also needs a PHY/backend flush contract so stale returns cannot be paired with IDs from a new reset epoch.

### 3.3 Out-of-order scheduling requires same-address hazard protection

Lowest-free-slot allocation is not transaction order. A newer command can reuse a low slot while an older command occupies a higher one. Lowest-index arbitration on equal age therefore cannot establish RAW or WAW ordering.

For example, an older write in slot 10 may wait for its payload while a newer read to the same bank/row/column occupies slot 0. Once the row is open, the read can be legal while the write is ineligible, exposing stale memory data. Two writes can similarly be reordered, leaving the wrong final value. Eligible-only aging and resets after preparatory ACT/PRE do not provide dependency tracking.

The integration contract needs either upstream serialization of overlapping addresses or scheduler-visible order/age tags with dependency masking. Hazard comparison should include the relevant byte/burst overlap and mask semantics, not merely an exact column equality if upstream transfers cover multiple words. AXI ID restoration alone does not enforce these dependencies or AXI response-order requirements.

The current unit test waits for the write before issuing its read, so it validates a serialized case. It does not demonstrate hardware hazard resolution.

### 3.4 Concurrent row and column issue needs two bank identities

The current PC selects one transaction and emits either a row or a column command. At channel level, a row from one PC and a column from its sibling can issue together because their timing/state trackers are separate.

To support simultaneous row and column issue **within the same PC**, splitting arbitration alone is insufficient. The timing checker has one `issued_bank`. If ACT to bank A and WR to bank B occurred together, the current interface could load both sets of per-bank counters using one bank identity.

```systemverilog
// Proposed future interface; not implemented in the reviewed RTL.
input logic [BANK_IDX_W-1:0] issued_row_bank;
input logic [BANK_IDX_W-1:0] issued_col_bank;
```

ACT/PRE loads would use `issued_row_bank`; RD/WR recovery loads would use `issued_col_bank`. The design would also need independent candidate selection, grant-qualified retirement/age updates, same-cycle legality checks, and well-defined shared-counter load precedence. Refresh must exclude incompatible column traffic. Separate ports are necessary for correctness, but are only one part of the upgrade.

### 3.5 Designing for a 1 GHz single-clock core

The main lesson is to preserve semantic clarity while making expensive logic visible. Parallel slot legality avoids a serial search through commands, but the winning path still includes indexed state, age comparison, metadata selection, dispatch and downstream grant. A compact procedural loop may describe a deep dependency chain. A tournament tree exposes logarithmic comparison depth, but physical closure still depends on mapped cells, fanout, placement and wiring.

Useful closure work starts with a reproducible synthesis/STA setup: target library and corner, a 1 ns clock constraint, uncertainty, I/O assumptions, and actual path endpoints. Counter inlining, aggregate reset spelling, or a theoretical five-stage tree cannot substitute for slack reports. Optimizations should preserve accepted command traces and be measured under identical constraints.

Self-checking tests should be built before scaling to 32 PCs. This bring-up demonstrates why: an absent formatter allowed apparently plausible command activity while write-buffer ownership never completed. Explicit boundary models, pointer/data checks, watchdogs, and buffer-drain assertions make unit results meaningful before integration multiplies the debugging surface.

### 3.6 Verification closure and remaining engineering work

| Requirement / corner case | Evidence in this report | Next closure step |
| --- | --- | --- |
| ACT/WR/RD and correct data/ID | Fresh single-PC PASS | Retain as a fast bring-up regression |
| Exact tested tRCD/tCCD/tWTR spacing | Independent VCD measurement | Add reusable command-edge timing assertions for boundary/negative cases |
| Request retained through grant denial | Inspected grant-qualified design | Exercise extended row/column denial and compare all state updates |
| Refresh drain and tRFC | Inspected source | Simulate open-bank drain, missed deadline, expiry/ack coincidence and post-REF blocking |
| WDB/RDB capacity and simultaneous events | Inspected admission/pointer logic | Check full/empty boundaries, wrap, stalls, delayed payload and ownership |
| RAW/WAW and AXI ordering | Hazard identified; no tracker established | Define serialization/dependency/reorder contract before general traffic |
| Reset consistency and stale returns | Mixed-style lint warning; short reset exercised | Specify reset release and in-flight flush; verify recovery |
| All 32 PCs and channel sharing | Beyond the fresh Phase 1 replay | Run integration regression separately against its own source manifest |
| Less than six logic levels / 1 GHz | Architectural target only | Map, constrain and analyze the complete implementation |
| Strict Rev 0.4 / DRAM / PHY conformance | Rev 0.4 document unavailable | Review actual specification clauses, device timings and PHY interface contract |

The repository includes a later full-core regression with additional timing and integration checks. Its existence is useful follow-on context; its previous README results are not counted as rerun evidence in this report.

## Appendix A. Implementation and history traceability

| Topic | Primary inspected artifact |
| --- | --- |
| PC interfaces, all-slot evaluation, refresh priority, accepted pulses | [`mc_pc_core.sv`][rtl-core] |
| Refresh interval and acknowledgment/expiry priority | [`mc_refresh_engine.sv`][rtl-refresh] |
| Open bits, remembered rows and PREALL priority | [`mc_bank_state.sv`][rtl-bank] |
| Default timings, legality and tFAW shift/decrement | [`mc_timing_check.sv`][rtl-timing] |
| Metadata packing, first-free allocation, overflow and retirement | [`mc_cmdq.sv`][rtl-cmdq] |
| Eligible ages, saturation, strict tie rule and reset style | [`mc_arbiter.sv`][rtl-arb] |
| Payload allocation, read selection and release | [`mc_wdb.sv`][rtl-wdb] |
| Issue IDs, ordered pairing and outstanding reservation | [`mc_rdb.sv`][rtl-rdb] |
| Static address slicing | [`mc_addr_decode.sv`][rtl-decode] |
| Packed row/column buses and split data lanes | [`mc_dfi_fmt.sv`][rtl-fmt] |
| Current one-word behavioral memory and checks | [`tb_mc_core.sv`][tb-core] |
| Original Phase 1 sources and defective smoke hookup | Git `6dc34fc`, October 26: `Phase_1/` snapshot |
| Helper-function-to-inline refactor | Git `01d527f`, November 2: `Phase_1/mc_timing_check.sv` diff |
| Historical optimization assessment | Git `01d527f`: `Phase_1/OPTIMIZATION_REVIEW.md`; text dated October 30, committed November 2 |
| Consolidated source tree and current unit test | Git `75414c2`, November 3 |

The historical optimization review discusses experimental tournament arbitration and other possible changes. Those experiments are not evidence that the reviewed production arbiter is balanced, and their generic synthesis figures are not physical timing or area signoff.

Existing modifications in `mc16x2.sv`, `mc_arbiter.sv`, and `mc_ch_arb.sv` were present before this documentation task and were left unchanged. The smoke build includes only `mc_arbiter.sv` from that modified set. Source hashes in the manifest distinguish the tested working copy from clean HEAD.

## Appendix B. Reproduction and retained evidence

Run from the repository root. This builds the single-PC test only; it does not elaborate the full 16-channel top. Build products and a fresh waveform go to `/tmp`.

```bash
mkdir -p /tmp/mc16x2_phase1_report

verilator --binary --timing --trace --assert -Wno-fatal \
  --top-module tb_mc_core \
  --Mdir /tmp/mc16x2_phase1_report/obj \
  src_mc/tb/tb_mc_core.sv \
  src_mc/rtl/mc_pc_core.sv \
  src_mc/rtl/mc_cmdq.sv \
  src_mc/rtl/mc_wdb.sv \
  src_mc/rtl/mc_rdb.sv \
  src_mc/rtl/mc_refresh_engine.sv \
  src_mc/rtl/mc_bank_state.sv \
  src_mc/rtl/mc_timing_check.sv \
  src_mc/rtl/mc_arbiter.sv

/tmp/mc16x2_phase1_report/obj/Vtb_mc_core \
  +vcd=/tmp/mc16x2_phase1_report/tb_mc_core.vcd
```

For the lint invocation, replace `--binary --trace --assert` with `--lint-only --Wall`, retain `--timing -Wno-fatal`, and use the same top and sources. Warnings were retained for review rather than suppressed individually.

| Retained artifact | Contents |
| --- | --- |
| [Simulation log][evi-log] | ACT/WR/RD/completion messages and PASS |
| [VCD waveform][evi-vcd] | Timestamped clock, requests, phases, payload and core state |
| [Lint log][evi-lint] | All five warnings from the focused build |
| [Verification summary][evi-json] | Sampled event times, phase transitions, spacing checks, tool version, HEAD and source SHA-256 hashes |

For independent timing inspection, sample `act_fire`, `wr_fire`, `rd_fire`, `dfi_rddata_valid` and `read_done` immediately before rising `clk` edges. Distinguish the post-edge drive of return-valid at 43.5 ns from its RDB sampling at 44.5 ns. The source-level `$fatal` checks establish payload, identity and drain results; the separate waveform inspection establishes the measured spacings reported here.

[rtl-core]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_pc_core.sv
[rtl-refresh]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_refresh_engine.sv
[rtl-bank]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_bank_state.sv
[rtl-timing]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_timing_check.sv
[rtl-cmdq]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_cmdq.sv
[rtl-arb]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_arbiter.sv
[rtl-wdb]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_wdb.sv
[rtl-rdb]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_rdb.sv
[rtl-decode]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_addr_decode.sv
[rtl-fmt]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/rtl/mc_dfi_fmt.sv
[tb-core]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/src_mc/tb/tb_mc_core.sv
[evi-log]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/docs/phase1_report_evidence/tb_mc_core.log
[evi-vcd]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/docs/phase1_report_evidence/tb_mc_core.vcd
[evi-lint]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/docs/phase1_report_evidence/verilator_lint.log
[evi-json]: /home/sai-preetham/Documents/Work/MC_IP_RTL/Busbridges/docs/phase1_report_evidence/verification_summary.json
