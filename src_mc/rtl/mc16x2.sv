`timescale 1ns/1ps
`default_nettype none

// Unified AXI-facing top: 16 channels, two independent PC cores per channel.
// AXI subordinate, CDC and dispatch feed the channel cores within this module.
// The formatter captures each write command and its word on the same edge.
// Read returns must follow issue order independently for each PC.
// Reset contract: assert both resets together and flush external PHY returns;
// release each reset synchronously to its own clock. No independent warm reset.
module mc16x2 (
  input wire logic aclk, aresetn, dfi_clk, ctl_reset_n,
  input wire logic [7:0] s_axi_awid,
  input wire logic [39:0] s_axi_awaddr,
  input wire logic [7:0] s_axi_awlen,
  input wire logic [2:0] s_axi_awsize,
  input wire logic [1:0] s_axi_awburst,
  input wire logic  s_axi_awlock,
  input wire logic [3:0] s_axi_awqos,
  input wire logic [3:0] s_axi_awcache,
  input wire logic [2:0] s_axi_awprot,
  input wire logic  s_axi_awvalid,
  output logic  s_axi_awready,
  input wire logic [255:0] s_axi_wdata,
  input wire logic [31:0] s_axi_wstrb,
  input wire logic  s_axi_wlast,
  input wire logic  s_axi_wvalid,
  output logic  s_axi_wready,
  output logic [7:0] s_axi_bid,
  output logic [1:0] s_axi_bresp,
  output logic  s_axi_bvalid,
  input wire logic  s_axi_bready,
  input wire logic [7:0] s_axi_arid,
  input wire logic [39:0] s_axi_araddr,
  input wire logic [7:0] s_axi_arlen,
  input wire logic [2:0] s_axi_arsize,
  input wire logic [1:0] s_axi_arburst,
  input wire logic  s_axi_arlock,
  input wire logic [3:0] s_axi_arqos,
  input wire logic [3:0] s_axi_arcache,
  input wire logic [2:0] s_axi_arprot,
  input wire logic  s_axi_arvalid,
  output logic  s_axi_arready,
  output logic [7:0] s_axi_rid,
  output logic [255:0] s_axi_rdata,
  output logic [1:0] s_axi_rresp,
  output logic  s_axi_rlast,
  output logic  s_axi_rvalid,
  input wire logic  s_axi_rready,
  output logic [15:0] dfi_row_val,
  output logic [15:0][21:0] dfi_row,
  output logic [15:0] dfi_col_val,
  output logic [15:0][11:0] dfi_col,
  output logic [15:0][63:0] dfi_wrdata,
  output logic [15:0][7:0] dfi_wrdata_mask,
  output logic [15:0][1:0] dfi_wrdata_en,
  output logic [15:0][1:0] dfi_rddata_en,
  input wire logic [15:0][63:0] dfi_rddata,
  input wire logic [15:0][1:0] dfi_rddata_valid,
  output logic [31:0] err_cmdq_overflow,
  output logic [31:0] err_wdb_overflow,
  output logic [31:0] err_ref_deadline_miss
 );
  logic [7:0] m_awid;
  logic [39:0] m_awaddr;
  logic [7:0] m_awlen;
  logic [2:0] m_awsize;
  logic [1:0] m_awburst;
  logic  m_awlock;
  logic [3:0] m_awqos;
  logic [3:0] m_awcache;
  logic [2:0] m_awprot;
  logic  m_awvalid;
  logic  m_awready;
  logic [255:0] m_wdata;
  logic [31:0] m_wstrb;
  logic  m_wlast;
  logic  m_wvalid;
  logic  m_wready;
  logic [7:0] m_bid;
  logic [1:0] m_bresp;
  logic  m_bvalid;
  logic  m_bready;
  logic [7:0] m_arid;
  logic [39:0] m_araddr;
  logic [7:0] m_arlen;
  logic [2:0] m_arsize;
  logic [1:0] m_arburst;
  logic  m_arlock;
  logic [3:0] m_arqos;
  logic [3:0] m_arcache;
  logic [2:0] m_arprot;
  logic  m_arvalid;
  logic  m_arready;
  logic [7:0] m_rid;
  logic [255:0] m_rdata;
  logic [1:0] m_rresp;
  logic  m_rlast;
  logic  m_rvalid;
  logic  m_rready;
  logic [31:0] cmd_push_val, cmdq_full, wdb_push_val, wdb_full, wr_done, rdb_valid, rdb_ready;
  logic [31:0][35:0] cmd_push_entry;
  logic [31:0][31:0] wdb_push_data, rdb_data;
  logic [31:0][3:0] wdb_push_mask, wdb_alloc_ptr;
  logic [31:0][7:0] rdb_axi_id;
  // AXI-domain connection from the subordinate interface to the CDC FIFOs.
  logic [7:0] sub_awid;
  logic [39:0] sub_awaddr;
  logic [7:0] sub_awlen;
  logic [2:0] sub_awsize;
  logic [1:0] sub_awburst;
  logic sub_awlock;
  logic [3:0] sub_awqos;
  logic [3:0] sub_awcache;
  logic [2:0] sub_awprot;
  logic sub_awvalid;
  logic sub_awready;
  logic [255:0] sub_wdata;
  logic [31:0] sub_wstrb;
  logic sub_wlast;
  logic sub_wvalid;
  logic sub_wready;
  logic [7:0] sub_bid;
  logic [1:0] sub_bresp;
  logic sub_bvalid;
  logic sub_bready;
  logic [7:0] sub_arid;
  logic [39:0] sub_araddr;
  logic [7:0] sub_arlen;
  logic [2:0] sub_arsize;
  logic [1:0] sub_arburst;
  logic sub_arlock;
  logic [3:0] sub_arqos;
  logic [3:0] sub_arcache;
  logic [2:0] sub_arprot;
  logic sub_arvalid;
  logic sub_arready;
  logic [7:0] sub_rid;
  logic [255:0] sub_rdata;
  logic [1:0] sub_rresp;
  logic sub_rlast;
  logic sub_rvalid;
  logic sub_rready;

  mc_axi_sub #(
    .AXI_DATA_W(256), .AXI_ADDR_W(40), .AXI_ID_W(8)
  ) u_axi_sub (
    .awid(s_axi_awid),
    .cdc_awid(sub_awid),
    .awaddr(s_axi_awaddr),
    .cdc_awaddr(sub_awaddr),
    .awlen(s_axi_awlen),
    .cdc_awlen(sub_awlen),
    .awsize(s_axi_awsize),
    .cdc_awsize(sub_awsize),
    .awburst(s_axi_awburst),
    .cdc_awburst(sub_awburst),
    .awlock(s_axi_awlock),
    .cdc_awlock(sub_awlock),
    .awqos(s_axi_awqos),
    .cdc_awqos(sub_awqos),
    .awcache(s_axi_awcache),
    .cdc_awcache(sub_awcache),
    .awprot(s_axi_awprot),
    .cdc_awprot(sub_awprot),
    .awvalid(s_axi_awvalid),
    .cdc_awvalid(sub_awvalid),
    .awready(s_axi_awready),
    .cdc_awready(sub_awready),
    .wdata(s_axi_wdata),
    .cdc_wdata(sub_wdata),
    .wstrb(s_axi_wstrb),
    .cdc_wstrb(sub_wstrb),
    .wlast(s_axi_wlast),
    .cdc_wlast(sub_wlast),
    .wvalid(s_axi_wvalid),
    .cdc_wvalid(sub_wvalid),
    .wready(s_axi_wready),
    .cdc_wready(sub_wready),
    .bid(s_axi_bid),
    .cdc_bid(sub_bid),
    .bresp(s_axi_bresp),
    .cdc_bresp(sub_bresp),
    .bvalid(s_axi_bvalid),
    .cdc_bvalid(sub_bvalid),
    .bready(s_axi_bready),
    .cdc_bready(sub_bready),
    .arid(s_axi_arid),
    .cdc_arid(sub_arid),
    .araddr(s_axi_araddr),
    .cdc_araddr(sub_araddr),
    .arlen(s_axi_arlen),
    .cdc_arlen(sub_arlen),
    .arsize(s_axi_arsize),
    .cdc_arsize(sub_arsize),
    .arburst(s_axi_arburst),
    .cdc_arburst(sub_arburst),
    .arlock(s_axi_arlock),
    .cdc_arlock(sub_arlock),
    .arqos(s_axi_arqos),
    .cdc_arqos(sub_arqos),
    .arcache(s_axi_arcache),
    .cdc_arcache(sub_arcache),
    .arprot(s_axi_arprot),
    .cdc_arprot(sub_arprot),
    .arvalid(s_axi_arvalid),
    .cdc_arvalid(sub_arvalid),
    .arready(s_axi_arready),
    .cdc_arready(sub_arready),
    .rid(s_axi_rid),
    .cdc_rid(sub_rid),
    .rdata(s_axi_rdata),
    .cdc_rdata(sub_rdata),
    .rresp(s_axi_rresp),
    .cdc_rresp(sub_rresp),
    .rlast(s_axi_rlast),
    .cdc_rlast(sub_rlast),
    .rvalid(s_axi_rvalid),
    .cdc_rvalid(sub_rvalid),
    .rready(s_axi_rready),
    .cdc_rready(sub_rready)
  );

  mc_axi_cdc u_axi_cdc (
    .aclk(aclk),
    .aresetn(aresetn),
    .dfi_clk(dfi_clk),
    .ctl_reset_n(ctl_reset_n),
    .s_awid(sub_awid),
    .m_awid(m_awid),
    .s_awaddr(sub_awaddr),
    .m_awaddr(m_awaddr),
    .s_awlen(sub_awlen),
    .m_awlen(m_awlen),
    .s_awsize(sub_awsize),
    .m_awsize(m_awsize),
    .s_awburst(sub_awburst),
    .m_awburst(m_awburst),
    .s_awlock(sub_awlock),
    .m_awlock(m_awlock),
    .s_awqos(sub_awqos),
    .m_awqos(m_awqos),
    .s_awcache(sub_awcache),
    .m_awcache(m_awcache),
    .s_awprot(sub_awprot),
    .m_awprot(m_awprot),
    .s_awvalid(sub_awvalid),
    .m_awvalid(m_awvalid),
    .s_awready(sub_awready),
    .m_awready(m_awready),
    .s_wdata(sub_wdata),
    .m_wdata(m_wdata),
    .s_wstrb(sub_wstrb),
    .m_wstrb(m_wstrb),
    .s_wlast(sub_wlast),
    .m_wlast(m_wlast),
    .s_wvalid(sub_wvalid),
    .m_wvalid(m_wvalid),
    .s_wready(sub_wready),
    .m_wready(m_wready),
    .s_bid(sub_bid),
    .m_bid(m_bid),
    .s_bresp(sub_bresp),
    .m_bresp(m_bresp),
    .s_bvalid(sub_bvalid),
    .m_bvalid(m_bvalid),
    .s_bready(sub_bready),
    .m_bready(m_bready),
    .s_arid(sub_arid),
    .m_arid(m_arid),
    .s_araddr(sub_araddr),
    .m_araddr(m_araddr),
    .s_arlen(sub_arlen),
    .m_arlen(m_arlen),
    .s_arsize(sub_arsize),
    .m_arsize(m_arsize),
    .s_arburst(sub_arburst),
    .m_arburst(m_arburst),
    .s_arlock(sub_arlock),
    .m_arlock(m_arlock),
    .s_arqos(sub_arqos),
    .m_arqos(m_arqos),
    .s_arcache(sub_arcache),
    .m_arcache(m_arcache),
    .s_arprot(sub_arprot),
    .m_arprot(m_arprot),
    .s_arvalid(sub_arvalid),
    .m_arvalid(m_arvalid),
    .s_arready(sub_arready),
    .m_arready(m_arready),
    .s_rid(sub_rid),
    .m_rid(m_rid),
    .s_rdata(sub_rdata),
    .m_rdata(m_rdata),
    .s_rresp(sub_rresp),
    .m_rresp(m_rresp),
    .s_rlast(sub_rlast),
    .m_rlast(m_rlast),
    .s_rvalid(sub_rvalid),
    .m_rvalid(m_rvalid),
    .s_rready(sub_rready),
    .m_rready(m_rready),
    .m_aw_ch_sel(),
    .m_aw_pc_sel(),
    .m_aw_row_addr(),
    .m_aw_bank_group(),
    .m_aw_bank_addr(),
    .m_aw_col_addr(),
    .m_ar_ch_sel(),
    .m_ar_pc_sel(),
    .m_ar_row_addr(),
    .m_ar_bank_group(),
    .m_ar_bank_addr(),
    .m_ar_col_addr()
  );
  mc_addr_decode u_addr_decode (
    .clk(dfi_clk),
    .rst_n(ctl_reset_n),
    .awid(m_awid),
    .awaddr(m_awaddr),
    .awlen(m_awlen),
    .awsize(m_awsize),
    .awburst(m_awburst),
    .awvalid(m_awvalid),
    .awready(m_awready),
    .wdata(m_wdata),
    .wstrb(m_wstrb),
    .wvalid(m_wvalid),
    .wready(m_wready),
    .bid(m_bid),
    .bresp(m_bresp),
    .bvalid(m_bvalid),
    .bready(m_bready),
    .arid(m_arid),
    .araddr(m_araddr),
    .arlen(m_arlen),
    .arsize(m_arsize),
    .arburst(m_arburst),
    .arvalid(m_arvalid),
    .arready(m_arready),
    .rid(m_rid),
    .rdata(m_rdata),
    .rresp(m_rresp),
    .rlast(m_rlast),
    .rvalid(m_rvalid),
    .rready(m_rready),
    .cmd_push_val(cmd_push_val),
    .cmd_push_entry(cmd_push_entry),
    .cmdq_full(cmdq_full),
    .wdb_push_val(wdb_push_val),
    .wdb_push_data(wdb_push_data),
    .wdb_push_mask(wdb_push_mask),
    .wdb_alloc_ptr(wdb_alloc_ptr),
    .wdb_full(wdb_full),
    .wr_done(wr_done),
    .rdb_valid(rdb_valid),
    .rdb_ready(rdb_ready),
    .rdb_data(rdb_data)
  );

  // Channel scheduling, buffers, arbitration and DFI formatting.
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
      assign wr_done[P] = dfi_wrdata_en[ch][pc];
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
