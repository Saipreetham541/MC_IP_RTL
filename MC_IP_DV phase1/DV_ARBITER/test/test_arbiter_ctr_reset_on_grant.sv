`timescale 1ns/1ps

// =============================================================================
// Test: test_arbiter_ctr_reset_on_grant
// Description: Feature 2 - Test 2: Check that the selected command's counter
//              resets to 0 after issue (when grant_ack is asserted).
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class test_arbiter_ctr_reset_on_grant extends mc_base_test;
  `uvm_component_utils(test_arbiter_ctr_reset_on_grant)

  function new(string name = "test_arbiter_ctr_reset_on_grant", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_arbiter_ctr_reset_on_grant seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 2: test_arbiter_ctr_reset_on_grant        ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_arbiter_ctr_reset_on_grant::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 2: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_arbiter_ctr_reset_on_grant
