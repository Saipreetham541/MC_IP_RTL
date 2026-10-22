`timescale 1ns/1ps

// =============================================================================
// Test: test_arbiter_saturation_255
// Description: Feature 2 - Test 3: Verify 8-bit counter saturation at 255
//              without wraparound.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class test_arbiter_saturation_255 extends mc_base_test;
  `uvm_component_utils(test_arbiter_saturation_255)

  function new(string name = "test_arbiter_saturation_255", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_arbiter_saturation_255 seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 3: test_arbiter_saturation_255            ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_arbiter_saturation_255::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 3: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_arbiter_saturation_255
