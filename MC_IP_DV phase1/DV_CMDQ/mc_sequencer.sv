`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_sequencer extends uvm_sequencer #(mc_seq_item);
  `uvm_component_utils(mc_sequencer)

  function new(string name = "mc_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : mc_sequencer
