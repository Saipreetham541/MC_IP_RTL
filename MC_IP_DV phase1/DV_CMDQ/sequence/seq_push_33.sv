`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// TEST 2 SEQUENCE: Push 33 to test overflow rejection
class seq_push_33 extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_push_33)

  function new(string name = "seq_push_33");
    super.new(name);
  endfunction

  task body();
    mc_seq_item req;
    `uvm_info("SEQ", "Starting: Pushing 33 items to test overflow rejection", UVM_LOW)
    repeat (33) begin
      req = mc_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { push_val == 1'b1; pop_val == 1'b0; });
      finish_item(req);
    end
    #20;
    `uvm_info("SEQ", "Finished: 33 items pushed. 33rd should be rejected.", UVM_LOW)
  endtask
endclass : seq_push_33
