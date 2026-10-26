`default_nettype none

`timescale 1ns/1ps

// Phase 4 integration for one channel:
//   PC0/PC1 command candidates -> shared row/column arbitration
//   -> one-cycle DFI formatter boundary stage.
//
// Row and column buses are arbitrated independently. The two PC data lanes
// remain independent and may be active concurrently.
module mc_channel_integration #(
  parameter int NUM_PC           = 2,
  parameter int CREDIT_CTR_WIDTH = 8
) (
  input  logic                             dfi_clk,
  input  logic                             dfi_reset_n,

  input  logic [NUM_PC-1:0]                row_req_valid,
  input  logic [NUM_PC-1:0]                row_req_legal,
  input  logic [NUM_PC-1:0]                row_req_refresh,
  input  logic [NUM_PC-1:0][2:0]           row_cmd,
  input  logic [NUM_PC-1:0][1:0]           row_bg,
  input  logic [NUM_PC-1:0][1:0]           row_ba,
  input  logic [NUM_PC-1:0][13:0]          row_addr,
  output logic [NUM_PC-1:0]                row_issue,

  input  logic [NUM_PC-1:0]                col_req_valid,
  input  logic [NUM_PC-1:0]                col_req_legal,
  input  logic [NUM_PC-1:0]                col_req_refresh,
  input  logic [NUM_PC-1:0][1:0]           col_cmd,
  input  logic [NUM_PC-1:0][1:0]           col_bg,
  input  logic [NUM_PC-1:0][1:0]           col_ba,
  input  logic [NUM_PC-1:0][4:0]           col_addr,
  output logic [NUM_PC-1:0]                col_issue,

  input  logic [NUM_PC-1:0][31:0]          wrdata_pc,
  input  logic [NUM_PC-1:0][3:0]           wrdata_mask_pc,
  input  logic [NUM_PC-1:0]                wrdata_en_pc,
  output logic [63:0]                      dfi_wrdata,
  output logic [7:0]                       dfi_wrdata_mask,
  output logic [1:0]                       dfi_wrdata_en,

  input  logic [63:0]                      dfi_rddata,
  input  logic [1:0]                       dfi_rddata_valid,
  input  logic [1:0]                       rddata_en_pc,
  output logic [1:0]                       dfi_rddata_en,
  output logic [31:0]                      rddata_pc0,
  output logic [31:0]                      rddata_pc1,
  output logic [1:0]                       rddata_valid,

  output logic                             dfi_row_val,
  output logic [21:0]                      dfi_row,
  output logic                             dfi_col_val,
  output logic [11:0]                      dfi_col
);

  logic [NUM_PC-1:0][21:0] row_cmd_packed;
  logic [NUM_PC-1:0][11:0] col_cmd_packed;

  logic [NUM_PC-1:0] row_grant;
  logic [NUM_PC-1:0] col_grant;
  logic              row_valid;
  logic              col_valid;
  logic              row_pc_sel;
  logic              col_pc_sel;
  logic [21:0]       row_cmd_selected;
  logic [11:0]       col_cmd_selected;

  logic [2:0]        fmt_row_cmd;
  logic [1:0]        fmt_row_bg;
  logic [1:0]        fmt_row_ba;
  logic [13:0]       fmt_row_addr;
  logic [1:0]        fmt_col_cmd;
  logic [1:0]        fmt_col_bg;
  logic [1:0]        fmt_col_ba;
  logic [4:0]        fmt_col_addr;

  always_comb begin
    for (int pc = 0; pc < NUM_PC; pc++) begin
      row_cmd_packed[pc] = {
        1'b0, row_cmd[pc], row_bg[pc], row_ba[pc], row_addr[pc]
      };
      col_cmd_packed[pc] = {
        1'b0, col_cmd[pc], col_bg[pc], col_ba[pc], col_addr[pc]
      };
    end
  end

  // The formatter captures one selected row and one selected column command
  // on every clock. Therefore a valid arbitration result is accepted in the
  // current cycle and the corresponding wait counter is reset.
  mc_ch_arb #(
    .NUM_PC           (NUM_PC),
    .ROW_CMD_WIDTH    (22),
    .COL_CMD_WIDTH    (12),
    .CREDIT_CTR_WIDTH (CREDIT_CTR_WIDTH)
  ) u_channel_arbiter (
    .clk             (dfi_clk),
    .rst_n           (dfi_reset_n),
    .row_req_valid   (row_req_valid),
    .row_req_legal   (row_req_legal),
    .row_req_refresh (row_req_refresh),
    .row_grant_ack   ({NUM_PC{1'b1}}),
    .row_cmd         (row_cmd_packed),
    .row_grant       (row_grant),
    .row_valid       (row_valid),
    .row_pc_sel      (row_pc_sel),
    .row_cmd_out     (row_cmd_selected),
    .col_req_valid   (col_req_valid),
    .col_req_legal   (col_req_legal),
    .col_req_refresh (col_req_refresh),
    .col_grant_ack   ({NUM_PC{1'b1}}),
    .col_cmd         (col_cmd_packed),
    .col_grant       (col_grant),
    .col_valid       (col_valid),
    .col_pc_sel      (col_pc_sel),
    .col_cmd_out     (col_cmd_selected)
  );

  assign row_issue = row_grant;
  assign col_issue = col_grant;

  assign fmt_row_cmd  = row_cmd_selected[20:18];
  assign fmt_row_bg   = row_cmd_selected[17:16];
  assign fmt_row_ba   = row_cmd_selected[15:14];
  assign fmt_row_addr = row_cmd_selected[13:0];

  assign fmt_col_cmd  = col_cmd_selected[10:9];
  assign fmt_col_bg   = col_cmd_selected[8:7];
  assign fmt_col_ba   = col_cmd_selected[6:5];
  assign fmt_col_addr = col_cmd_selected[4:0];

  mc_dfi_fmt u_dfi_formatter (
    .dfi_clk          (dfi_clk),
    .dfi_reset_n      (dfi_reset_n),
    .row_valid        (row_valid),
    .row_pc_sel       (row_pc_sel),
    .row_cmd          (fmt_row_cmd),
    .row_bg           (fmt_row_bg),
    .row_ba           (fmt_row_ba),
    .row_addr         (fmt_row_addr),
    .dfi_row_val      (dfi_row_val),
    .dfi_row          (dfi_row),
    .col_valid        (col_valid),
    .col_pc_sel       (col_pc_sel),
    .col_cmd          (fmt_col_cmd),
    .col_bg           (fmt_col_bg),
    .col_ba           (fmt_col_ba),
    .col_addr         (fmt_col_addr),
    .dfi_col_val      (dfi_col_val),
    .dfi_col          (dfi_col),
    .wrdata           ({wrdata_pc[1], wrdata_pc[0]}),
    .wrdata_mask      ({wrdata_mask_pc[1], wrdata_mask_pc[0]}),
    .wrdata_en        (wrdata_en_pc),
    .dfi_wrdata       (dfi_wrdata),
    .dfi_wrdata_mask  (dfi_wrdata_mask),
    .dfi_wrdata_en    (dfi_wrdata_en),
    .dfi_rddata       (dfi_rddata),
    .dfi_rddata_valid (dfi_rddata_valid),
    .rddata_en        (rddata_en_pc),
    .dfi_rddata_en    (dfi_rddata_en),
    .rddata_pc0       (rddata_pc0),
    .rddata_pc1       (rddata_pc1),
    .rddata_valid     (rddata_valid)
  );

endmodule : mc_channel_integration

`default_nettype wire
