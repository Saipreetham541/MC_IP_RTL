`timescale 1ns/1ps

// =============================================================================
// Interface: mc_if
// Description: Verification interface for Credit-Counter Arbiter (mc_arbiter).
//              Provides synchronous clocking blocks for driving request inputs
//              and sampling arbitration grants and internal wait counters.
// =============================================================================
interface mc_if (input logic clk, input logic rst_n);
  import mc_pkg::*;

  // ---------------------------------------------------------------------------
  // Arbiter Stimulus & Response Signals
  // ---------------------------------------------------------------------------
  logic [NUM_REQ-1:0]          req_valid;    // Slot occupied
  logic [NUM_REQ-1:0]          req_legal;    // Slot timing-legal this cycle
  logic                        grant_ack;    // 1 = winner consumed downstream
  logic [NUM_REQ-1:0]          grant;        // 1-hot winner mask
  logic [IDX_W-1:0]            grant_idx;    // Binary winner index
  logic                        grant_valid;  // 1 = at least one eligible candidate exists
  logic [NUM_REQ-1:0][CREDIT_CTR_WIDTH-1:0] wait_ctr; // Probed 8-bit wait counters

  // ---------------------------------------------------------------------------
  // Driver Clocking Block (drives inputs, samples grants & counters)
  // ---------------------------------------------------------------------------
  clocking drv_cb @(posedge clk);
    default input #1step output #100ps;
    output req_valid, req_legal, grant_ack;
    input  grant, grant_idx, grant_valid, wait_ctr;
  endclocking
  modport DRV (clocking drv_cb, input clk, input rst_n);

  // ---------------------------------------------------------------------------
  // Monitor Clocking Block (samples full bus transactions)
  // ---------------------------------------------------------------------------
  clocking mon_cb @(posedge clk);
    default input #1step output #100ps;
    input  req_valid, req_legal, grant_ack;
    input  grant, grant_idx, grant_valid, wait_ctr;
  endclocking
  modport MON (clocking mon_cb, input clk, input rst_n);

endinterface : mc_if
