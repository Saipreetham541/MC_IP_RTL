`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// =============================================================================
// TEST 4: Verify queue behaviour at empty and full boundaries
// =============================================================================
class test_cmdq_boundary_empty_full extends mc_base_test;
  `uvm_component_utils(test_cmdq_boundary_empty_full)

  function new(string name = "test_cmdq_boundary_empty_full", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_boundary_empty_full seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 4: test_cmdq_boundary_empty_full          ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_boundary_empty_full::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 4: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_cmdq_boundary_empty_full
