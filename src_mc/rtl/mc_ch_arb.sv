`default_nettype none

`timescale 1ns/1ps

// Arbitration between the two pseudo-channels sharing one channel's row and
// column command buses. Row and column arbitration are independent, so both
// outputs may be valid in the same cycle.
module mc_ch_arb #(
  parameter int NUM_PC           = 2,
  parameter int ROW_CMD_WIDTH    = 22,
  parameter int COL_CMD_WIDTH    = 12,
  parameter int CREDIT_CTR_WIDTH = 8
) (
  input  wire logic                              clk,
  input  wire logic                              rst_n,

  input  wire logic [NUM_PC-1:0]                 row_req_valid,
  input  wire logic [NUM_PC-1:0]                 row_req_legal,
  input  wire logic [NUM_PC-1:0]                 row_req_refresh,
  input  wire logic [NUM_PC-1:0]                 row_grant_ack,
  input  wire logic [NUM_PC-1:0][ROW_CMD_WIDTH-1:0] row_cmd,
  output logic [NUM_PC-1:0]                 row_grant,
  output logic                              row_valid,
  output logic                              row_pc_sel,
  output logic [ROW_CMD_WIDTH-1:0]          row_cmd_out,

  input  wire logic [NUM_PC-1:0]                 col_req_valid,
  input wire logic [NUM_PC-1:0]                 col_req_legal,
  input wire logic [NUM_PC-1:0]                 col_req_refresh,
  input wire logic [NUM_PC-1:0]                 col_grant_ack,
  input wire logic [NUM_PC-1:0][COL_CMD_WIDTH-1:0] col_cmd,
  output logic [NUM_PC-1:0]                 col_grant,
  output logic                              col_valid,
  output logic                              col_pc_sel,
  output logic [COL_CMD_WIDTH-1:0]          col_cmd_out
);

  logic [$clog2(NUM_PC)-1:0] row_grant_idx;
  logic [$clog2(NUM_PC)-1:0] col_grant_idx;
  logic row_grant_ack_reduced;
  logic col_grant_ack_reduced;
  assign row_grant_ack_reduced = |(row_grant & row_grant_ack);
  assign col_grant_ack_reduced = |(col_grant & col_grant_ack);
  mc_arbiter #(
    .NUM_REQ          (NUM_PC),
    .CREDIT_CTR_WIDTH (CREDIT_CTR_WIDTH)
  ) u_row_arbiter (
    .clk          (clk),
    .rst_n        (rst_n),
    .req_valid    (row_req_valid),
    .req_legal    (row_req_legal),
    .req_priority (row_req_refresh),
    .grant_ack    (row_grant_ack_reduced),
    .grant        (row_grant),
    .grant_idx    (row_grant_idx),
    .grant_valid  (row_valid)
  );

  mc_arbiter #(
    .NUM_REQ          (NUM_PC),
    .CREDIT_CTR_WIDTH (CREDIT_CTR_WIDTH)
  ) u_col_arbiter (
    .clk          (clk),
    .rst_n        (rst_n),
    .req_valid    (col_req_valid),
    .req_legal    (col_req_legal),
    .req_priority (col_req_refresh),
    .grant_ack    (col_grant_ack_reduced),
    .grant        (col_grant),
    .grant_idx    (col_grant_idx),
    .grant_valid  (col_valid)
  );

  always_comb begin
    row_pc_sel = 1'b0;
    row_cmd_out = '0;
    if (row_valid) begin
      row_pc_sel = row_grant_idx[0];
      row_cmd_out = row_cmd[row_grant_idx];
      row_cmd_out[ROW_CMD_WIDTH-1] = row_pc_sel;
    end

    col_pc_sel = 1'b0;
    col_cmd_out = '0;
    if (col_valid) begin
      col_pc_sel = col_grant_idx[0];
      col_cmd_out = col_cmd[col_grant_idx];
      col_cmd_out[COL_CMD_WIDTH-1] = col_pc_sel;
    end
  end

endmodule : mc_ch_arb

`default_nettype wire
