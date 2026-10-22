`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// TEST 1 SEQUENCE: Fill exactly 32
class seq_fill_32 extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_fill_32)

  function new(string name = "seq_fill_32");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;
    `uvm_info("SEQ", "Starting: Pushing 32 items to fill CMDQ", UVM_LOW)
    repeat (32) begin
      req = mc_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { push_val == 1'b1; pop_val == 1'b0; });
      finish_item(req);
    end
    #20;
    `uvm_info("SEQ", "Finished: 32 items pushed. Queue should be full.", UVM_LOW)
  endtask
endclass : seq_fill_32
