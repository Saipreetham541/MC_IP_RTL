`timescale 1ns/1ps

// =============================================================================
// Class: mc_seq_item
// Description: UVM Sequence Item for MC16X2 HBM3 Memory Controller IP (mc_pc_core).
//              Encapsulates command entries pushed into CMDQ and observed transaction
//              snapshots for scoreboard verification.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

typedef enum bit [1:0] {
  MC_ITEM_PUSH      = 2'b00,
  MC_ITEM_ROW_ISSUE = 2'b01,
  MC_ITEM_COL_ISSUE = 2'b10
} mc_item_kind_e;

class mc_seq_item extends uvm_sequence_item;
  `uvm_object_utils(mc_seq_item)

  // ---------------------------------------------------------------------------
  // Stimulus Fields
  // ---------------------------------------------------------------------------
  rand mc_item_kind_e            kind;
  rand cmd_entry_t               entry;
  rand int unsigned              delay_cycles;

  // ---------------------------------------------------------------------------
  // Observed / Monitored Fields
  // ---------------------------------------------------------------------------
  bit                            cmdq_full;
  bit                            err_cmdq_overflow;
  row_cmd_e                      row_cmd;
  col_cmd_e                      col_cmd;
  bit [ROW_ADDR_W-1:0]           row_addr;
  bit [COL_ADDR_W-1:0]           col_addr;
  bit [BG_ADDR_W-1:0]            bg;
  bit [BANK_ADDR_W-1:0]          bank;
  bit [AXI_ID_W-1:0]             axi_id;
  bit                            is_ref;

  // Core Internal State Snapshots
  bit [TOTAL_BANKS-1:0]          bank_is_open_snap;
  bit [7:0]                      cnt_rcd_snap [TOTAL_BANKS-1:0];
  bit [7:0]                      cnt_rrd_snap;
  bit [CMDQ_DEPTH-1:0]           slot_valid_snap;
  bit [CMDQ_DEPTH-1:0]           slot_legal_snap;
  bit [CMDQ_ADDR_W-1:0]          grant_idx_snap;
  bit [CREDIT_CTR_WIDTH-1:0]     wait_ctr_snap [CMDQ_DEPTH-1:0];

  constraint c_delay {
    delay_cycles inside {[0:10]};
  }

  function new(string name = "mc_seq_item");
    super.new(name);
    kind         = MC_ITEM_PUSH;
    delay_cycles = 0;
  endfunction

  virtual function string convert2string();
    return $sformatf("kind=%s id=0x%02h wr=%0b bg=%0d ba=%0d row=0x%04h col=0x%02h",
                     kind.name(), entry.axi_id, entry.is_write, entry.bankgroup,
                     entry.bank, entry.row, entry.col);
  endfunction

endclass : mc_seq_item
