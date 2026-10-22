`timescale 1ns/1ps

// =============================================================================
// Test: test_arbiter_highest_ctr_wins
// Description: Feature 2 - Test 1: Verify selection of the eligible command
//              with the highest wait-counter value.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class test_arbiter_highest_ctr_wins extends mc_base_test;
  `uvm_component_utils(test_arbiter_highest_ctr_wins)

  function new(string name = "test_arbiter_highest_ctr_wins", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_arbiter_highest_ctr_wins seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 1: test_arbiter_highest_ctr_wins          ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_arbiter_highest_ctr_wins::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 1: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_arbiter_highest_ctr_wins
