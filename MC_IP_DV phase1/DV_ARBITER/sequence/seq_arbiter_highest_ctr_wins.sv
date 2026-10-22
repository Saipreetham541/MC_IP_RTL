`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_arbiter_highest_ctr_wins
// Testcase: test_arbiter_highest_ctr_wins
// Objective: Verify selection of the eligible command with highest wait-counter value.
// Pass Criteria: The Arbiter grants the eligible slot with the highest counter value,
//                even when other eligible slots have a lower slot index.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class seq_arbiter_highest_ctr_wins extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_arbiter_highest_ctr_wins)

  function new(string name = "seq_arbiter_highest_ctr_wins");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    `uvm_info("SEQ", "=== [TEST 1] Starting Highest Wait-Counter Selection Test ===", UVM_LOW)

    // -------------------------------------------------------------------------
    // Step 1: Age Slot 7 for 10 cycles while Slot 2 remains timing-blocked.
    // In each cycle, Slot 7 is eligible and loses/waits without issue -> wait_ctr[7]
    // increments: 0 -> 1 -> ... -> 10.
    // Slot 2 is blocked (req_legal[2]=0), so wait_ctr[2] remains 0.
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 1: Aging Slot 7 for 10 cycles while Slot 2 remains timing-blocked", UVM_LOW)
    for (int cycle = 0; cycle < 10; cycle++) begin
      req = mc_seq_item::type_id::create($sformatf("age_s7_c%0d", cycle));
      start_item(req);
      req.grant_ack = 1'b0;
      req.req_valid = (1 << 2) | (1 << 7); // Both slots valid
      req.req_legal = (1 << 7);            // Only Slot 7 legal
      finish_item(req);
    end

    // -------------------------------------------------------------------------
    // Step 2: Make BOTH Slot 2 and Slot 7 timing-legal.
    // Now:
    //   Slot 2: lower index (2 < 7), wait_ctr = 0
    //   Slot 7: higher index (7 > 2), wait_ctr = 10
    // Arbiter MUST select Slot 7 because wait_ctr[7] (10) > wait_ctr[2] (0)!
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 2: Both Slot 2 (ctr=0) and Slot 7 (ctr=10) are eligible. Verifying Slot 7 wins.", UVM_LOW)
    req = mc_seq_item::type_id::create("arb_compete");
    start_item(req);
    req.grant_ack = 1'b0;
    req.req_valid = (1 << 2) | (1 << 7);
    req.req_legal = (1 << 2) | (1 << 7); // Both legal now
    finish_item(req);

    // -------------------------------------------------------------------------
    // Step 3: Verify Winner
    // -------------------------------------------------------------------------
    if (req.grant_idx_observed == 7 && req.grant_valid_observed) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 7 won arbitration due to highest wait-counter (10 vs 0)!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Expected Slot 7 to win, but Slot %0d was granted (valid=%0b)!",
                 req.grant_idx_observed, req.grant_valid_observed))
    end

    `uvm_info("SEQ", "=== [TEST 1] Completed Highest Wait-Counter Selection Test ===", UVM_LOW)
  endtask
endclass : seq_arbiter_highest_ctr_wins
