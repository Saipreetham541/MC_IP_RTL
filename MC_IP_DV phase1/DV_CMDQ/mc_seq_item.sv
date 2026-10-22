`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_seq_item extends uvm_sequence_item;
  `uvm_object_utils(mc_seq_item)

  rand bit                    push_val;
  rand bit                    pop_val;
  rand bit [CMDQ_ADDR_W-1:0]  pop_idx;
  rand cmd_entry_t            push_entry;

  bit                         cmdq_full_observed;
  bit                         cmdq_overflow_observed;

  constraint c_valid { push_val || pop_val; }

  function new(string name = "mc_seq_item");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("push=%0b pop=%0b idx=%0d | id=0x%02h wr=%0b row=0x%04h bg=%0d ba=%0d col=0x%02h | full=%0b ovf=%0b",
      push_val, pop_val, pop_idx,
      push_entry.axi_id, push_entry.is_write, push_entry.row, push_entry.bankgroup, push_entry.bank, push_entry.col,
      cmdq_full_observed, cmdq_overflow_observed);
  endfunction
endclass : mc_seq_item
