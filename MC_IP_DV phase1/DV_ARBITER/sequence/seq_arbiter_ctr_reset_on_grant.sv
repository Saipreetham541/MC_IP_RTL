`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_arbiter_ctr_reset_on_grant
// Testcase: test_arbiter_ctr_reset_on_grant
// Objective: Check that the selected command's counter resets to 0 after issue.
// Pass Criteria: The granted slot's wait_ctr resets to 0 at the cycle specified
//                by the RTL when grant_ack is asserted.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class seq_arbiter_ctr_reset_on_grant extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_arbiter_ctr_reset_on_grant)

  function new(string name = "seq_arbiter_ctr_reset_on_grant");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    `uvm_info("SEQ", "=== [TEST 2] Starting Counter Reset on Grant Test ===", UVM_LOW)

    // -------------------------------------------------------------------------
    // Step 1: Age Slot 4 for 3 cycles first
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 1: Aging Slot 4 for 3 cycles first", UVM_LOW)
    for (int cycle = 0; cycle < 3; cycle++) begin
      req = mc_seq_item::type_id::create($sformatf("age_s4_%0d", cycle));
      start_item(req);
      req.grant_ack = 1'b0;
      req.req_valid = (1 << 4) | (1 << 5);
      req.req_legal = (1 << 4); // Only slot 4 legal
      finish_item(req);
    end

    // -------------------------------------------------------------------------
    // Step 2: Age both Slot 4 and Slot 5 for 2 more cycles
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 2: Aging both Slot 4 and Slot 5 for 2 more cycles", UVM_LOW)
    for (int cycle = 0; cycle < 2; cycle++) begin
      req = mc_seq_item::type_id::create($sformatf("age_s4_s5_%0d", cycle));
      start_item(req);
      req.grant_ack = 1'b0;
      req.req_valid = (1 << 4) | (1 << 5);
      req.req_legal = (1 << 4) | (1 << 5); // Both legal
      finish_item(req);
    end

    // -------------------------------------------------------------------------
    // Step 3: Slot 4 wins. Issue Slot 4 downstream with grant_ack = 1
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 3: Slot 4 is granted. Asserting grant_ack = 1 to issue command.", UVM_LOW)
    req = mc_seq_item::type_id::create("issue_slot4");
    start_item(req);
    req.grant_ack = 1'b1; // DOWNSTREAM CONSUMES/ISSUES WINNER
    req.req_valid = (1 << 4) | (1 << 5);
    req.req_legal = (1 << 4) | (1 << 5);
    finish_item(req);

    // -------------------------------------------------------------------------
    // Step 4: Next cycle: Verify Slot 4 counter has reset to 0!
    // Since Slot 4 counter reset to 0 and Slot 5 counter is >= 2,
    // Slot 5 MUST now win over Slot 4!
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 4: Checking that Slot 4 counter reset to 0 (Slot 5 now wins)", UVM_LOW)
    req = mc_seq_item::type_id::create("check_after_reset");
    start_item(req);
    req.grant_ack = 1'b0;
    req.req_valid = (1 << 4) | (1 << 5);
    req.req_legal = (1 << 4) | (1 << 5);
    finish_item(req);

    if (req.wait_ctr_observed[4] == 0) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 4 wait_ctr observed as 0 after issue!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Slot 4 counter did NOT reset to 0! Observed: %0d",
                 req.wait_ctr_observed[4]))
    end

    if (req.grant_idx_observed == 5) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 5 now wins arbitration because Slot 4 counter was reset!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Expected Slot 5 to win after Slot 4 reset, but Slot %0d won!",
                 req.grant_idx_observed))
    end

    `uvm_info("SEQ", "=== [TEST 2] Completed Counter Reset on Grant Test ===", UVM_LOW)
  endtask
endclass : seq_arbiter_ctr_reset_on_grant
