`timescale 1ns/1ps

// =============================================================================
// Class: mc_monitor
// Description: UVM Monitor observing upstream command pushes and scheduled
//              Row/Column command grants on every posedge clk.
//              Broadcasts observed items to scoreboard for verification.
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

      if (vif.rst_n) begin
        // 1. Observe Upstream Command Push
        if (vif.mon_cb.cmd_push_val) begin
          item = mc_seq_item::type_id::create("p_item");
          item.kind              = MC_ITEM_PUSH;
          item.entry             = vif.mon_cb.cmd_push_entry;
          item.cmdq_full         = vif.mon_cb.cmdq_full;
          item.err_cmdq_overflow = vif.mon_cb.err_cmdq_overflow;
          ap.write(item);
        end

        // 2. Observe Row Command Issue (ACT, PRE, REF)
        if (vif.mon_cb.row_req_val && vif.mon_cb.ch_arb_row_grant) begin
          item = mc_seq_item::type_id::create("r_item");
          item.kind              = MC_ITEM_ROW_ISSUE;
          item.row_cmd           = vif.mon_cb.row_req_cmd;
          item.row_addr          = vif.mon_cb.row_req_addr;
          item.bg                = vif.mon_cb.row_req_bg;
          item.bank              = vif.mon_cb.row_req_bank;
          item.is_ref            = vif.mon_cb.row_req_is_ref;
          item.bank_is_open_snap = vif.mon_cb.dbg_bank_is_open;
          item.slot_valid_snap   = vif.mon_cb.dbg_slot_valid;
          item.slot_legal_snap   = vif.mon_cb.dbg_slot_legal;
          item.grant_idx_snap    = vif.mon_cb.dbg_grant_idx;
          item.cnt_rrd_snap      = vif.mon_cb.dbg_cnt_rrd;
          for (int b = 0; b < TOTAL_BANKS; b++) begin
            item.cnt_rcd_snap[b] = vif.dbg_cnt_rcd[b];
          end
          ap.write(item);
        end

        // 3. Observe Column Command Issue (RD, WR)
        if (vif.mon_cb.col_req_val && vif.mon_cb.ch_arb_col_grant) begin
          item = mc_seq_item::type_id::create("c_item");
          item.kind              = MC_ITEM_COL_ISSUE;
          item.col_cmd           = vif.mon_cb.col_req_cmd;
          item.col_addr          = vif.mon_cb.col_req_addr;
          item.bg                = vif.mon_cb.col_req_bg;
          item.bank              = vif.mon_cb.col_req_bank;
          item.axi_id            = vif.mon_cb.col_req_axi_id;
          item.bank_is_open_snap = vif.mon_cb.dbg_bank_is_open;
          item.slot_valid_snap   = vif.mon_cb.dbg_slot_valid;
          item.slot_legal_snap   = vif.mon_cb.dbg_slot_legal;
          item.grant_idx_snap    = vif.mon_cb.dbg_grant_idx;
          item.cnt_rrd_snap      = vif.mon_cb.dbg_cnt_rrd;
          for (int b = 0; b < TOTAL_BANKS; b++) begin
            item.cnt_rcd_snap[b] = vif.dbg_cnt_rcd[b];
          end
          ap.write(item);
        end
      end
    end
  endtask

endclass : mc_monitor
