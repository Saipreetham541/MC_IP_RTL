`timescale 1ns/1ps

// =============================================================================
// Class: mc_driver
// Description: UVM Driver translating sequence items into cycle-accurate bus
//              transactions for mc_arbiter via clocking block drv_cb.
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
    mc_seq_item req;

    // Reset initial bus state
    vif.drv_cb.req_valid <= '0;
    vif.drv_cb.req_legal <= '0;
    vif.drv_cb.grant_ack <= 1'b0;

    // Wait for reset deassertion
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);

    forever begin
      seq_item_port.get_next_item(req);

      // Drive request inputs to DUT
      vif.drv_cb.req_valid <= req.req_valid;
      vif.drv_cb.req_legal <= req.req_legal;
      vif.drv_cb.grant_ack <= req.grant_ack;

      // Synchronize 1 full clock cycle
      @(vif.drv_cb);

      // Sample observed responses back into sequence item
      req.grant_observed       = vif.drv_cb.grant;
      req.grant_idx_observed   = vif.drv_cb.grant_idx;
      req.grant_valid_observed = vif.drv_cb.grant_valid;
      req.wait_ctr_observed    = vif.drv_cb.wait_ctr;

      // Reset 1-cycle active pulse
      vif.drv_cb.grant_ack <= 1'b0;

      seq_item_port.item_done();
    end
  endtask

endclass : mc_driver
