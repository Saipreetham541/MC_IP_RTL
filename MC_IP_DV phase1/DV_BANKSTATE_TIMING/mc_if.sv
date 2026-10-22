`timescale 1ns/1ps

// =============================================================================
// Interface: mc_if
// Description: Verification interface for MC16X2 HBM3 Memory Controller IP (mc_pc_core).
//              Provides synchronous clocking blocks for driving command inputs and
//              grant signals, and sampling scheduled command outputs and internal
//              bank timing state down-counters.
// =============================================================================
interface mc_if (input logic clk, input logic rst_n);
  import mc_pkg::*;

  // ---------------------------------------------------------------------------
  // Upstream Command Push Interface
  // ---------------------------------------------------------------------------
  logic                      cmd_push_val;
  cmd_entry_t                cmd_push_entry;
  logic                      cmdq_full;
  logic                      err_cmdq_overflow;

  // ---------------------------------------------------------------------------
  // Downstream Channel Arbiter Grant Handshakes (Stimulus to Core)
  // ---------------------------------------------------------------------------
  logic                      ch_arb_row_grant;
  logic                      ch_arb_col_grant;

  // ---------------------------------------------------------------------------
  // Scheduled Row Command Outputs from Core
  // ---------------------------------------------------------------------------
  logic                      row_req_val;
  logic                      row_req_is_ref;
  row_cmd_e                  row_req_cmd;
  logic [ROW_ADDR_W-1:0]     row_req_addr;
  logic [BG_ADDR_W-1:0]      row_req_bg;
  logic [BANK_ADDR_W-1:0]    row_req_bank;

  // ---------------------------------------------------------------------------
  // Scheduled Column Command Outputs from Core
  // ---------------------------------------------------------------------------
  logic                      col_req_val;
  col_cmd_e                  col_req_cmd;
  logic [COL_ADDR_W-1:0]     col_req_addr;
  logic [BG_ADDR_W-1:0]      col_req_bg;
  logic [BANK_ADDR_W-1:0]    col_req_bank;
  logic [WDB_ADDR_W-1:0]     col_req_wdb_ptr;
  logic [AXI_ID_W-1:0]       col_req_axi_id;

  // ---------------------------------------------------------------------------
  // Observability Probes (Tapped from mc_pc_core internals for Self-Checking)
  // ---------------------------------------------------------------------------
  logic [TOTAL_BANKS-1:0]      dbg_bank_is_open;
  logic [ROW_ADDR_W-1:0]       dbg_open_row [TOTAL_BANKS-1:0];
  logic [7:0]                  dbg_cnt_rcd  [TOTAL_BANKS-1:0];
  logic [7:0]                  dbg_cnt_rrd;
  logic [TOTAL_BANKS-1:0]      dbg_legal_rd;
  logic [TOTAL_BANKS-1:0]      dbg_legal_act;
  logic [CMDQ_DEPTH-1:0]       dbg_slot_valid;
  logic [CMDQ_DEPTH-1:0]       dbg_slot_legal;
  cmd_entry_t                  dbg_slot_data [CMDQ_DEPTH-1:0];
  logic [CMDQ_ADDR_W-1:0]      dbg_grant_idx;
  logic [CREDIT_CTR_WIDTH-1:0] dbg_wait_ctr  [CMDQ_DEPTH-1:0];
  logic                        dbg_ref_req;

  // ---------------------------------------------------------------------------
  // Driver Clocking Block (drives push/grants, samples DUT responses)
  // ---------------------------------------------------------------------------
  clocking drv_cb @(posedge clk);
    default input #1step output #100ps;
    output cmd_push_val, cmd_push_entry, ch_arb_row_grant, ch_arb_col_grant;
    input  cmdq_full, err_cmdq_overflow;
    input  row_req_val, row_req_is_ref, row_req_cmd, row_req_addr, row_req_bg, row_req_bank;
    input  col_req_val, col_req_cmd, col_req_addr, col_req_bg, col_req_bank, col_req_axi_id;
    input  dbg_bank_is_open, dbg_cnt_rcd, dbg_cnt_rrd, dbg_legal_rd, dbg_legal_act;
    input  dbg_slot_valid, dbg_slot_legal, dbg_grant_idx;
  endclocking
  modport DRV (clocking drv_cb, input clk, input rst_n);

  // ---------------------------------------------------------------------------
  // Monitor Clocking Block (samples complete interface activity)
  // ---------------------------------------------------------------------------
  clocking mon_cb @(posedge clk);
    default input #1step output #100ps;
    input  cmd_push_val, cmd_push_entry, cmdq_full, err_cmdq_overflow;
    input  ch_arb_row_grant, ch_arb_col_grant;
    input  row_req_val, row_req_is_ref, row_req_cmd, row_req_addr, row_req_bg, row_req_bank;
    input  col_req_val, col_req_cmd, col_req_addr, col_req_bg, col_req_bank, col_req_axi_id;
    input  dbg_bank_is_open, dbg_cnt_rcd, dbg_cnt_rrd, dbg_legal_rd, dbg_legal_act;
    input  dbg_slot_valid, dbg_slot_legal, dbg_grant_idx;
  endclocking
  modport MON (clocking mon_cb, input clk, input rst_n);

endinterface : mc_if
