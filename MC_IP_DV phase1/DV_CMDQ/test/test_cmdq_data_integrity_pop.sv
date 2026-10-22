`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// =============================================================================
// TEST 3: Verify pop data integrity in order 0 to 31
// =============================================================================
class test_cmdq_data_integrity_pop extends mc_base_test;
  `uvm_component_utils(test_cmdq_data_integrity_pop)

  function new(string name = "test_cmdq_data_integrity_pop", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_pop_integrity seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 3: test_cmdq_data_integrity_pop           ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_pop_integrity::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 3: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_cmdq_data_integrity_pop
