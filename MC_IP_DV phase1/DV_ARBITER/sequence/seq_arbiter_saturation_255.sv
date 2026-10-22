`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_arbiter_saturation_255
// Testcase: test_arbiter_saturation_255
// Objective: Verify 8-bit counter saturation at 255 without wraparound.
// Pass Criteria: The counter reaches 8'hFF (255) and holds at 255 instead of
//                wrapping around to 0.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class seq_arbiter_saturation_255 extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_arbiter_saturation_255)

  function new(string name = "seq_arbiter_saturation_255");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    `uvm_info("SEQ", "=== [TEST 3] Starting 8-Bit Counter Saturation (255) Test ===", UVM_LOW)

    // -------------------------------------------------------------------------
    // Step 1: Age Slot 3 for 260 cycles without grant_ack
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 1: Incrementing wait counter of Slot 3 for 260 cycles (past 255 limit)...", UVM_LOW)
    for (int cycle = 0; cycle < 260; cycle++) begin
      req = mc_seq_item::type_id::create($sformatf("sat_c%0d", cycle));
      start_item(req);
      req.grant_ack = 1'b0;
      req.req_valid = (1 << 3);
      req.req_legal = (1 << 3);
      finish_item(req);

      if (cycle == 254) begin
        `uvm_info("SEQ", $sformatf("Cycle 255: Slot 3 wait_ctr reached = %0d", req.wait_ctr_observed[3]), UVM_MEDIUM)
      end
    end

    // -------------------------------------------------------------------------
    // Step 2: Check that counter saturated at exactly 255 (8'hFF)
    // -------------------------------------------------------------------------
    if (req.wait_ctr_observed[3] == 8'hFF) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Slot 3 wait_ctr saturated at 255 (did NOT wrap around)!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Counter failed to saturate at 255! Observed: %0d",
                 req.wait_ctr_observed[3]))
    end

    // -------------------------------------------------------------------------
    // Step 3: Compete against Slot 0 (counter = 0).
    // If Slot 3 had wrapped around to 0, Slot 0 would win by index tie-break (0 < 3).
    // But since Slot 3 saturated at 255, Slot 3 MUST win!
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "Step 2: Competing saturated Slot 3 (ctr=255) against Slot 0 (ctr=0)", UVM_LOW)
    req = mc_seq_item::type_id::create("sat_vs_slot0");
    start_item(req);
    req.grant_ack = 1'b0;
    req.req_valid = (1 << 0) | (1 << 3);
    req.req_legal = (1 << 0) | (1 << 3);
    finish_item(req);

    if (req.grant_idx_observed == 3) begin
      `uvm_info("SEQ", "[PASS] Verification Succeeded: Saturated Slot 3 (255) won against lower-index Slot 0 (0)!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("FAIL: Expected Slot 3 (ctr=255) to win, but Slot %0d won!",
                 req.grant_idx_observed))
    end

    `uvm_info("SEQ", "=== [TEST 3] Completed 8-Bit Counter Saturation Test ===", UVM_LOW)
  endtask
endclass : seq_arbiter_saturation_255
