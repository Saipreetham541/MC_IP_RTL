`timescale 1ns/1ps
module mc_pc_core
  import mc_pkg::*;
(
  input  logic                      clk,          // dfi_clk (1 GHz)
  input  logic                      rst_n,        // ctl_reset_n

  // Decoded push interface from CDC/Address Router (2 PCs)
  input  logic [1:0]                cmd_push_val,
  input  cmd_entry_t                cmd_push_entry [2],
  output logic [1:0]                cmdq_full,

  // Upstream feedback from Channel Arbiter (per PC)
  input  logic [1:0]                ch_arb_row_grant,
  input  logic [1:0]                ch_arb_col_grant,

  // Candidate command outputs to Channel Arbiter (per PC)
  output logic [1:0]                row_req_val,
  output row_cmd_e                  row_req_cmd [2],
  output logic [ROW_ADDR_W-1:0]     row_req_addr [2],
  output logic [BG_ADDR_W-1:0]      row_req_bg [2],
  output logic [BANK_ADDR_W-1:0]    row_req_bank [2],

  output logic [1:0]                col_req_val,
  output col_cmd_e                  col_req_cmd [2],
  output logic [COL_ADDR_W-1:0]     col_req_addr [2],
  output logic [BG_ADDR_W-1:0]      col_req_bg [2],
  output logic [BANK_ADDR_W-1:0]    col_req_bank [2],
  output logic [WDB_ADDR_W-1:0]     col_req_wdb_ptr [2],
  output logic [AXI_ID_W-1:0]       col_req_axi_id [2]
);

  // --------------------------------------------------------------------------
  // Internal Wires (per PC)
  // --------------------------------------------------------------------------
  logic [CMDQ_DEPTH-1:0]     slot_valid [2];
  cmd_entry_t                slot_data_0 [CMDQ_DEPTH-1:0];
  cmd_entry_t                slot_data_1 [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0]     slot_legal [2];
  logic [CMDQ_DEPTH-1:0]     cmdq_grant [2];
  logic [CMDQ_ADDR_W-1:0]    cmdq_grant_idx [2];
  logic                      cmdq_grant_valid [2];

  logic [TOTAL_BANKS-1:0]    bank_is_open;
  logic [ROW_ADDR_W-1:0]     open_row [TOTAL_BANKS-1:0];

  logic [TOTAL_BANKS-1:0]    legal_act;
  logic [TOTAL_BANKS-1:0]    legal_pre;
  logic [TOTAL_BANKS-1:0]    legal_rd;
  logic [TOTAL_BANKS-1:0]    legal_wr;
  logic                      legal_ref;

  logic                      ref_req;
  logic                      ref_ack;

  // Track command actions (per PC)
  logic [1:0]                issue_act;
  logic [1:0]                issue_pre;
  logic [1:0]                issue_rd;
  logic [1:0]                issue_wr;
  logic [3:0]                active_bank_idx [2];

  // --------------------------------------------------------------------------
  // Submodule Instances (per PC)
  // --------------------------------------------------------------------------
  mc_cmdq u_cmdq_0 (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_val   (cmd_push_val[0]),
    .push_entry (cmd_push_entry[0]),
    .cmdq_full  (cmdq_full[0]),
    .pop_val    (col_req_val[0] && ch_arb_col_grant[0]),
    .pop_idx    (cmdq_grant_idx[0]),
    .slot_valid (slot_valid[0]),
    .slot_data  (slot_data_0)
  );

  mc_cmdq u_cmdq_1 (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_val   (cmd_push_val[1]),
    .push_entry (cmd_push_entry[1]),
    .cmdq_full  (cmdq_full[1]),
    .pop_val    (col_req_val[1] && ch_arb_col_grant[1]),
    .pop_idx    (cmdq_grant_idx[1]),
    .slot_valid (slot_valid[1]),
    .slot_data  (slot_data_1)
  );

  mc_refresh_engine u_ref_eng (
    .clk     (clk),
    .rst_n   (rst_n),
    .ref_ack (ref_ack),
    .ref_req (ref_req)
  );

  mc_bank_state u_bank_state (
    .clk           (clk),
    .rst_n         (rst_n),
    .cmd_act_en    (|issue_act),
    .cmd_pre_en    (|issue_pre),
    .cmd_preall_en (1'b0),
    .update_bg     (row_req_bg[0]),  // Bank state shared across PCs
    .update_bank   (row_req_bank[0]),
    .update_row    (row_req_addr[0]),
    .bank_is_open  (bank_is_open),
    .open_row      (open_row)
  );

  mc_timing_check u_timing_check (
    .clk           (clk),
    .rst_n         (rst_n),
    .issued_act    (|issue_act),
    .issued_pre    (|issue_pre),
    .issued_preall (1'b0),
    .issued_rd     (|issue_rd),
    .issued_wr     (|issue_wr),
    .issued_ref    (ref_ack),
    .issued_bank   (active_bank_idx[0]),  // Timing checks shared
    .legal_act     (legal_act),
    .legal_pre     (legal_pre),
    .legal_rd      (legal_rd),
    .legal_wr      (legal_wr),
    .legal_ref     (legal_ref)
  );

  // --------------------------------------------------------------------------
  // Command Slot Legality Generation (per PC)
  // --------------------------------------------------------------------------
  always_comb begin
    // PC0
    for (int i = 0; i < CMDQ_DEPTH; i++) begin
      logic [3:0] b_idx;
      b_idx = {slot_data_0[i].bankgroup, slot_data_0[i].bank};

      if (!slot_valid[0][i]) begin
        slot_legal[0][i] = 1'b0;
      end else if (bank_is_open[b_idx] && (open_row[b_idx] == slot_data_0[i].row)) begin
        slot_legal[0][i] = slot_data_0[i].is_write ? legal_wr[b_idx] : legal_rd[b_idx];
      end else if (!bank_is_open[b_idx]) begin
        slot_legal[0][i] = legal_act[b_idx];
      end else begin
        slot_legal[0][i] = legal_pre[b_idx];
      end
    end

    // PC1
    for (int i = 0; i < CMDQ_DEPTH; i++) begin
      logic [3:0] b_idx;
      b_idx = {slot_data_1[i].bankgroup, slot_data_1[i].bank};

      if (!slot_valid[1][i]) begin
        slot_legal[1][i] = 1'b0;
      end else if (bank_is_open[b_idx] && (open_row[b_idx] == slot_data_1[i].row)) begin
        slot_legal[1][i] = slot_data_1[i].is_write ? legal_wr[b_idx] : legal_rd[b_idx];
      end else if (!bank_is_open[b_idx]) begin
        slot_legal[1][i] = legal_act[b_idx];
      end else begin
        slot_legal[1][i] = legal_pre[b_idx];
      end
    end
  end

  // --------------------------------------------------------------------------
  // CMDQ Credit-Counter Arbiter (per PC)
  // --------------------------------------------------------------------------
  genvar pc;
  generate
    for (pc = 0; pc < 2; pc++) begin : gen_cmdq_arbiter
      mc_arbiter #(
        .NUM_REQ (CMDQ_DEPTH)
      ) u_cmdq_arbiter (
        .clk         (clk),
        .rst_n       (rst_n),
        .req_valid   (slot_valid[pc]),
        .req_legal   (slot_legal[pc]),
        .grant       (cmdq_grant[pc]),
        .grant_idx   (cmdq_grant_idx[pc]),
        .grant_valid (cmdq_grant_valid[pc])
      );
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Candidate Dispatch to Channel Arbiter (per PC)
  // --------------------------------------------------------------------------
  cmd_entry_t winner_0;
  cmd_entry_t winner_1;
  wire [3:0] winner_b_idx_0;
  wire [3:0] winner_b_idx_1;
  assign winner_0 = slot_data_0[cmdq_grant_idx[0]];
  assign winner_1 = slot_data_1[cmdq_grant_idx[1]];
  assign winner_b_idx_0 = {winner_0.bankgroup, winner_0.bank};
  assign winner_b_idx_1 = {winner_1.bankgroup, winner_1.bank};

  // PC0 dispatch
  always_comb begin
    // Default outputs
    row_req_val[0]     = 1'b0;
    row_req_cmd[0]     = ROW_CMD_NOP;
    row_req_addr[0]    = '0;
    row_req_bg[0]      = '0;
    row_req_bank[0]    = '0;
    col_req_val[0]     = 1'b0;
    col_req_cmd[0]     = COL_CMD_NOP;
    col_req_addr[0]    = '0;
    col_req_bg[0]      = '0;
    col_req_bank[0]    = '0;
    col_req_wdb_ptr[0] = '0;
    col_req_axi_id[0]  = '0;
    ref_ack            = 1'b0;

    // Refresh Priority: Unconditionally overrides normal traffic (Section 5.5)
    // Only PC0 handles refresh (shared resource)
    if (ref_req && legal_ref) begin
      row_req_val[0] = 1'b1;
      row_req_cmd[0] = ROW_CMD_REF;
      if (ch_arb_row_grant[0]) begin
        ref_ack = 1'b1;
      end
    end else if (cmdq_grant_valid[0]) begin
      if (bank_is_open[winner_b_idx_0] && (open_row[winner_b_idx_0] == winner_0.row)) begin
        // Issue RD / WR column command
        col_req_val[0]     = 1'b1;
        col_req_cmd[0]     = winner_0.is_write ? COL_CMD_WR : COL_CMD_RD;
        col_req_addr[0]    = winner_0.col;
        col_req_bg[0]      = winner_0.bankgroup;
        col_req_bank[0]    = winner_0.bank;
        col_req_wdb_ptr[0] = winner_0.wdb_ptr;
        col_req_axi_id[0]  = winner_0.axi_id;
      end else if (!bank_is_open[winner_b_idx_0]) begin
        // Issue ACT row command
        row_req_val[0]  = 1'b1;
        row_req_cmd[0]  = ROW_CMD_ACT;
        row_req_addr[0] = winner_0.row;
        row_req_bg[0]   = winner_0.bankgroup;
        row_req_bank[0] = winner_0.bank;
      end else begin
        // Issue PRE row command
        row_req_val[0]  = 1'b1;
        row_req_cmd[0]  = ROW_CMD_PRE;
        row_req_bg[0]   = winner_0.bankgroup;
        row_req_bank[0] = winner_0.bank;
      end
    end
  end

  // PC1 dispatch
  always_comb begin
    // Default outputs
    row_req_val[1]     = 1'b0;
    row_req_cmd[1]     = ROW_CMD_NOP;
    row_req_addr[1]    = '0;
    row_req_bg[1]      = '0;
    row_req_bank[1]    = '0;
    col_req_val[1]     = 1'b0;
    col_req_cmd[1]     = COL_CMD_NOP;
    col_req_addr[1]    = '0;
    col_req_bg[1]      = '0;
    col_req_bank[1]    = '0;
    col_req_wdb_ptr[1] = '0;
    col_req_axi_id[1]  = '0;

    if (cmdq_grant_valid[1]) begin
      if (bank_is_open[winner_b_idx_1] && (open_row[winner_b_idx_1] == winner_1.row)) begin
        // Issue RD / WR column command
        col_req_val[1]     = 1'b1;
        col_req_cmd[1]     = winner_1.is_write ? COL_CMD_WR : COL_CMD_RD;
        col_req_addr[1]    = winner_1.col;
        col_req_bg[1]      = winner_1.bankgroup;
        col_req_bank[1]    = winner_1.bank;
        col_req_wdb_ptr[1] = winner_1.wdb_ptr;
        col_req_axi_id[1]  = winner_1.axi_id;
      end else if (!bank_is_open[winner_b_idx_1]) begin
        // Issue ACT row command
        row_req_val[1]  = 1'b1;
        row_req_cmd[1]  = ROW_CMD_ACT;
        row_req_addr[1] = winner_1.row;
        row_req_bg[1]   = winner_1.bankgroup;
        row_req_bank[1] = winner_1.bank;
      end else begin
        // Issue PRE row command
        row_req_val[1]  = 1'b1;
        row_req_cmd[1]  = ROW_CMD_PRE;
        row_req_bg[1]   = winner_1.bankgroup;
        row_req_bank[1] = winner_1.bank;
      end
    end
  end

  // Tracking issued operations for timing countdown triggers
  assign issue_act[0]       = row_req_val[0] && (row_req_cmd[0] == ROW_CMD_ACT) && ch_arb_row_grant[0];
  assign issue_pre[0]       = row_req_val[0] && (row_req_cmd[0] == ROW_CMD_PRE) && ch_arb_row_grant[0];
  assign issue_rd[0]        = col_req_val[0] && (col_req_cmd[0] == COL_CMD_RD)  && ch_arb_col_grant[0];
  assign issue_wr[0]        = col_req_val[0] && (col_req_cmd[0] == COL_CMD_WR)  && ch_arb_col_grant[0];
  assign active_bank_idx[0] = row_req_val[0] ? {row_req_bg[0], row_req_bank[0]} : {col_req_bg[0], col_req_bank[0]};

  assign issue_act[1]       = row_req_val[1] && (row_req_cmd[1] == ROW_CMD_ACT) && ch_arb_row_grant[1];
  assign issue_pre[1]       = row_req_val[1] && (row_req_cmd[1] == ROW_CMD_PRE) && ch_arb_row_grant[1];
  assign issue_rd[1]        = col_req_val[1] && (col_req_cmd[1] == COL_CMD_RD)  && ch_arb_col_grant[1];
  assign issue_wr[1]        = col_req_val[1] && (col_req_cmd[1] == COL_CMD_WR)  && ch_arb_col_grant[1];
  assign active_bank_idx[1] = row_req_val[1] ? {row_req_bg[1], row_req_bank[1]} : {col_req_bg[1], col_req_bank[1]};

endmodule
