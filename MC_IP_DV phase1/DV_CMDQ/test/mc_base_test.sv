`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_base_test extends uvm_test;
  `uvm_component_utils(mc_base_test)

  mc_env env;

  function new(string name = "mc_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mc_env::type_id::create("env", this);
  endfunction
endclass : mc_base_test
