`timescale 1ns/1ps

// =============================================================================
// Class: mc_base_test
// Description: Base test for MC16X2 HBM3 Memory Controller IP (mc_pc_core).
//              Instantiates environment and retrieves virtual interface.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_base_test extends uvm_test;
  `uvm_component_utils(mc_base_test)

  mc_env         env;
  virtual mc_if  vif;

  function new(string name = "mc_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mc_if)::get(this, "", "mc_vif", vif)) begin
      if (!uvm_config_db#(virtual mc_if)::get(null, "*", "mc_vif", vif))
        `uvm_fatal("BASE_NO_VIF", "Virtual interface mc_if not found in config_db!")
    end
    env = mc_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  // Synchronize to stable state post-reset
  task wait_reset();
    wait (vif.rst_n === 1'b1);
    @(posedge vif.clk);
    #1ps;
  endtask

endclass : mc_base_test
