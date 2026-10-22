`timescale 1ns/1ps

// =============================================================================
// Class: mc_monitor
// Description: UVM Monitor sampling mc_arbiter signals on every posedge clk
//              and broadcasting observed transactions to the scoreboard.
// =============================================================================
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

      // Capture transactions on any arbiter activity
      if ((vif.mon_cb.req_valid != 0) || vif.mon_cb.grant_valid || vif.mon_cb.grant_ack) begin
        item = mc_seq_item::type_id::create("mon_item");

        item.req_valid            = vif.mon_cb.req_valid;
        item.req_legal            = vif.mon_cb.req_legal;
        item.grant_ack            = vif.mon_cb.grant_ack;
        item.grant_observed       = vif.mon_cb.grant;
        item.grant_idx_observed   = vif.mon_cb.grant_idx;
        item.grant_valid_observed = vif.mon_cb.grant_valid;
        item.wait_ctr_observed    = vif.mon_cb.wait_ctr;

        ap.write(item);
      end
    end
  endtask

endclass : mc_monitor
