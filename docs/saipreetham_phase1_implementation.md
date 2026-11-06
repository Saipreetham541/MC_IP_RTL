# Saipreetham Phase 1 Implementation

**Project:** MC16X2 HBM3 Memory Controller  
**Work area:** Single Pseudo Channel Core  
**Main sprint:** October 12 to October 30 2026

## My work

I worked on the RTL for one pseudo-channel core, a part of the memory controller that handles memory requests. I built the modules that store commands and data, track open memory rows, check waiting times, and choose the next command.

I first worked on the modules separately. I then connected them in `mc_pc_core` and improved the code. My main rule was to update the design only when the channel accepted a command.

## My timeline

| Period | My work |
| --- | --- |
| October 12 to 16 | Studied the design and worked on the command queue, data buffers, bank tracking, timing checks, refresh timer, and request selection. |
| October 19 to 24 | Reviewed the RTL, counter values, reset code, and module connections. Looked at ways to make the code clearer and the selection logic shorter. |
| October 26 to 30 | Connected the modules in the core and worked through the first basic tests. Checked how commands moved between the modules. |
| November 2 and 3 | Completed follow-up changes to the counter code and the core testbench. These changes were recorded after the main sprint. |

## How I built the modules

The design uses ACT to open a memory row and PRE to close it. A bank is a section of memory. The core checks which row is open in each bank before choosing a read or write.

### mc_refresh_engine

Memory needs refresh at regular intervals to keep its data. I used a countdown timer with a default interval of 3900 clock cycles.

When the timer ends, it raises a refresh request. I kept this request active until refresh was accepted, so waiting for the banks would not lose it. I also added a warning if the request was still waiting when the next interval ended. The timer reloads with the interval minus one to give the correct cycle count.

### mc_bank_state

I used a table to track 16 banks. Each bank stores whether it is open and which row is open. An accepted ACT opens a row, and an accepted PRE closes it.

This helps the core decide whether it can read or write now, needs to open a row, or needs to close another row first. I made the table change only after a command was accepted.

### mc_timing_check

I used counters to enforce the required gaps between memory commands. Some counters track one bank, while others track activity across the core. Four timers also limit how many rows can be opened close together.

My first version used helper functions to decrease the counters. I later wrote the decrease and zero check directly at each counter assignment. This made the code easier to follow. I checked that counters stopped at zero and that their starting values gave the correct waiting time.

### mc_cmdq

I built a queue with 32 command slots. Each slot stores the request ID, command type, address, and write-data location. New commands go into the first free slot.

The core can check every slot and choose a ready command. I kept the command stored while its row was being opened or closed. I removed it only after its read or write was accepted. I also added full and overflow checks to protect stored commands.

### mc_arbiter

This module chooses one command from the ready requests. I gave each slot an eight-bit waiting counter. A ready request gains priority as it waits. Equal counter values favor the lower slot number, and counters stop at 255.

I made the waiting counter reset when the selected operation was accepted. If the channel refused it, the request kept its priority. I also identified a balanced selection tree as a possible future improvement to shorten the selection path.

### mc_wdb

I built 16 slots to hold write data. Each slot stores a 32-bit word and four byte-mask bits. The matching command stores the slot number so it can find its data later.

I kept write data separate from the command queue to keep the queue small. A write can run only when its data is ready. Row preparation can happen earlier. I release the data slot after its contents have been safely captured for the write.

### mc_rdb

I used two queue stages to handle read results. The first stores request IDs when reads are accepted. The second pairs returning data with the oldest waiting ID and holds it until the receiver accepts it.

I counted all unfinished reads when checking space. This includes reads still waiting for memory and results already stored in the buffer. That prevents the core from accepting more reads than it can hold.

### mc_pc_core

I connected the seven modules in this core. It checks the command slots, bank state, timing counters, and available data space to choose the next operation.

I allowed row preparation before write data arrived or read-buffer space became free. I also gave refresh priority. The core closes open banks when safe, waits for the required delay, and then requests refresh. Bank state, timing loads, and command removal follow accepted commands.

## Improvements I made

I replaced the timing helper functions with direct counter expressions. I reviewed reset code and module connections to make the RTL easier to read and check.

I kept command storage and data storage separate. I allowed row preparation to continue while data or buffer space was still being arranged. I also kept waiting priority when a selected command was not accepted.

## Basic testing

I used a simple testbench to write one word and read it back. I fixed a missing write-buffer release connection and added checks for the returned data, request ID, and empty buffers at the end. The test passed and produced a waveform for review.

## What I learned

- A selected command must be accepted before it changes the stored bank or timing state.
- Counter starting values and clock edges must be checked carefully to avoid waiting one cycle too long or too little.
- Every buffer slot needs a clear point for allocation, use, and release.
- Requests to the same address need ordering rules when commands can run out of order.
- Short code can still create a long hardware path. Timing improvements need measurements.
- Small tests with automatic checks make it easier to find mistakes before connecting more cores.
