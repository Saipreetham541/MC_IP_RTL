`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// =============================================================================
// TEST 3 SEQUENCE: Push 32 items, then pop slots 0 to 31 in order
// =============================================================================
class seq_pop_integrity extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_pop_integrity)

  function new(string name = "seq_pop_integrity");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;

    // Step 1: Push 32 commands (Cmd 0 to Cmd 31) into empty queue
    `uvm_info("SEQ", "=== [TEST 3] Step 1: Pushing 32 items (Cmd 0 to Cmd 31) ===", UVM_LOW)
    for (int i = 0; i < 32; i++) begin
      req = mc_seq_item::type_id::create($sformatf("push_%0d", i));
      start_item(req);
      assert(req.randomize() with {
        push_val == 1'b1;
        pop_val  == 1'b0;
      });
      finish_item(req);
    end

    // Step 2: Pop them in order from pop_idx = 0 to pop_idx = 31
    `uvm_info("SEQ", "=== [TEST 3] Step 2: Popping slots in order from 0 to 31 ===", UVM_LOW)
    for (int i = 0; i < 32; i++) begin
      req = mc_seq_item::type_id::create($sformatf("pop_%0d", i));
      start_item(req);
      req.push_val = 1'b0;
      req.pop_val  = 1'b1;
      req.pop_idx  = CMDQ_ADDR_W'(i);
      finish_item(req);
    end

    `uvm_info("SEQ", "=== [TEST 3] Completed 32 pushes and 32 pops in order ===", UVM_LOW)
  endtask
endclass : seq_pop_integrity
