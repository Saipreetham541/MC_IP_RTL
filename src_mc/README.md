# MC16x2 memory-controller RTL

`mc16x2` connects one AXI4 slave port through clock-domain crossing and a
transaction backend to **16 channels / 32 pseudo-channel cores**. APB4 provides
configuration, status and interrupts. Each channel has shared row/column
arbitration and a DFI formatter, with separate 32-bit data lanes for its two PCs.

The default `AXI_ENABLE=1` configuration uses the AXI/APB path. A static
`AXI_ENABLE=0` diagnostic configuration preserves the decoded single-word
interface used by the independent core integration regression.

## File structure

```text
src_mc/
|-- README.md
|-- rtl/
|   |-- mc16x2.sv             AXI/APB-facing 16-channel / 32-PC top
|   |-- mc_axi_sub.sv         AXI transaction backend and address decode
|   |-- mc_axi_cdc.sv         Five AXI CDC FIFOs and reset-release synchronization
|   |-- mc_addr_decode.sv     Fixed address-field extraction
|   |-- mc_async_fifo.sv      Dual-clock storage and synchronized Gray pointers
|   |-- mc_csr.sv             Control/status register storage, counters and IRQ
|   |-- mc_apb_if.sv          APB4 transfer handling and bounded wait
|   |-- mc_sync_dfi.sv        Coherent APB request/response CDC bridge
|   |-- mc_pc_core.sv         Per-PC queues, scheduler and submodule integration
|   |-- mc_cmdq.sv            Command queue and slot allocation
|   |-- mc_wdb.sv             Write payload storage and allocation pointers
|   |-- mc_rdb.sv             Read-return storage and issue-ID tracking
|   |-- mc_bank_state.sv      Open-bank and open-row tracking
|   |-- mc_timing_check.sv    DRAM command timing counters
|   |-- mc_refresh_engine.sv  Per-PC periodic refresh
|   |-- mc_arbiter.sv         Credit-counter arbitration primitive
|   |-- mc_ch_arb.sv          Independent channel row/column arbitration
|   `-- mc_dfi_fmt.sv         Registered command packing and lane routing
`-- tb/
    |-- tb_mc16x2_axi.sv      End-to-end AXI/APB/CDC/PHY-model regression
    |-- tb_mc16x2.sv          Independent decoded 32-PC integration regression
    |-- tb_mc_core.sv         Single-PC write/read waveform demo
    |-- tb_mc_dfi_fmt.sv      Formatter unit test
    `-- tb_mc_async_fifo.sv   Asynchronous FIFO unit test
```

There are 18 RTL modules and five testbenches. Each module has one active
source definition. Generated build files and waveforms belong outside this tree.

## Connected hierarchy

```text
mc16x2
|-- g_axi                           AXI_ENABLE=1
|   |-- u_axi_cdc                   mc_axi_cdc
|   |   `-- AW / W / AR / B / R      five mc_async_fifo instances
|   |-- u_axi_sub                   mc_axi_sub
|   |   `-- u_addr_decode           mc_addr_decode
|   `-- u_csr                       mc_csr
|       |-- u_apb_if                mc_apb_if
|       `-- u_sync_dfi              mc_sync_dfi
`-- g_channel[0:15]
    |-- g_pc[0:1].u_pc_core         mc_pc_core
    |   |-- mc_cmdq / mc_wdb / mc_rdb
    |   |-- mc_bank_state / mc_timing_check
    |   `-- mc_arbiter / mc_refresh_engine
    |-- u_ch_arb                    row and column arbitration
    `-- u_dfi_fmt                   channel DFI formatter
```

The host AXI signals connect to `mc_axi_cdc`. In the DFI domain,
`mc_axi_sub` validates requests, generates beat addresses, selects CH/PC,
allocates commands/payloads and generates B/R responses. Responses return to
`aclk` through the same CDC set. Address decode is part of the backend, so
every generated beat address is decoded.

The backend has one active AXI burst at a time. AW and AR queues arbitrate
round-robin between bursts. This conservative implementation preserves per-ID
response ordering and write visibility; it does not exploit all PC cores for
simultaneously active AXI transactions. The CDC FIFOs can queue additional work.

## Clocks and resets

| Signal | Scope |
| --- | --- |
| `aclk` | Host AXI interface and AXI endpoints of the CDC FIFOs |
| `dfi_clk` | Backend, all 32 PC cores, lane transfer logic, channel arbiters, formatters and CSR storage |
| `pclk` | APB interface and APB endpoint of the coherent register bridge |
| `aresetn` | AXI transaction reset |
| `ctl_reset_n` | Controller transaction reset |
| `presetn` | APB bridge and configuration/status reset |

