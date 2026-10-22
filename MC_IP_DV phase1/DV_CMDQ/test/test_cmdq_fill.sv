`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// TEST 1: Verify 32-entry capacity
class test_cmdq_fill extends mc_base_test;
  `uvm_component_utils(test_cmdq_fill)

  function new(string name = "test_cmdq_fill", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_fill_32 seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 1: test_cmdq_fill (32 Items)      ", UVM_LOW)
    `uvm_info("TEST", "==================================================", UVM_LOW)

    seq = seq_fill_32::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    phase.drop_objection(this);
  endtask
endclass : test_cmdq_fill
