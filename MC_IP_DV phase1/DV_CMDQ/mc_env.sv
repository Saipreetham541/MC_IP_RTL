`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_env extends uvm_env;
  `uvm_component_utils(mc_env)

  mc_agent      agt;
  mc_scoreboard sb;

  function new(string name = "mc_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = mc_agent::type_id::create("agt", this);
    sb  = mc_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.ap.connect(sb.ap_imp);
  endfunction
endclass : mc_env
