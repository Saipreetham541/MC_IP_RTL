`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_monitor extends uvm_monitor;
  `uvm_component_utils(mc_monitor)

  virtual mc_if vif;
  uvm_analysis_port #(mc_seq_item) ap;

  function new(string name = "mc_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mc_if)::get(this, "", "mc_vif", vif)) begin
      if (!uvm_config_db#(virtual mc_if)::get(null, "*", "mc_vif", vif))
        `uvm_fatal("NO_VIF", "Monitor: virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    mc_seq_item item;

    wait (vif.rst_n === 1'b1);
    @(vif.mon_cb);

    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.push_val || vif.mon_cb.pop_val) begin
        item = mc_seq_item::type_id::create("mon_item");
        item.push_val               = vif.mon_cb.push_val;
        item.push_entry             = vif.mon_cb.push_entry;
        item.pop_val                = vif.mon_cb.pop_val;
        item.pop_idx                = vif.mon_cb.pop_idx;
        item.cmdq_full_observed     = vif.mon_cb.cmdq_full;
        item.cmdq_overflow_observed = vif.mon_cb.cmdq_overflow;

        ap.write(item);
      end
    end
  endtask
endclass : mc_monitor
