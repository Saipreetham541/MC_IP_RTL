`timescale 1ns/1ps

// =============================================================================
// Class: mc_driver
// Description: UVM Driver translating sequence items into cycle-accurate bus
//              transactions for mc_pc_core via interface clocking block drv_cb.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_driver extends uvm_driver #(mc_seq_item);
  `uvm_component_utils(mc_driver)

  virtual mc_if vif;

  function new(string name = "mc_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mc_if)::get(this, "", "mc_vif", vif)) begin
      if (!uvm_config_db#(virtual mc_if)::get(null, "*", "mc_vif", vif))
        `uvm_fatal("NO_VIF", "Driver: virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.cmd_push_val   <= 1'b0;
    vif.drv_cb.cmd_push_entry <= '0;

    // Wait for reset deassertion
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(mc_seq_item item);
    @(vif.drv_cb);
    repeat (item.delay_cycles) @(vif.drv_cb);

    if (item.kind == MC_ITEM_PUSH) begin
      vif.drv_cb.cmd_push_val   <= 1'b1;
      vif.drv_cb.cmd_push_entry <= item.entry;
      @(vif.drv_cb);
      vif.drv_cb.cmd_push_val   <= 1'b0;
      vif.drv_cb.cmd_push_entry <= '0;
    end
  endtask

endclass : mc_driver