Asserting either `aresetn` or `ctl_reset_n` flushes the complete transaction
path, including both endpoints of all five AXI FIFOs and all core queues.
Reset release is synchronized independently to `aclk` and `dfi_clk`. FIFOs
advertise no transfers while their local reset is active. This coordinated
flush prevents old payloads or IDs surviving a one-sided reset.

APB configuration/status is retained across AXI/controller resets and clears
on `presetn`. External memory is not cleared by controller reset. Reset aborts
outstanding transactions and does not roll back already transferred write data.

APB request/response words remain stable until a synchronized toggle
acknowledgement; multi-bit configuration is not sampled through independent
bit synchronizers. All register reads/writes execute coherently in `dfi_clk`.

## AXI behavior

| Property | Current support |
| --- | --- |
| Data / address / ID | 256 / 40 / 8 bits |
| Channels | Independent AW, W, B, AR and R interfaces |
| Bursts | INCR, 1-16 beats; aligned sizes from 1 to 32 bytes per beat |
| Address checks | Alignment, 4-KiB boundary, reserved high bits and channel enable |
| Write data | AW/W association in order; W may arrive before AW |
| Byte enables | WSTRB checked against transfer lanes, then converted to active-high DFI byte-inhibit masks |
| Read data | Full beat assembly; unrequested narrow-transfer lanes return zero |
| Ordering | One active backend burst; FIFO-ordered B/R responses and per-ID ordering |
| Write completion | Posted B after accepted valid payloads and commands are owned by the cores |
| Read-after-write | New transactions wait for the preceding burst's physical write transfers to finish |
| Backpressure | Command/WDB capacity, CDC FIFO capacity, BREADY and RREADY |
| Unsupported requests | SLVERR for unsupported size/type/length, unaligned/cross-page requests, exclusive accesses or malformed write beats |
| Decode failures | DECERR for reserved address space or disabled channels |

Invalid write descriptors are drained according to AWLEN and return one B
response. Malformed WLAST or out-of-lane WSTRB causes SLVERR; an errored burst
may have earlier valid beats already committed and is not atomic. Invalid
reads return the requested number of error beats with correct RID/RLAST and
zero data. EXOKAY is never generated.

If write data does not arrive within the programmed timeout, the backend
returns SLVERR and latches a write-path fault. Further writes require an
AXI/controller reset to resynchronize AW/W association; reads and APB remain
available. Timeout zero disables this check. It measures DFI cycles waiting
for W data, not cycles stalled by core capacity.

A global disable stops new backend burst admission; work already accepted by
the backend drains. AXI FIFO ingress may still queue requests until those FIFOs
fill. Channel enables are checked when a burst is admitted.

## Address mapping and data transfer

| AXI address bits | Field |
| --- | --- |
| 39:33 | Reserved; must be zero |
| 32:29 | Channel 0-15 |
| 28 | PC0 or PC1 |
| 27:14 | Row |
| 13:12 | Bank group |
| 11:10 | Bank |
| 9:5 | Column |
| 4:0 | Byte offset within a 32-byte column |

The flattened PC index is `p = 2*channel + pc`. Channel 0 uses indices 0/1;
channel 15 uses 30/31. Each PC has 16 banks, organized as four groups of four.

In AXI mode, one column command corresponds to a **32-byte memory location**.
The WDB/RDB entries are configured as complete 256-bit AXI beats. A WR sends
eight consecutive 32-bit words, least-significant word first, starting on the
same edge as the formatted command. Its WDB pointer stays allocated until the
last word is captured. A RD expects eight ordered lane words, allowing gaps;
the top assembles the frame before presenting it to the core RDB/backend.

PC0 occupies channel data bits `[31:0]`, mask `[3:0]` and enable `[0]`; PC1 uses
`[63:32]`, `[7:4]` and `[1]`. Inactive write lanes are zero. RD enable marks the
column command; PHY return-valid identifies each subsequent lane word.

The current burst contract uses zero additional write-data offset. Per-PC
column spacing is conservatively eight clocks in AXI mode. Write recovery and
write-to-read guards include the seven additional data clocks, so tWR and tWTR
remain satisfied relative to the final write word. Row and column arbitration
are independent, and accepted grants feed back to the originating core.

The command entry remains 36 bits:

| Bits | Field |
| --- | --- |
| 35:28 | ID |
| 27 | Write=1, read=0 |
| 26:13 | Row |
| 12:11 | Bank group |
| 10:9 | Bank |
| 8:4 | Column |
| 3:0 | WDB pointer |

## Initial APB register map

This is a **project-defined initial map**. The architecture PDF does not provide
complete register fields or the companion RDL/IP-XACT source, and its high-level
ranges overlap. These offsets do not claim compatibility with an approved
vendor/software register reference.

