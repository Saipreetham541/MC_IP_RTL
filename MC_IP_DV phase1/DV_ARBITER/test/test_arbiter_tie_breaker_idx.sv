`timescale 1ns/1ps

// =============================================================================
// Test: test_arbiter_tie_breaker_idx
// Description: Feature 2 - Test 4: Check that the lower CMDQ slot index wins
//              when counter values are equal.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class test_arbiter_tie_breaker_idx extends mc_base_test;
  `uvm_component_utils(test_arbiter_tie_breaker_idx)

  function new(string name = "test_arbiter_tie_breaker_idx", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_arbiter_tie_breaker_idx seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", "  STARTING TEST 4: test_arbiter_tie_breaker_idx          ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    seq = seq_arbiter_tie_breaker_idx::type_id::create("seq");
    seq.start(env.agt.seqr);

    #100ns;
    `uvm_info("TEST", "Completed TEST 4: Dropping objection.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : test_arbiter_tie_breaker_idx
