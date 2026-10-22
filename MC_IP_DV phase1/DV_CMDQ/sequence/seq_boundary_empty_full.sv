`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// =============================================================================
// TEST 4 SEQUENCE: Check queue behaviour at empty and full boundaries
// =============================================================================
class seq_boundary_empty_full extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_boundary_empty_full)

  function new(string name = "seq_boundary_empty_full");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    // -------------------------------------------------------------------------
    // Step 1: At Empty (0 items) -> Try popping (pop_val = 1)
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "=== [TEST 4] Step 1: Attempting pop on EMPTY queue (0 items) ===", UVM_LOW)
    req = mc_seq_item::type_id::create("empty_pop");
    start_item(req);
    req.push_val = 1'b0;
    req.pop_val  = 1'b1;
    req.pop_idx  = 5'd0;
    finish_item(req);

    // -------------------------------------------------------------------------
    // Step 2: At Full (32 items) -> Fill queue with 32 items
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "=== [TEST 4] Step 2: Filling queue with 32 items ===", UVM_LOW)
    for (int i = 0; i < 32; i++) begin
      req = mc_seq_item::type_id::create($sformatf("fill_%0d", i));
      start_item(req);
      assert(req.randomize() with {
        push_val == 1'b1;
        pop_val  == 1'b0;
      });
      finish_item(req);
    end

    // -------------------------------------------------------------------------
    // Step 3: Try 33rd push on full queue (should be blocked)
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "=== [TEST 4] Step 3: Attempting 33rd push on full queue ===", UVM_LOW)
    req = mc_seq_item::type_id::create("overflow_push");
    start_item(req);
    assert(req.randomize() with {
      push_val == 1'b1;
      pop_val  == 1'b0;
    });
    finish_item(req);

    // -------------------------------------------------------------------------
    // Step 4: Pop 1 slot (pop slot 0, size drops 32 -> 31)
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "=== [TEST 4] Step 4: Popping slot 0 (32 -> 31). cmdq_full should drop to 0 ===", UVM_LOW)
    req = mc_seq_item::type_id::create("pop_slot_0");
    start_item(req);
    req.push_val = 1'b0;
    req.pop_val  = 1'b1;
    req.pop_idx  = 5'd0;
    finish_item(req);

    // -------------------------------------------------------------------------
    // Step 5: Push 1 new item (size goes 31 -> 32, fills slot 0 again)
    // -------------------------------------------------------------------------
    `uvm_info("SEQ", "=== [TEST 4] Step 5: Pushing 1 item (31 -> 32). cmdq_full should re-assert ===", UVM_LOW)
    req = mc_seq_item::type_id::create("push_slot_0");
    start_item(req);
    assert(req.randomize() with {
      push_val == 1'b1;
      pop_val  == 1'b0;
    });
    finish_item(req);

    `uvm_info("SEQ", "=== [TEST 4] Finished Empty/Full Boundary Sequence ===", UVM_LOW)
  endtask
endclass : seq_boundary_empty_full