All registers are 32 bits. Unaligned/unmapped accesses and writes to read-only
registers return PSLVERR. Writable fields honor PSTRB. APB waits are bounded to
16 ACCESS clocks; a timed-out request's eventual reply is not reused for the
next access.

| Offset | Register | Access / reset |
| --- | --- | --- |
| `0x000` | IP ID | RO, `0x4D431602` |
| `0x004` | Global enable, bit 0 | RW, 1 |
| `0x008` | Channel enables, bits 15:0 | RW, `0xFFFF` |
| `0x00C` | WDATA timeout in DFI clocks | RW, 1024; zero disables |
| `0x010` | Error status, bits 5:0 | RW1C, zero; new events dominate clearing |
| `0x014` | IRQ mask, bits 5:0 | RW, `0x3F`; mask bit 1 enables that source |
| `0x018` | Per-PC CMDQ-full vector | RO |
| `0x01C` | Per-PC WDB-full vector | RO |
| `0x020` | Per-PC RDB-valid vector | RO |
| `0x024` | Completed write-burst responses | RO, zero |
| `0x028` | Completed read-burst responses | RO, zero |
| `0x02C` | Backend active bit 0, write-faulted bit 1 | RO |

Response counters include error responses. They increment when the backend
enqueues B or the final R beat into CDC, before host-side response consumption.
They reset only with `presetn`.

| Error bit | Source |
| --- | --- |
| 0 | WDATA timeout |
| 1 | AXI validation/protocol error or unsolicited PHY return word |
| 2 | Any PC CMDQ overflow |
| 3 | Any PC WDB overflow |
| 4 | Any PC refresh-deadline miss |
| 5 | APB access error or timeout |

`irq` is the OR of sticky error bits enabled by the IRQ mask.

## Diagnostic decoded mode

With the static parameter `AXI_ENABLE=0`, AXI/APB outputs are inactive and the
original 32 per-PC decoded interfaces drive the cores directly. Each WDB/RDB
entry then holds one 32-bit word, and a column command transfers one lane word.
CMDQ/WDB/RDB depths remain 32/16/16 in both configurations.

In AXI mode the diagnostic command/payload/read-ready inputs are ignored; the
backend owns those interfaces. Existing per-PC fullness/error/valid outputs
remain observable. The legacy 32-bit `rdb_data[p]` output shows only the low
word of a full frame; host read data uses the 256-bit AXI R channel.

## Verification

| Testbench | Scope |
| --- | --- |
| `tb_mc16x2_axi` | Default AXI/APB path, all 32 PCs, beat serialization/assembly, narrow/masked transfers, burst errors, CDC capacity, response stalls, controls/IRQ, timeout and reset recovery |
| `tb_mc16x2` | Diagnostic decoded mode: independent PC contention, complete buffer capacity, simultaneous lane returns, randomized backpressure, timing and busy refresh |
| `tb_mc_core` | Focused single-PC ACT/WR/RD waveform and readback |
| `tb_dfi_formatter` in `tb_mc_dfi_fmt.sv` | Field packing, PC selection, data lanes and reset/strobes |
| `tb_mc_async_fifo` | FIFO ordering, fill/full, drain/empty and asynchronous clocks |

The AXI regression uses independently phased clocks and a seed-dependent AXI
period. Its reference memory is updated from accepted host write data; a
separate PHY model checks every serialized word/mask, tracks open rows, produces
read bursts with gaps, and checks timing from the final write data word.
Output scoreboards check IDs, response codes, RLAST, data and stall stability.

Directed cases cover W-before-AW, 16-beat and bank-crossing bursts, byte through
32-byte sizes, all 32 destinations, full AW/W/AR/B/R FIFOs, APB byte strobes,
RO/unmapped errors, stalled-clock APB timeout/late acknowledgement, global and
channel enables, IRQ masking/W1C, WDATA timeout, independent AXI/core resets,
CSR retention and first traffic immediately after reset release. The decoded
regression retains the larger randomized per-PC scheduling tests.

## Remaining implementation boundaries

The transaction path is connected and functional, but the initial backend is
serialized. Higher concurrency, the approved generated register map, full FIFO
occupancy/performance monitoring and the final per-PC attribute bookkeeping
remain future work. Cache/protection/QoS metadata crosses CDC but has no
scheduling or access-control effect in this implementation.

The eight-word DFI burst and zero-additional-write-offset behavior are the
current controller/model contract. Programmable PHY latency, initialization,
update and low-power control still need the selected PHY's requirements. The
simulations do not establish physical timing closure, structural CDC signoff
or complete HBM/DFI device compliance.
