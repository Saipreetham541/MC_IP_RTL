`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// TEST 2: Verify overflow rejection on 33rd push
class test_cmdq_overflow extends mc_base_test;
  `uvm_component_utils(test_cmdq_overflow)

  function new(string name = "test_cmdq_overflow", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_push_33 seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 2: test_cmdq_overflow (33 Items)  ", UVM_LOW)
    `uvm_info("TEST", "==================================================", UVM_LOW)

    seq = seq_push_33::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    phase.drop_objection(this);
  endtask
endclass : test_cmdq_overflow
