`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_arbiter_tie_breaker_idx
// Testcase: test_arbiter_tie_breaker_idx
// Objective: Check that the lower CMDQ slot index wins when counter values are equal.
// Pass Criteria: The lower binary index is granted; for example, slot 2 wins over slot 10.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class seq_arbiter_tie_breaker_idx extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_arbiter_tie_breaker_idx)

  function new(string name = "seq_arbiter_tie_breaker_idx");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    `uvm_info("SEQ", "=== [TEST 4] Starting Tie-Breaker by Lowest Slot Index Test ===", UVM_LOW)

    // -------------------------------------------------------------------------
    // Step 1: Equal Counter = 0 (Immediate competition between Slot 2 and Slot 10)
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 1: Competing Slot 2 and Slot 10 with equal counters (wait_ctr=0)", UVM_LOW)
    req = mc_seq_item::type_id::create("tie_at_zero");
    start_item(req);
    req.grant_ack = 1'b0;
    req.req_valid = (1 << 2) | (1 << 10);
    req.req_legal = (1 << 2) | (1 << 10);
    finish_item(req);

    if (req.grant_idx_observed == 2 && req.grant_valid_observed) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 2 won over Slot 10 at wait_ctr=0 (Lower index wins)!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Expected Slot 2 to win tie at ctr=0, but Slot %0d won!",
                 req.grant_idx_observed))
    end

    // -------------------------------------------------------------------------
    // Step 2: Age both Slot 2 and Slot 10 in lockstep so both reach counter = 5
    // We achieve this by having Slot 0 win each cycle without ack.
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 2: Aging both Slot 2 and Slot 10 in lockstep to wait_ctr=5", UVM_LOW)
    for (int cycle = 0; cycle < 5; cycle++) begin
      req = mc_seq_item::type_id::create($sformatf("lockstep_age_%0d", cycle));
      start_item(req);
      req.grant_ack = 1'b0;
      // Slot 0 is present, so Slot 0 wins by tie-break
      req.req_valid = (1 << 0) | (1 << 2) | (1 << 10);
      req.req_legal = (1 << 0) | (1 << 2) | (1 << 10);
      finish_item(req);
    end

    // -------------------------------------------------------------------------
    // Step 3: Now remove Slot 0. Slot 2 and Slot 10 both have wait_ctr = 5.
    // Verify Slot 2 wins again!
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 3: Competing Slot 2 and Slot 10 with equal non-zero counters (wait_ctr=5)", UVM_LOW)
    req = mc_seq_item::type_id::create("tie_at_five");
    start_item(req);
    req.grant_ack = 1'b0;
    req.req_valid = (1 << 2) | (1 << 10);
    req.req_legal = (1 << 2) | (1 << 10);
    finish_item(req);

    if (req.grant_idx_observed == 2) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 2 won over Slot 10 with equal wait_ctr=5 (Lower index wins)!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Expected Slot 2 to win tie at ctr=5, but Slot %0d won!",
                 req.grant_idx_observed))
    end

    `uvm_info("SEQ", "=== [TEST 4] Completed Tie-Breaker Test ===", UVM_LOW)
  endtask
endclass : seq_arbiter_tie_breaker_idx
