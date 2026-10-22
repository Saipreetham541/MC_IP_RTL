`timescale 1ns/1ps

module mc_pc_core
  import mc_pkg::*;
#(
  parameter int DFI_PC_DATA_W = 32,
  parameter int DFI_PC_MASK_W = 4
) (
  input  logic                      clk,          // DFI-domain clock; all core state advances here.
  input  logic                      rst_n,        // Synchronous active-low controller reset.

  // Decoded transaction input. cmdq_full is backpressure: the decoder must
  // retain the command until a queue slot is available.
  input  logic                      cmd_push_val,   // One-cycle request to store cmd_push_entry.
  input  cmd_entry_t                cmd_push_entry, // Address, type, ID, and optional WDB pointer.
  output logic                      cmdq_full,      // High when no command slot can be allocated.

  // Write payload storage is separate from CMDQ because command scheduling can
  // be delayed or reordered. The command carries wdb_alloc_ptr to find its data.
  input  logic                      wdb_push_val,  // Stores one data/mask payload.
  input  logic [DFI_PC_DATA_W-1:0]  wdb_push_data,
  input  logic [DFI_PC_MASK_W-1:0]  wdb_push_mask,
  output logic [WDB_ADDR_W-1:0]     wdb_alloc_ptr, // Pointer copied into the write command.
  output logic                      wdb_full,      // Backpressure when all payload slots are used.
  input  logic [WDB_ADDR_W-1:0]     wdb_raddr,    // Formatter-selected payload pointer.
  output logic [DFI_PC_DATA_W-1:0]  wdb_rdata,
  output logic [DFI_PC_MASK_W-1:0]  wdb_rmask,
  input  logic                      wdb_pop_val,   // Releases payload after DFI transmission.
  input  logic [WDB_ADDR_W-1:0]     wdb_pop_ptr,

  // Returning PHY data has no AXI ID, so RDB pairs it with IDs recorded when
  // reads issue and presents a standard valid/ready completion interface.
  input  logic                      dfi_rddata_valid,
  input  logic [DFI_PC_DATA_W-1:0]  dfi_rddata,
  output logic                      rdb_valid,     // Completion data and ID are available.
  input  logic                      rdb_ready,     // Consumer accepts the current completion.
  output logic [DFI_PC_DATA_W-1:0]  rdb_data,
  output logic [AXI_ID_W-1:0]       rdb_axi_id,

  // Candidate commands must receive the matching channel grant before they are
  // considered issued. This prevents state/timing updates for a rejected request.
  output logic                      row_req_val,    // A row command is ready for arbitration.
  output logic                      row_req_is_ref, // Prioritize refresh PRE/REF service.
  output row_cmd_e                  row_req_cmd,
  output logic [ROW_ADDR_W-1:0]     row_req_addr,
  output logic [BG_ADDR_W-1:0]      row_req_bg,
  output logic [BANK_ADDR_W-1:0]    row_req_bank,
  input  logic                      ch_arb_row_grant, // Channel accepted this row request.

  output logic                      col_req_val,      // A column command is ready for arbitration.
  output col_cmd_e                  col_req_cmd,
  output logic [COL_ADDR_W-1:0]     col_req_addr,
  output logic [BG_ADDR_W-1:0]      col_req_bg,
  output logic [BANK_ADDR_W-1:0]    col_req_bank,
  output logic [WDB_ADDR_W-1:0]     col_req_wdb_ptr,  // Selects payload for WR.
  output logic [AXI_ID_W-1:0]       col_req_axi_id,   // Records completion identity for RD.
  input  logic                      ch_arb_col_grant, // Channel accepted this column request.

  // 5. Error / Interrupt Status Flags (Section 10)
  output logic                      err_cmdq_overflow,
  output logic                      err_wdb_overflow,
  output logic                      err_ref_deadline_miss
);

  // Queue visibility and arbitration results. slot_legal is recomputed from
  // current bank/timing/buffer state every cycle.
  logic [CMDQ_DEPTH-1:0]  slot_valid;
  cmd_entry_t             slot_data [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0]  slot_legal;
  logic [CMDQ_DEPTH-1:0]  cmdq_grant;
  logic [CMDQ_ADDR_W-1:0] cmdq_grant_idx;
  logic                   cmdq_grant_valid;
  logic                   cmdq_arb_ack;

  logic [WDB_DEPTH-1:0]   wdb_data_rdy; // Prevents WR before its payload arrives.
  logic                   rdb_full;      // Prevents RD when no completion capacity remains.

  logic [TOTAL_BANKS-1:0] bank_is_open;
  logic [ROW_ADDR_W-1:0]  open_row [TOTAL_BANKS-1:0];

  logic [TOTAL_BANKS-1:0] legal_act;
  logic [TOTAL_BANKS-1:0] legal_pre;
  logic [TOTAL_BANKS-1:0] legal_rd;
  logic [TOTAL_BANKS-1:0] legal_wr;
  logic                   legal_ref;

  logic                   ref_req; // Held until all banks are prepared and REF is granted.
  logic                   ref_ack; // Clears ref_req and starts the tRFC busy interval.

  // These pulses represent commands actually accepted by the channel; only
  // accepted commands are allowed to change bank or timing state.
  logic                   issue_act;
  logic                   issue_pre;
  logic                   issue_rd;
  logic                   issue_wr;
  logic [BANK_IDX_W-1:0]  active_bank_idx;

  logic                   refresh_pre_valid;
  logic [BANK_IDX_W-1:0]  refresh_pre_bank_idx;
  logic                   any_bank_open;

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
      logic [BANK_IDX_W-1:0] b_idx;
      logic       data_buf_ok;

      b_idx       = {slot_data[i].bankgroup, slot_data[i].bank};
      // Page-hit commands consume a data buffer immediately. ACT/PRE may proceed
      // earlier because they do not yet consume write data or read-return space.
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
  // Reset the selected slot's age only when its candidate really issued.
  // A refresh-preempted command keeps its accumulated priority.
  assign cmdq_arb_ack = (|cmdq_grant) && !ref_req &&
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
  wire [BANK_IDX_W-1:0] winner_b_idx;

  assign winner       = slot_data[cmdq_grant_idx];
  assign winner_b_idx = {winner.bankgroup, winner.bank};

  // During a pending refresh, find the lowest-numbered open bank that is safe to
  // precharge. One bank is closed per granted PRE; REF waits until every bank is
  // closed and the timing checker reports all tRP counters expired.
  always_comb begin
    refresh_pre_valid    = 1'b0;
    refresh_pre_bank_idx = '0;
    any_bank_open        = 1'b0;

    for (int i = 0; i < TOTAL_BANKS; i++) begin
      if (bank_is_open[i]) begin
        any_bank_open = 1'b1;
        if (legal_pre[i] && !refresh_pre_valid) begin
          refresh_pre_valid    = 1'b1;
          refresh_pre_bank_idx = BANK_IDX_W'(i);
        end
      end
    end
  end

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

    // Refresh preparation and REF have automatic top priority (Section 5.5).
    if (ref_req) begin
      if (any_bank_open) begin
        if (refresh_pre_valid) begin
          row_req_val     = 1'b1;
          row_req_is_ref  = 1'b1;
          row_req_cmd     = ROW_CMD_PRE;
          row_req_bg      = refresh_pre_bank_idx[BANK_IDX_W-1 -: BG_ADDR_W];
          row_req_bank    = refresh_pre_bank_idx[BANK_ADDR_W-1:0];
        end
      end else if (legal_ref) begin
        row_req_val    = 1'b1;
        row_req_is_ref = 1'b1;
        row_req_cmd    = ROW_CMD_REF;
        if (ch_arb_row_grant) begin
          ref_ack = 1'b1;
        end
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

  // Convert granted candidate commands into single-cycle state-update pulses.
  // active_bank_idx selects the per-bank counters updated by that command.
  assign issue_act       = row_req_val && (row_req_cmd == ROW_CMD_ACT) && ch_arb_row_grant;
  assign issue_pre       = row_req_val && (row_req_cmd == ROW_CMD_PRE) && ch_arb_row_grant;
  assign issue_rd        = col_req_val && (col_req_cmd == COL_CMD_RD)  && ch_arb_col_grant;
  assign issue_wr        = col_req_val && (col_req_cmd == COL_CMD_WR)  && ch_arb_col_grant;
  assign active_bank_idx = row_req_val ? {row_req_bg, row_req_bank} : {col_req_bg, col_req_bank};

endmodule : mc_pc_core
