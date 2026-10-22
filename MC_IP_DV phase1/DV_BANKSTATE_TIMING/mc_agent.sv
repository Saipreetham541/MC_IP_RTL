`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_agent extends uvm_agent;
  `uvm_component_utils(mc_agent)

  mc_driver    drv;
  mc_monitor   mon;
  mc_sequencer seqr;

  function new(string name = "mc_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon  = mc_monitor::type_id::create("mon", this);
    drv  = mc_driver::type_id::create("drv", this);
    seqr = mc_sequencer::type_id::create("seqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass : mc_agent
