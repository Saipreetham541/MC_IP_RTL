`default_nettype none
`timescale 1ns/1ps

// Current-RTL integration: 16 channels, two independent PC cores/channel.
// Entry = {id[7:0], write, row[13:0], bg[1:0], bank[1:0], col[4:0], ptr[3:0]}.
// PC index = 2*channel + pc. A push is accepted on a rising edge when !full;
// sample the WDB allocation pointer BEFORE the payload push edge.
// Read completions follow RD issue order, independently per PC.
//
// Baseline data contract: the formatter captures a command and its selected
// WDB word on the SAME edge (zero additional write offset), freeing that slot.
// RD enable accompanies RD; PHY returns use the existing formatter register.
// This is a decoded core top: no AXI/APB, burst conversion, programmable PHY
// latency, initialization/control or CSR functionality is claimed here.
module mc16x2 (
  input  logic                 dfi_clk,
  input  logic                 ctl_reset_n,
  input  logic [31:0]           cmd_push_val,
  input  logic [31:0][35:0]     cmd_push_entry,
  output logic [31:0]           cmdq_full,
  input  logic [31:0]           wdb_push_val,
  input  logic [31:0][31:0]     wdb_push_data,
  input  logic [31:0][3:0]      wdb_push_mask,
  output logic [31:0][3:0]      wdb_alloc_ptr,
  output logic [31:0]           wdb_full,
  output logic [31:0]           rdb_valid,
  input  logic [31:0]           rdb_ready,
  output logic [31:0][31:0]     rdb_data,
  output logic [31:0][7:0]      rdb_axi_id,
  output logic [15:0]           dfi_row_val,
  output logic [15:0][21:0]     dfi_row,
  output logic [15:0]           dfi_col_val,
  output logic [15:0][11:0]     dfi_col,
  output logic [15:0][63:0]     dfi_wrdata,
  output logic [15:0][7:0]      dfi_wrdata_mask,
  output logic [15:0][1:0]      dfi_wrdata_en,
  output logic [15:0][1:0]      dfi_rddata_en,
  input  logic [15:0][63:0]     dfi_rddata,
  input  logic [15:0][1:0]      dfi_rddata_valid,
  output logic [31:0]           err_cmdq_overflow,
  output logic [31:0]           err_wdb_overflow,
  output logic [31:0]           err_ref_deadline_miss
);
  localparam logic [1:0] COL_RD = 2'b01;
  localparam logic [1:0] COL_WR = 2'b10;
  logic [31:0] row_req_valid, row_req_refresh, col_req_valid;
  logic [31:0][2:0] row_cmd;
  logic [31:0][13:0] row_addr;
  logic [31:0][1:0] row_bg, row_bank;
  logic [31:0][1:0] col_cmd;
  logic [31:0][4:0] col_addr;
  logic [31:0][1:0] col_bg, col_bank;
  logic [31:0][3:0] col_wdb_ptr;
  logic [31:0][7:0] col_axi_id;
  logic [31:0] row_grant, col_grant;
  logic [31:0][31:0] wdb_data, returned_data;
  logic [31:0][3:0] wdb_mask;
  logic [31:0] returned_valid;

  for (genvar ch = 0; ch < 16; ch++) begin : g_channel
    logic [1:0][21:0] row_candidates;
    logic [1:0][11:0] col_candidates;
    logic row_valid, col_valid, row_pc, col_pc;
    logic [21:0] selected_row;
    logic [11:0] selected_col;
    logic [63:0] lane_data;
    logic [7:0] lane_mask;
    logic [1:0] write_enable, read_enable;

    for (genvar pc = 0; pc < 2; pc++) begin : g_pc
      localparam int P = 2*ch + pc;
      logic write_issue;
      assign write_issue = col_grant[P] && (col_cmd[P] == COL_WR);
      assign row_candidates[pc] = {1'b0, row_cmd[P], row_bg[P], row_bank[P], row_addr[P]};
      assign col_candidates[pc] = {1'b0, col_cmd[P], col_bg[P], col_bank[P], col_addr[P]};
      assign lane_data[pc*32 +: 32] = write_issue ? wdb_data[P] : 32'b0;
      assign lane_mask[pc*4 +: 4] = write_issue ? wdb_mask[P] : 4'b0;
      assign write_enable[pc] = write_issue;
      assign read_enable[pc] = col_grant[P] && (col_cmd[P] == COL_RD);
      mc_pc_core u_pc_core (
        .clk(dfi_clk), .rst_n(ctl_reset_n),
        .cmd_push_val(cmd_push_val[P]), .cmd_push_entry(cmd_push_entry[P]), .cmdq_full(cmdq_full[P]),
        .wdb_push_val(wdb_push_val[P]), .wdb_push_data(wdb_push_data[P]),
        .wdb_push_mask(wdb_push_mask[P]), .wdb_alloc_ptr(wdb_alloc_ptr[P]), .wdb_full(wdb_full[P]),
        .wdb_raddr(col_wdb_ptr[P]), .wdb_rdata(wdb_data[P]), .wdb_rmask(wdb_mask[P]),
        .wdb_pop_val(write_issue), .wdb_pop_ptr(col_wdb_ptr[P]),
        .dfi_rddata_valid(returned_valid[P]), .dfi_rddata(returned_data[P]),
        .rdb_valid(rdb_valid[P]), .rdb_ready(rdb_ready[P]), .rdb_data(rdb_data[P]), .rdb_axi_id(rdb_axi_id[P]),
        .row_req_val(row_req_valid[P]), .row_req_is_ref(row_req_refresh[P]),
        .row_req_cmd(row_cmd[P]), .row_req_addr(row_addr[P]), .row_req_bg(row_bg[P]), .row_req_bank(row_bank[P]),
        .ch_arb_row_grant(row_grant[P]), .col_req_val(col_req_valid[P]), .col_req_cmd(col_cmd[P]),
        .col_req_addr(col_addr[P]), .col_req_bg(col_bg[P]), .col_req_bank(col_bank[P]),
        .col_req_wdb_ptr(col_wdb_ptr[P]), .col_req_axi_id(col_axi_id[P]), .ch_arb_col_grant(col_grant[P]),
        .err_cmdq_overflow(err_cmdq_overflow[P]), .err_wdb_overflow(err_wdb_overflow[P]),
        .err_ref_deadline_miss(err_ref_deadline_miss[P])
      );
    end
    mc_ch_arb u_ch_arb (
      .clk(dfi_clk), .rst_n(ctl_reset_n),
      .row_req_valid(row_req_valid[2*ch +: 2] & {2{ctl_reset_n}}),
      .row_req_legal(2'b11), .row_req_refresh(row_req_refresh[2*ch +: 2]),
      .row_grant_ack(2'b11), .row_cmd(row_candidates), .row_grant(row_grant[2*ch +: 2]),
      .row_valid(row_valid), .row_pc_sel(row_pc), .row_cmd_out(selected_row),
      .col_req_valid(col_req_valid[2*ch +: 2] & {2{ctl_reset_n}}),
      .col_req_legal(2'b11), .col_req_refresh(2'b00), .col_grant_ack(2'b11), .col_cmd(col_candidates),
      .col_grant(col_grant[2*ch +: 2]), .col_valid(col_valid), .col_pc_sel(col_pc), .col_cmd_out(selected_col)
    );
    mc_dfi_fmt u_dfi_fmt (
      .dfi_clk(dfi_clk), .dfi_reset_n(ctl_reset_n),
      .row_valid(row_valid), .row_pc_sel(row_pc), .row_cmd(selected_row[20:18]),
      .row_bg(selected_row[17:16]), .row_ba(selected_row[15:14]), .row_addr(selected_row[13:0]),
      .dfi_row_val(dfi_row_val[ch]), .dfi_row(dfi_row[ch]),
      .col_valid(col_valid), .col_pc_sel(col_pc), .col_cmd(selected_col[10:9]),
      .col_bg(selected_col[8:7]), .col_ba(selected_col[6:5]), .col_addr(selected_col[4:0]),
      .dfi_col_val(dfi_col_val[ch]), .dfi_col(dfi_col[ch]),
      .wrdata(lane_data), .wrdata_mask(lane_mask), .wrdata_en(write_enable),
      .dfi_wrdata(dfi_wrdata[ch]), .dfi_wrdata_mask(dfi_wrdata_mask[ch]), .dfi_wrdata_en(dfi_wrdata_en[ch]),
      .rddata_en(read_enable), .dfi_rddata_en(dfi_rddata_en[ch]),
      .dfi_rddata(dfi_rddata[ch]), .dfi_rddata_valid(dfi_rddata_valid[ch]),
      .rddata_pc0(returned_data[2*ch]), .rddata_pc1(returned_data[2*ch+1]),
      .rddata_valid(returned_valid[2*ch +: 2])
    );
  end
endmodule : mc16x2
`default_nettype wire
