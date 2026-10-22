`timescale 1ns/1ps

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
    mc_seq_item req;

    vif.drv_cb.push_val   <= 1'b0;
    vif.drv_cb.push_entry <= '0;
    vif.drv_cb.pop_val    <= 1'b0;
    vif.drv_cb.pop_idx    <= '0;

    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);

    forever begin
      seq_item_port.get_next_item(req);

      if (req.push_val) begin
        vif.drv_cb.push_val   <= 1'b1;
        vif.drv_cb.push_entry <= req.push_entry;
      end else begin
        vif.drv_cb.push_val   <= 1'b0;
      end

      if (req.pop_val) begin
        vif.drv_cb.pop_val    <= 1'b1;
        vif.drv_cb.pop_idx    <= req.pop_idx;
      end else begin
        vif.drv_cb.pop_val    <= 1'b0;
      end

      @(vif.drv_cb);

      vif.drv_cb.push_val <= 1'b0;
      vif.drv_cb.pop_val  <= 1'b0;

      seq_item_port.item_done();
    end
  endtask
endclass : mc_driver
