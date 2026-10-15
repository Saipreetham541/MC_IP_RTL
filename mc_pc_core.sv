`timescale 1ns/1ps

module mc_pc_core
  import mc_pkg::*;
#(
  parameter int DFI_PC_DATA_W = 32,
  parameter int DFI_PC_MASK_W = 4
) (
  input  logic                      clk,          // dfi_clk (1 GHz)
  input  logic                      rst_n,        // ctl_reset_n

  // 1. Decoded Command Push Interface (from Address Decoder)
  input  logic                      cmd_push_val,
  input  cmd_entry_t                cmd_push_entry,
  output logic                      cmdq_full,

  // 2. Write Data Buffer (WDB) Interface
  input  logic                      wdb_push_val,
  input  logic [DFI_PC_DATA_W-1:0]  wdb_push_data,
  input  logic [DFI_PC_MASK_W-1:0]  wdb_push_mask,
  output logic [WDB_ADDR_W-1:0]     wdb_alloc_ptr,
  output logic                      wdb_full,
  input  logic [WDB_ADDR_W-1:0]     wdb_raddr,
  output logic [DFI_PC_DATA_W-1:0]  wdb_rdata,
  output logic [DFI_PC_MASK_W-1:0]  wdb_rmask,
  input  logic                      wdb_pop_val,
  input  logic [WDB_ADDR_W-1:0]     wdb_pop_ptr,

  // 3. Read Data Buffer (RDB) Interface
  input  logic                      dfi_rddata_valid,
  input  logic [DFI_PC_DATA_W-1:0]  dfi_rddata,
  output logic                      rdb_valid,
  input  logic                      rdb_ready,
  output logic [DFI_PC_DATA_W-1:0]  rdb_data,
  output logic [AXI_ID_W-1:0]       rdb_axi_id,

  // 4. Candidate Command Outputs to Channel Arbiter (mc_ch_arb)
  output logic                      row_req_val,
  output logic                      row_req_is_ref, // High when row_req is a top-priority REF
  output row_cmd_e                  row_req_cmd,
  output logic [ROW_ADDR_W-1:0]     row_req_addr,
  output logic [BG_ADDR_W-1:0]      row_req_bg,
  output logic [BANK_ADDR_W-1:0]    row_req_bank,
  input  logic                      ch_arb_row_grant,

  output logic                      col_req_val,
  output col_cmd_e                  col_req_cmd,
  output logic [COL_ADDR_W-1:0]     col_req_addr,
  output logic [BG_ADDR_W-1:0]      col_req_bg,
  output logic [BANK_ADDR_W-1:0]    col_req_bank,
  output logic [WDB_ADDR_W-1:0]     col_req_wdb_ptr,
  output logic [AXI_ID_W-1:0]       col_req_axi_id,
  input  logic                      ch_arb_col_grant,

  // 5. Error / Interrupt Status Flags (Section 10)
  output logic                      err_cmdq_overflow,
  output logic                      err_wdb_overflow,
  output logic                      err_ref_deadline_miss
);

  // Internal Signals
  logic [CMDQ_DEPTH-1:0]  slot_valid;
  cmd_entry_t             slot_data [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0]  slot_legal;
  logic [CMDQ_DEPTH-1:0]  cmdq_grant;
  logic [CMDQ_ADDR_W-1:0] cmdq_grant_idx;
  logic                   cmdq_grant_valid;
  logic                   cmdq_arb_ack;

  logic [WDB_DEPTH-1:0]   wdb_data_rdy;
  logic                   rdb_full;

  logic [TOTAL_BANKS-1:0] bank_is_open;
  logic [ROW_ADDR_W-1:0]  open_row [TOTAL_BANKS-1:0];

  logic [TOTAL_BANKS-1:0] legal_act;
  logic [TOTAL_BANKS-1:0] legal_pre;
  logic [TOTAL_BANKS-1:0] legal_rd;
  logic [TOTAL_BANKS-1:0] legal_wr;
  logic                   legal_ref;

  logic                   ref_req;
  logic                   ref_ack;

  logic                   issue_act;
  logic                   issue_pre;
  logic                   issue_rd;
  logic                   issue_wr;
  logic [3:0]             active_bank_idx;

  // --------------------------------------------------------------------------
  // 1. Command Queue (32 entries)
  // --------------------------------------------------------------------------
  mc_cmdq u_cmdq (
    .clk           (clk),
    .rst_n         (rst_n),
    .push_val      (cmd_push_val),
    .push_entry    (cmd_push_entry),
    .cmdq_full     (cmdq_full),
    .cmdq_overflow (err_cmdq_overflow),
    .pop_val       (col_req_val && ch_arb_col_grant),
    .pop_idx       (cmdq_grant_idx),
    .slot_valid    (slot_valid),
    .slot_data     (slot_data)
  );

  // --------------------------------------------------------------------------
  // 2. Write Data Buffer (16 entries)
  // --------------------------------------------------------------------------
  mc_wdb #(
    .DFI_PC_DATA_W (DFI_PC_DATA_W),
    .DFI_PC_MASK_W (DFI_PC_MASK_W)
  ) u_wdb (
    .clk           (clk),
    .rst_n         (rst_n),
    .wdb_push_val  (wdb_push_val),
    .wdb_push_data (wdb_push_data),
    .wdb_push_mask (wdb_push_mask),
    .wdb_alloc_ptr (wdb_alloc_ptr),
    .wdb_full      (wdb_full),
    .wdb_overflow  (err_wdb_overflow),
    .wdb_data_rdy  (wdb_data_rdy),
    .wdb_raddr     (wdb_raddr),
    .wdb_rdata     (wdb_rdata),
    .wdb_rmask     (wdb_rmask),
    .wdb_pop_val   (wdb_pop_val),
    .wdb_pop_ptr   (wdb_pop_ptr)
  );

  // --------------------------------------------------------------------------
  // 3. Read Data Buffer (16 entries)
  // --------------------------------------------------------------------------
  mc_rdb #(
    .DFI_PC_DATA_W (DFI_PC_DATA_W)
  ) u_rdb (
    .clk              (clk),
    .rst_n            (rst_n),
    .rd_cmd_issue_val (issue_rd),
    .rd_cmd_issue_id  (col_req_axi_id),
    .rdb_full         (rdb_full),
    .dfi_rddata_valid (dfi_rddata_valid),
    .dfi_rddata       (dfi_rddata),
    .rdb_valid        (rdb_valid),
    .rdb_ready        (rdb_ready),
    .rdb_data         (rdb_data),
    .rdb_axi_id       (rdb_axi_id)
  );

  // --------------------------------------------------------------------------
  // 4. Refresh Engine (tREFI = 3900 cycles)
  // --------------------------------------------------------------------------
  mc_refresh_engine u_ref_eng (
    .clk               (clk),
    .rst_n             (rst_n),
    .ref_ack           (ref_ack),
    .ref_req           (ref_req),
    .ref_deadline_miss (err_ref_deadline_miss)
  );

  // --------------------------------------------------------------------------
  // 5. Bank State Table (16 banks per PC)
  // --------------------------------------------------------------------------
  mc_bank_state u_bank_state (
    .clk           (clk),
    .rst_n         (rst_n),
    .cmd_act_en    (issue_act),
    .cmd_pre_en    (issue_pre),
    .cmd_preall_en (ref_ack),        // All-bank refresh closes open banks
    .update_bg     (row_req_bg),
    .update_bank   (row_req_bank),
    .update_row    (row_req_addr),
    .bank_is_open  (bank_is_open),
    .open_row      (open_row)
  );

  // --------------------------------------------------------------------------
  // 6. DRAM Timing Legality Checker
  // --------------------------------------------------------------------------
  mc_timing_check u_timing_check (
    .clk           (clk),
    .rst_n         (rst_n),
    .issued_act    (issue_act),
    .issued_pre    (issue_pre),
    .issued_preall (1'b0),
    .issued_rd     (issue_rd),
    .issued_wr     (issue_wr),
    .issued_ref    (ref_ack),
    .issued_bank   (active_bank_idx),
    .legal_act     (legal_act),
    .legal_pre     (legal_pre),
    .legal_rd      (legal_rd),
    .legal_wr      (legal_wr),
    .legal_ref     (legal_ref)
  );

  // --------------------------------------------------------------------------
  // 7. Per-Slot Legality Evaluation
  // --------------------------------------------------------------------------
  always_comb begin
    for (int i = 0; i < CMDQ_DEPTH; i++) begin
      logic [3:0] b_idx;
      logic       data_buf_ok;

      b_idx       = {slot_data[i].bankgroup, slot_data[i].bank};
      data_buf_ok = slot_data[i].is_write ? wdb_data_rdy[slot_data[i].wdb_ptr] : !rdb_full;

      if (!slot_valid[i]) begin
        slot_legal[i] = 1'b0;
      end else if (bank_is_open[b_idx] && (open_row[b_idx] == slot_data[i].row)) begin
        // Page Hit: check column timing and WDB/RDB readiness
        slot_legal[i] = data_buf_ok && (slot_data[i].is_write ? legal_wr[b_idx] : legal_rd[b_idx]);
      end else if (!bank_is_open[b_idx]) begin
        // Bank Closed: check ACT timing
        slot_legal[i] = legal_act[b_idx];
      end else begin
        // Bank Conflict (wrong row open): check PRE timing
        slot_legal[i] = legal_pre[b_idx];
      end
    end
  end

  // --------------------------------------------------------------------------
  // 8. CMDQ Credit-Counter Arbiter (32 entries)
  // --------------------------------------------------------------------------
  // The CMDQ winner's counter only resets if it was not preempted by Refresh
  // and actually won the downstream channel bus
  assign cmdq_arb_ack = !(ref_req && legal_ref) &&
                        ((row_req_val && ch_arb_row_grant) || (col_req_val && ch_arb_col_grant));

  mc_arbiter #(
    .NUM_REQ (CMDQ_DEPTH)
  ) u_cmdq_arbiter (
    .clk         (clk),
    .rst_n       (rst_n),
    .req_valid   (slot_valid),
    .req_legal   (slot_legal),
    .grant_ack   (cmdq_arb_ack),
    .grant       (cmdq_grant),
    .grant_idx   (cmdq_grant_idx),
    .grant_valid (cmdq_grant_valid)
  );

  // --------------------------------------------------------------------------
  // 9. Command Dispatch Logic
  // --------------------------------------------------------------------------
  cmd_entry_t winner;
  wire [3:0]  winner_b_idx;

  assign winner       = slot_data[cmdq_grant_idx];
  assign winner_b_idx = {winner.bankgroup, winner.bank};

  always_comb begin
    row_req_val     = 1'b0;
    row_req_is_ref  = 1'b0;
    row_req_cmd     = ROW_CMD_NOP;
    row_req_addr    = '0;
    row_req_bg      = '0;
    row_req_bank    = '0;

    col_req_val     = 1'b0;
    col_req_cmd     = COL_CMD_NOP;
    col_req_addr    = '0;
    col_req_bg      = '0;
    col_req_bank    = '0;
    col_req_wdb_ptr = '0;
    col_req_axi_id  = '0;

    ref_ack         = 1'b0;

    // Refresh has automatic top priority (Section 5.5)
    if (ref_req && legal_ref) begin
      row_req_val    = 1'b1;
      row_req_is_ref = 1'b1;
      row_req_cmd    = ROW_CMD_REF;
      if (ch_arb_row_grant) begin
        ref_ack = 1'b1;
      end
    end else if (cmdq_grant_valid) begin
      if (bank_is_open[winner_b_idx] && (open_row[winner_b_idx] == winner.row)) begin
        // Page Hit -> Issue Column RD or WR
        col_req_val     = 1'b1;
        col_req_cmd     = winner.is_write ? COL_CMD_WR : COL_CMD_RD;
        col_req_addr    = winner.col;
        col_req_bg      = winner.bankgroup;
        col_req_bank    = winner.bank;
        col_req_wdb_ptr = winner.wdb_ptr;
        col_req_axi_id  = winner.axi_id;
      end else if (!bank_is_open[winner_b_idx]) begin
        // Bank Closed -> Issue Row ACT
        row_req_val     = 1'b1;
        row_req_cmd     = ROW_CMD_ACT;
        row_req_addr    = winner.row;
        row_req_bg      = winner.bankgroup;
        row_req_bank    = winner.bank;
      end else begin
        // Page Conflict -> Issue Row PRE
        row_req_val     = 1'b1;
        row_req_cmd     = ROW_CMD_PRE;
        row_req_bg      = winner.bankgroup;
        row_req_bank    = winner.bank;
      end
    end
  end

  // Trigger pulses for Bank State & Timing Counters when granted by Channel Arbiter
  assign issue_act       = row_req_val && (row_req_cmd == ROW_CMD_ACT) && ch_arb_row_grant;
  assign issue_pre       = row_req_val && (row_req_cmd == ROW_CMD_PRE) && ch_arb_row_grant;
  assign issue_rd        = col_req_val && (col_req_cmd == COL_CMD_RD)  && ch_arb_col_grant;
  assign issue_wr        = col_req_val && (col_req_cmd == COL_CMD_WR)  && ch_arb_col_grant;
  assign active_bank_idx = row_req_val ? {row_req_bg, row_req_bank} : {col_req_bg, col_req_bank};

endmodule : mc_pc_core