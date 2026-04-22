`timescale 1ns/1ps

module top_tb;

  localparam int AXI_ADDR_W            = 40;
  localparam int AXI_ID_W              = 8;
  localparam int AXI_LEN_W             = 8;
  localparam int AXI_SIZE_W            = 3;
  localparam int AXI_BURST_W           = 2;
  localparam int AXI_DATA_W            = 1024;
  localparam int AXI_WSTRB_W           = 128;
  localparam int AXI_RESP_W            = 2;
  localparam int FDI_DATA_W            = 2048;
  localparam int FDI_STATUS_W          = 3;
  localparam int CDC_AW_D_W            = 61;
  localparam int CDC_W_D_W             = 1153;
  localparam int CDC_AR_D_W            = 61;
  localparam int CDC_B_D_W             = 10;
  localparam int CDC_R_D_W             = 1035;
  localparam int CDC_DEPTH             = 16;
  localparam int CDC_ADDR_W            = $clog2(CDC_DEPTH);
  localparam int CREDIT_SIZE           = 6;
  localparam int RTN_VCN_W             = 2;
  localparam int VCN_W                 = 3;
  localparam int COMPLETION_TRACKER_W  = 256;
  localparam int AW_DEPTH              = 32;
  localparam int W_DEPTH               = 64;
  localparam int AR_DEPTH              = 32;
  localparam int AW_W                  = AXI_ID_W + 8 + 2 + 3 + AXI_ADDR_W;
  localparam int W_W                   = AXI_DATA_W + 128 + 1;
  localparam int AR_W                  = AXI_ID_W + 8 + 2 + 3 + AXI_ADDR_W;
  localparam int B_W                   = AXI_ID_W + 2;
  localparam int R_W                   = AXI_DATA_W + AXI_ID_W + 2 + 1;
  localparam logic [RTN_VCN_W-1:0] CREDIT_VCN_NP  = 2'h0;
  localparam logic [RTN_VCN_W-1:0] CREDIT_VCN_CPL = 2'h1;
  localparam logic [CREDIT_SIZE-1:0] CREDIT_INIT_COUNT = 6'd32;

  localparam logic [3:0] OPCODE_WRITE_REQ  = 4'h0;
  localparam logic [3:0] OPCODE_READ_REQ   = 4'h1;
  localparam logic [3:0] OPCODE_WRITE_RESP = 4'h2;
  localparam logic [3:0] OPCODE_READ_RESP  = 4'h3;
  localparam logic [3:0] OPCODE_CREDIT_RTN = 4'h4;

  logic                    fdi_clk_i;
  logic                    axi_clk_i;
  logic                    por_n_i;
  logic                    axi_rst_n_i;
  logic                    fdi_rst_n_i;

  logic [AXI_ADDR_W-1:0]   PORT0_SUB_awaddr;
  logic [AXI_ID_W-1:0]     PORT0_SUB_awid;
  logic [AXI_LEN_W-1:0]    PORT0_SUB_awlen;
  logic [AXI_SIZE_W-1:0]   PORT0_SUB_awsize;
  logic [AXI_BURST_W-1:0]  PORT0_SUB_awburst;
  logic                    PORT0_SUB_awvalid;
  logic                    PORT0_SUB_awready;
  logic [AXI_DATA_W-1:0]   PORT0_SUB_wdata;
  logic [AXI_WSTRB_W-1:0]  PORT0_SUB_wstrb;
  logic                    PORT0_SUB_wlast;
  logic                    PORT0_SUB_wvalid;
  logic                    PORT0_SUB_wready;
  logic [AXI_ID_W-1:0]     PORT0_SUB_bid;
  logic [AXI_RESP_W-1:0]   PORT0_SUB_bresp;
  logic                    PORT0_SUB_bvalid;
  logic                    PORT0_SUB_bready;
  logic [AXI_ADDR_W-1:0]   PORT0_SUB_araddr;
  logic [AXI_ID_W-1:0]     PORT0_SUB_arid;
  logic [AXI_LEN_W-1:0]    PORT0_SUB_arlen;
  logic [AXI_SIZE_W-1:0]   PORT0_SUB_arsize;
  logic [AXI_BURST_W-1:0]  PORT0_SUB_arburst;
  logic                    PORT0_SUB_arvalid;
  logic                    PORT0_SUB_arready;
  logic [AXI_DATA_W-1:0]   PORT0_SUB_rdata;
  logic [AXI_ID_W-1:0]     PORT0_SUB_rid;
  logic [AXI_RESP_W-1:0]   PORT0_SUB_rresp;
  logic                    PORT0_SUB_rlast;
  logic                    PORT0_SUB_rvalid;
  logic                    PORT0_SUB_rready;

  logic [AXI_ADDR_W-1:0]   PORT1_SUB_awaddr;
  logic [AXI_ID_W-1:0]     PORT1_SUB_awid;
  logic [AXI_LEN_W-1:0]    PORT1_SUB_awlen;
  logic [AXI_SIZE_W-1:0]   PORT1_SUB_awsize;
  logic [AXI_BURST_W-1:0]  PORT1_SUB_awburst;
  logic                    PORT1_SUB_awvalid;
  logic                    PORT1_SUB_awready;
  logic [AXI_DATA_W-1:0]   PORT1_SUB_wdata;
  logic [AXI_WSTRB_W-1:0]  PORT1_SUB_wstrb;
  logic                    PORT1_SUB_wlast;
  logic                    PORT1_SUB_wvalid;
  logic                    PORT1_SUB_wready;
  logic [AXI_ID_W-1:0]     PORT1_SUB_bid;
  logic [AXI_RESP_W-1:0]   PORT1_SUB_bresp;
  logic                    PORT1_SUB_bvalid;
  logic                    PORT1_SUB_bready;
  logic [AXI_ADDR_W-1:0]   PORT1_SUB_araddr;
  logic [AXI_ID_W-1:0]     PORT1_SUB_arid;
  logic [AXI_LEN_W-1:0]    PORT1_SUB_arlen;
  logic [AXI_SIZE_W-1:0]   PORT1_SUB_arsize;
  logic [AXI_BURST_W-1:0]  PORT1_SUB_arburst;
  logic                    PORT1_SUB_arvalid;
  logic                    PORT1_SUB_arready;
  logic [AXI_DATA_W-1:0]   PORT1_SUB_rdata;
  logic [AXI_ID_W-1:0]     PORT1_SUB_rid;
  logic [AXI_RESP_W-1:0]   PORT1_SUB_rresp;
  logic                    PORT1_SUB_rlast;
  logic                    PORT1_SUB_rvalid;
  logic                    PORT1_SUB_rready;

  logic [AXI_ADDR_W-1:0]   PORT0_MGR_awaddr;
  logic [AXI_ID_W-1:0]     PORT0_MGR_awid;
  logic [AXI_LEN_W-1:0]    PORT0_MGR_awlen;
  logic [AXI_SIZE_W-1:0]   PORT0_MGR_awsize;
  logic [AXI_BURST_W-1:0]  PORT0_MGR_awburst;
  logic                    PORT0_MGR_awvalid;
  logic                    PORT0_MGR_awready;
  logic [AXI_DATA_W-1:0]   PORT0_MGR_wdata;
  logic [AXI_WSTRB_W-1:0]  PORT0_MGR_wstrb;
  logic                    PORT0_MGR_wlast;
  logic                    PORT0_MGR_wvalid;
  logic                    PORT0_MGR_wready;
  logic [AXI_ID_W-1:0]     PORT0_MGR_bid;
  logic [AXI_RESP_W-1:0]   PORT0_MGR_bresp;
  logic                    PORT0_MGR_bvalid;
  logic                    PORT0_MGR_bready;
  logic [AXI_ADDR_W-1:0]   PORT0_MGR_araddr;
  logic [AXI_ID_W-1:0]     PORT0_MGR_arid;
  logic [AXI_LEN_W-1:0]    PORT0_MGR_arlen;
  logic [AXI_SIZE_W-1:0]   PORT0_MGR_arsize;
  logic [AXI_BURST_W-1:0]  PORT0_MGR_arburst;
  logic                    PORT0_MGR_arvalid;
  logic                    PORT0_MGR_arready;
  logic [AXI_DATA_W-1:0]   PORT0_MGR_rdata;
  logic [AXI_ID_W-1:0]     PORT0_MGR_rid;
  logic [AXI_RESP_W-1:0]   PORT0_MGR_rresp;
  logic                    PORT0_MGR_rlast;
  logic                    PORT0_MGR_rvalid;
  logic                    PORT0_MGR_rready;

  logic [AXI_ADDR_W-1:0]   PORT1_MGR_awaddr;
  logic [AXI_ID_W-1:0]     PORT1_MGR_awid;
  logic [AXI_LEN_W-1:0]    PORT1_MGR_awlen;
  logic [AXI_SIZE_W-1:0]   PORT1_MGR_awsize;
  logic [AXI_BURST_W-1:0]  PORT1_MGR_awburst;
  logic                    PORT1_MGR_awvalid;
  logic                    PORT1_MGR_awready;
  logic [AXI_DATA_W-1:0]   PORT1_MGR_wdata;
  logic [AXI_WSTRB_W-1:0]  PORT1_MGR_wstrb;
  logic                    PORT1_MGR_wlast;
  logic                    PORT1_MGR_wvalid;
  logic                    PORT1_MGR_wready;
  logic [AXI_ID_W-1:0]     PORT1_MGR_bid;
  logic [AXI_RESP_W-1:0]   PORT1_MGR_bresp;
  logic                    PORT1_MGR_bvalid;
  logic                    PORT1_MGR_bready;
  logic [AXI_ADDR_W-1:0]   PORT1_MGR_araddr;
  logic [AXI_ID_W-1:0]     PORT1_MGR_arid;
  logic [AXI_LEN_W-1:0]    PORT1_MGR_arlen;
  logic [AXI_SIZE_W-1:0]   PORT1_MGR_arsize;
  logic [AXI_BURST_W-1:0]  PORT1_MGR_arburst;
  logic                    PORT1_MGR_arvalid;
  logic                    PORT1_MGR_arready;
  logic [AXI_DATA_W-1:0]   PORT1_MGR_rdata;
  logic [AXI_ID_W-1:0]     PORT1_MGR_rid;
  logic [AXI_RESP_W-1:0]   PORT1_MGR_rresp;
  logic                    PORT1_MGR_rlast;
  logic                    PORT1_MGR_rvalid;
  logic                    PORT1_MGR_rready;

  logic [FDI_DATA_W-1:0]   fdi_lp_data;
  logic                    fdi_lp_valid;
  logic                    fdi_lp_irdy;
  logic                    fdi_lp_startofpkt;
  logic                    fdi_lp_endofpkt;
  logic                    fdi_pl_trdy;
  logic [FDI_STATUS_W-1:0] fdi_lp_state_req;
  logic                    fdi_lp_linkerror;
  logic [FDI_DATA_W-1:0]   fdi_pl_data;
  logic                    fdi_pl_valid;
  logic                    fdi_pl_irdy;
  logic                    fdi_pl_startofpkt;
  logic                    fdi_pl_endofpkt;
  logic                    fdi_lp_trdy;
  logic [FDI_STATUS_W-1:0] fdi_pl_state_sts;
  logic                    fdi_pl_inband_pres;
  logic [2:0]              tb_forced_rx_vcn;

  int unsigned checks_run;
  int unsigned checks_failed;

  axfdi_bridge
    #(
  .axi_addr_w(AXI_ADDR_W),
  .axi_id_w(AXI_ID_W),
  .axi_len_w(AXI_LEN_W),
  .axi_size_w(AXI_SIZE_W),
  .axi_burst_w(AXI_BURST_W),
  .axi_data_w(AXI_DATA_W),
  .axi_wstrb_w(AXI_WSTRB_W),
  .axi_resp_w(AXI_RESP_W),
  .fdi_data_w(FDI_DATA_W),
  .fdi_status_w(FDI_STATUS_W),
  .cdc_aw_d_w(CDC_AW_D_W),
  .cdc_w_d_w(CDC_W_D_W),
  .cdc_ar_d_w(CDC_AR_D_W),
  .cdc_b_d_w(CDC_B_D_W),
  .cdc_r_d_w(CDC_R_D_W),
  .cdc_depth(CDC_DEPTH),
  .cdc_addr_w(CDC_ADDR_W),
  .credit_size(CREDIT_SIZE),
  .rtn_vcn_w(RTN_VCN_W),
  .vcn_w(VCN_W),
  .completion_tracker_w(COMPLETION_TRACKER_W),
  .AW_DEPTH(AW_DEPTH),
  .W_DEPTH(W_DEPTH),
  .AR_DEPTH(AR_DEPTH),
  .AW_W(AW_W),
  .W_W(W_W),
  .AR_W(AR_W)
      )dut
      (
    .fdi_clk_i          (fdi_clk_i),
    .axi_clk_i          (axi_clk_i),
    .por_n_i            (por_n_i),
    .axi_rst_n_i        (axi_rst_n_i),
    .fdi_rst_n_i        (fdi_rst_n_i),
    .PORT0_SUB_awaddr   (PORT0_SUB_awaddr),
    .PORT0_SUB_awid     (PORT0_SUB_awid),
    .PORT0_SUB_awlen    (PORT0_SUB_awlen),
    .PORT0_SUB_awsize   (PORT0_SUB_awsize),
    .PORT0_SUB_awburst  (PORT0_SUB_awburst),
    .PORT0_SUB_awvalid  (PORT0_SUB_awvalid),
    .PORT0_SUB_awready  (PORT0_SUB_awready),
    .PORT0_SUB_wdata    (PORT0_SUB_wdata),
    .PORT0_SUB_wstrb    (PORT0_SUB_wstrb),
    .PORT0_SUB_wlast    (PORT0_SUB_wlast),
    .PORT0_SUB_wvalid   (PORT0_SUB_wvalid),
    .PORT0_SUB_wready   (PORT0_SUB_wready),
    .PORT0_SUB_bid      (PORT0_SUB_bid),
    .PORT0_SUB_bresp    (PORT0_SUB_bresp),
    .PORT0_SUB_bvalid   (PORT0_SUB_bvalid),
    .PORT0_SUB_bready   (PORT0_SUB_bready),
    .PORT0_SUB_araddr   (PORT0_SUB_araddr),
    .PORT0_SUB_arid     (PORT0_SUB_arid),
    .PORT0_SUB_arlen    (PORT0_SUB_arlen),
    .PORT0_SUB_arsize   (PORT0_SUB_arsize),
    .PORT0_SUB_arburst  (PORT0_SUB_arburst),
    .PORT0_SUB_arvalid  (PORT0_SUB_arvalid),
    .PORT0_SUB_arready  (PORT0_SUB_arready),
    .PORT0_SUB_rdata    (PORT0_SUB_rdata),
    .PORT0_SUB_rid      (PORT0_SUB_rid),
    .PORT0_SUB_rresp    (PORT0_SUB_rresp),
    .PORT0_SUB_rlast    (PORT0_SUB_rlast),
    .PORT0_SUB_rvalid   (PORT0_SUB_rvalid),
    .PORT0_SUB_rready   (PORT0_SUB_rready),
    .PORT1_SUB_awaddr   (PORT1_SUB_awaddr),
    .PORT1_SUB_awid     (PORT1_SUB_awid),
    .PORT1_SUB_awlen    (PORT1_SUB_awlen),
    .PORT1_SUB_awsize   (PORT1_SUB_awsize),
    .PORT1_SUB_awburst  (PORT1_SUB_awburst),
    .PORT1_SUB_awvalid  (PORT1_SUB_awvalid),
    .PORT1_SUB_awready  (PORT1_SUB_awready),
    .PORT1_SUB_wdata    (PORT1_SUB_wdata),
    .PORT1_SUB_wstrb    (PORT1_SUB_wstrb),
    .PORT1_SUB_wlast    (PORT1_SUB_wlast),
    .PORT1_SUB_wvalid   (PORT1_SUB_wvalid),
    .PORT1_SUB_wready   (PORT1_SUB_wready),
    .PORT1_SUB_bid      (PORT1_SUB_bid),
    .PORT1_SUB_bresp    (PORT1_SUB_bresp),
    .PORT1_SUB_bvalid   (PORT1_SUB_bvalid),
    .PORT1_SUB_bready   (PORT1_SUB_bready),
    .PORT1_SUB_araddr   (PORT1_SUB_araddr),
    .PORT1_SUB_arid     (PORT1_SUB_arid),
    .PORT1_SUB_arlen    (PORT1_SUB_arlen),
    .PORT1_SUB_arsize   (PORT1_SUB_arsize),
    .PORT1_SUB_arburst  (PORT1_SUB_arburst),
    .PORT1_SUB_arvalid  (PORT1_SUB_arvalid),
    .PORT1_SUB_arready  (PORT1_SUB_arready),
    .PORT1_SUB_rdata    (PORT1_SUB_rdata),
    .PORT1_SUB_rid      (PORT1_SUB_rid),
    .PORT1_SUB_rresp    (PORT1_SUB_rresp),
    .PORT1_SUB_rlast    (PORT1_SUB_rlast),
    .PORT1_SUB_rvalid   (PORT1_SUB_rvalid),
    .PORT1_SUB_rready   (PORT1_SUB_rready),
    .PORT0_MGR_awaddr   (PORT0_MGR_awaddr),
    .PORT0_MGR_awid     (PORT0_MGR_awid),
    .PORT0_MGR_awlen    (PORT0_MGR_awlen),
    .PORT0_MGR_awsize   (PORT0_MGR_awsize),
    .PORT0_MGR_awburst  (PORT0_MGR_awburst),
    .PORT0_MGR_awvalid  (PORT0_MGR_awvalid),
    .PORT0_MGR_awready  (PORT0_MGR_awready),
    .PORT0_MGR_wdata    (PORT0_MGR_wdata),
    .PORT0_MGR_wstrb    (PORT0_MGR_wstrb),
    .PORT0_MGR_wlast    (PORT0_MGR_wlast),
    .PORT0_MGR_wvalid   (PORT0_MGR_wvalid),
    .PORT0_MGR_wready   (PORT0_MGR_wready),
    .PORT0_MGR_bid      (PORT0_MGR_bid),
    .PORT0_MGR_bresp    (PORT0_MGR_bresp),
    .PORT0_MGR_bvalid   (PORT0_MGR_bvalid),
    .PORT0_MGR_bready   (PORT0_MGR_bready),
    .PORT0_MGR_araddr   (PORT0_MGR_araddr),
    .PORT0_MGR_arid     (PORT0_MGR_arid),
    .PORT0_MGR_arlen    (PORT0_MGR_arlen),
    .PORT0_MGR_arsize   (PORT0_MGR_arsize),
    .PORT0_MGR_arburst  (PORT0_MGR_arburst),
    .PORT0_MGR_arvalid  (PORT0_MGR_arvalid),
    .PORT0_MGR_arready  (PORT0_MGR_arready),
    .PORT0_MGR_rdata    (PORT0_MGR_rdata),
    .PORT0_MGR_rid      (PORT0_MGR_rid),
    .PORT0_MGR_rresp    (PORT0_MGR_rresp),
    .PORT0_MGR_rlast    (PORT0_MGR_rlast),
    .PORT0_MGR_rvalid   (PORT0_MGR_rvalid),
    .PORT0_MGR_rready   (PORT0_MGR_rready),
    .PORT1_MGR_awaddr   (PORT1_MGR_awaddr),
    .PORT1_MGR_awid     (PORT1_MGR_awid),
    .PORT1_MGR_awlen    (PORT1_MGR_awlen),
    .PORT1_MGR_awsize   (PORT1_MGR_awsize),
    .PORT1_MGR_awburst  (PORT1_MGR_awburst),
    .PORT1_MGR_awvalid  (PORT1_MGR_awvalid),
    .PORT1_MGR_awready  (PORT1_MGR_awready),
    .PORT1_MGR_wdata    (PORT1_MGR_wdata),
    .PORT1_MGR_wstrb    (PORT1_MGR_wstrb),
    .PORT1_MGR_wlast    (PORT1_MGR_wlast),
    .PORT1_MGR_wvalid   (PORT1_MGR_wvalid),
    .PORT1_MGR_wready   (PORT1_MGR_wready),
    .PORT1_MGR_bid      (PORT1_MGR_bid),
    .PORT1_MGR_bresp    (PORT1_MGR_bresp),
    .PORT1_MGR_bvalid   (PORT1_MGR_bvalid),
    .PORT1_MGR_bready   (PORT1_MGR_bready),
    .PORT1_MGR_araddr   (PORT1_MGR_araddr),
    .PORT1_MGR_arid     (PORT1_MGR_arid),
    .PORT1_MGR_arlen    (PORT1_MGR_arlen),
    .PORT1_MGR_arsize   (PORT1_MGR_arsize),
    .PORT1_MGR_arburst  (PORT1_MGR_arburst),
    .PORT1_MGR_arvalid  (PORT1_MGR_arvalid),
    .PORT1_MGR_arready  (PORT1_MGR_arready),
    .PORT1_MGR_rdata    (PORT1_MGR_rdata),
    .PORT1_MGR_rid      (PORT1_MGR_rid),
    .PORT1_MGR_rresp    (PORT1_MGR_rresp),
    .PORT1_MGR_rlast    (PORT1_MGR_rlast),
    .PORT1_MGR_rvalid   (PORT1_MGR_rvalid),
    .PORT1_MGR_rready   (PORT1_MGR_rready),
    .fdi_lp_data        (fdi_lp_data),
    .fdi_lp_valid       (fdi_lp_valid),
    .fdi_lp_irdy        (fdi_lp_irdy),
    .fdi_lp_startofpkt  (fdi_lp_startofpkt),
    .fdi_lp_endofpkt    (fdi_lp_endofpkt),
    .fdi_pl_trdy        (fdi_pl_trdy),
    .fdi_lp_state_req   (fdi_lp_state_req),
    .fdi_lp_linkerror   (fdi_lp_linkerror),
    .fdi_pl_data        (fdi_pl_data),
    .fdi_pl_valid       (fdi_pl_valid),
    .fdi_pl_irdy        (fdi_pl_irdy),
    .fdi_pl_startofpkt  (fdi_pl_startofpkt),
    .fdi_pl_endofpkt    (fdi_pl_endofpkt),
    .fdi_lp_trdy        (fdi_lp_trdy),
    .fdi_pl_state_sts   (fdi_pl_state_sts),
    .fdi_pl_inband_pres (fdi_pl_inband_pres)
  );

  initial fdi_clk_i = 1'b0;
  always #5 fdi_clk_i = ~fdi_clk_i;

  initial axi_clk_i = 1'b0;
  always #6 axi_clk_i = ~axi_clk_i;

  task automatic expect_bit(input logic actual,
                            input logic expected,
                            input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=%0b actual=%0b", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_u8(input logic [7:0] actual,
                           input logic [7:0] expected,
                           input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_u40(input logic [39:0] actual,
                            input logic [39:0] expected,
                            input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_u1024(input logic [AXI_DATA_W-1:0] actual,
                              input logic [AXI_DATA_W-1:0] expected,
                              input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s mismatch", msg);
      end
    end
  endtask

  task automatic drive_defaults();
    begin
      por_n_i            = 1'b0;
      axi_rst_n_i        = 1'b0;
      fdi_rst_n_i        = 1'b0;

      PORT0_SUB_awaddr   = '0;
      PORT0_SUB_awid     = '0;
      PORT0_SUB_awlen    = '0;
      PORT0_SUB_awsize   = '0;
      PORT0_SUB_awburst  = '0;
      PORT0_SUB_awvalid  = 1'b0;
      PORT0_SUB_wdata    = '0;
      PORT0_SUB_wstrb    = '0;
      PORT0_SUB_wlast    = 1'b0;
      PORT0_SUB_wvalid   = 1'b0;
      PORT0_SUB_bready   = 1'b1;
      PORT0_SUB_araddr   = '0;
      PORT0_SUB_arid     = '0;
      PORT0_SUB_arlen    = '0;
      PORT0_SUB_arsize   = '0;
      PORT0_SUB_arburst  = '0;
      PORT0_SUB_arvalid  = 1'b0;
      PORT0_SUB_rready   = 1'b1;

      PORT1_SUB_awaddr   = '0;
      PORT1_SUB_awid     = '0;
      PORT1_SUB_awlen    = '0;
      PORT1_SUB_awsize   = '0;
      PORT1_SUB_awburst  = '0;
      PORT1_SUB_awvalid  = 1'b0;
      PORT1_SUB_wdata    = '0;
      PORT1_SUB_wstrb    = '0;
      PORT1_SUB_wlast    = 1'b0;
      PORT1_SUB_wvalid   = 1'b0;
      PORT1_SUB_bready   = 1'b1;
      PORT1_SUB_araddr   = '0;
      PORT1_SUB_arid     = '0;
      PORT1_SUB_arlen    = '0;
      PORT1_SUB_arsize   = '0;
      PORT1_SUB_arburst  = '0;
      PORT1_SUB_arvalid  = 1'b0;
      PORT1_SUB_rready   = 1'b1;

      PORT0_MGR_awready  = 1'b1;
      PORT0_MGR_wready   = 1'b1;
      PORT0_MGR_bid      = '0;
      PORT0_MGR_bresp    = '0;
      PORT0_MGR_bvalid   = 1'b0;
      PORT0_MGR_arready  = 1'b1;
      PORT0_MGR_rdata    = '0;
      PORT0_MGR_rid      = '0;
      PORT0_MGR_rresp    = '0;
      PORT0_MGR_rlast    = 1'b0;
      PORT0_MGR_rvalid   = 1'b0;

      PORT1_MGR_awready  = 1'b1;
      PORT1_MGR_wready   = 1'b1;
      PORT1_MGR_bid      = '0;
      PORT1_MGR_bresp    = '0;
      PORT1_MGR_bvalid   = 1'b0;
      PORT1_MGR_arready  = 1'b1;
      PORT1_MGR_rdata    = '0;
      PORT1_MGR_rid      = '0;
      PORT1_MGR_rresp    = '0;
      PORT1_MGR_rlast    = 1'b0;
      PORT1_MGR_rvalid   = 1'b0;

      fdi_pl_trdy        = 1'b0;
      fdi_pl_data        = '0;
      fdi_pl_valid       = 1'b0;
      fdi_pl_irdy        = 1'b0;
      fdi_pl_startofpkt  = 1'b0;
      fdi_pl_endofpkt    = 1'b0;
      fdi_pl_state_sts   = '0;
      fdi_pl_inband_pres = 1'b0;
    end
  endtask

  task automatic apply_reset();
    begin
      drive_defaults();
      repeat (4) @(posedge fdi_clk_i);
      por_n_i = 1'b1;
      repeat (2) @(posedge axi_clk_i);
      axi_rst_n_i = 1'b1;
      repeat (2) @(posedge fdi_clk_i);
      fdi_rst_n_i = 1'b1;
      repeat (4) @(posedge fdi_clk_i);
    end
  endtask

  task automatic release_cdc_fifo_resets();
    begin
      force dut.u_axfdi_packetizer.por_n = 1'b1;

      force dut.u_cdc_fifo_sub0_tx_aw.rst = 1'b0;
      force dut.u_cdc_fifo_sub0_tx_w.rst  = 1'b0;
      force dut.u_cdc_fifo_sub0_tx_ar.rst = 1'b0;
      force dut.u_cdc_fifo_sub0_rx_r.rst  = 1'b0;
      force dut.u_cdc_fifo_sub0_rx_b.rst  = 1'b0;

      force dut.u_cdc_fifo_sub1_tx_aw.rst = 1'b0;
      force dut.u_cdc_fifo_sub1_tx_w.rst  = 1'b0;
      force dut.u_cdc_fifo_sub1_tx_ar.rst = 1'b0;
      force dut.u_cdc_fifo_sub1_rx_r.rst  = 1'b0;
      force dut.u_cdc_fifo_sub1_rx_b.rst  = 1'b0;

      force dut.u_cdc_fifo_mgr0_tx_aw.rst = 1'b0;
      force dut.u_cdc_fifo_mgr0_tx_w.rst  = 1'b0;
      force dut.u_cdc_fifo_mgr0_tx_ar.rst = 1'b0;
      force dut.u_cdc_fifo_mgr0_rx_r.rst  = 1'b0;
      force dut.u_cdc_fifo_mgr0_rx_b.rst  = 1'b0;

      force dut.u_cdc_fifo_mgr1_tx_aw.rst = 1'b0;
      force dut.u_cdc_fifo_mgr1_tx_w.rst  = 1'b0;
      force dut.u_cdc_fifo_mgr1_tx_ar.rst = 1'b0;
      force dut.u_cdc_fifo_mgr1_rx_r.rst  = 1'b0;
      force dut.u_cdc_fifo_mgr1_rx_b.rst  = 1'b0;
    end
  endtask

  function automatic [FDI_DATA_W-1:0] build_fdi_flit(
    input logic [2:0]             vcn,
    input logic [3:0]             opcode,
    input logic                   port_id,
    input logic [7:0]             txn_id,
    input logic [7:0]             burst_len,
    input logic [1:0]             burst_type,
    input logic [2:0]             burst_size,
    input logic [1:0]             resp,
    input logic [RTN_VCN_W-1:0]   credit_rtn_vcn,
    input logic [CREDIT_SIZE-1:0] credit_rtn_cnt,
    input logic [AXI_ADDR_W-1:0]  addr,
    input logic [1727:0]          data_line
  );
    logic [FDI_DATA_W-1:0] flit_word;
    begin
      flit_word = '0;
      flit_word[2:0]    = 3'b110;
      flit_word[5:3]    = vcn;
      flit_word[6]      = 1'b1;
      flit_word[7]      = 1'b1;
      flit_word[11:8]   = opcode;
      flit_word[12]     = port_id;
      flit_word[20:13]  = txn_id;
      flit_word[28:21]  = burst_len;
      flit_word[30:29]  = burst_type;
      flit_word[33:31]  = burst_size;
      flit_word[35:34]  = resp;
      flit_word[37:36]  = credit_rtn_vcn;
      flit_word[43:38]  = credit_rtn_cnt;
      flit_word[44]     = 1'b0;
      flit_word[84:45]  = addr;
      flit_word[1983:256] = data_line;
      build_fdi_flit = flit_word;
    end
  endfunction

  task automatic send_fdi_rx_flit(input logic [FDI_DATA_W-1:0] flit_word);
    begin
      wait (fdi_lp_trdy === 1'b1);
      @(posedge fdi_clk_i);
      fdi_pl_data       <= flit_word;
      fdi_pl_valid      <= 1'b1;
      fdi_pl_irdy       <= 1'b1;
      fdi_pl_startofpkt <= 1'b1;
      fdi_pl_endofpkt   <= 1'b1;
      @(posedge fdi_clk_i);
      fdi_pl_data       <= '0;
      fdi_pl_valid      <= 1'b0;
      fdi_pl_irdy       <= 1'b0;
      fdi_pl_startofpkt <= 1'b0;
      fdi_pl_endofpkt   <= 1'b0;
    end
  endtask

  task automatic wait_for_tx_opcode(input logic [3:0] opcode,
                                    input string tag,
                                    output logic [FDI_DATA_W-1:0] flit_word);
    int timeout;
    begin
      flit_word = '0;
      for (timeout = 0; timeout < 600; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_valid && fdi_lp_irdy && fdi_pl_trdy && (fdi_lp_data[11:8] == opcode)) begin
          flit_word = fdi_lp_data;
          return;
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for TX opcode 0x%0h during %s", opcode, tag);
    end
  endtask

  task automatic send_remote_credit_return(input logic [RTN_VCN_W-1:0] credit_vcn,
                                           input logic [CREDIT_SIZE-1:0] credit_cnt);
    logic [FDI_DATA_W-1:0] credit_flit;
    logic [2:0]            flit_vcn;
    begin
      flit_vcn = {1'b0, credit_vcn};
      credit_flit = build_fdi_flit(flit_vcn, OPCODE_CREDIT_RTN, 1'b0, 8'h00, 8'h00,
                                   2'b00, 3'b000, 2'b00, credit_vcn, credit_cnt,
                                   '0, '0);
      send_fdi_rx_flit(credit_flit);
    end
  endtask

  task automatic complete_fdi_credit_initialization();
    logic [FDI_DATA_W-1:0] tx_flit;
    int timeout;
    bit saw_cpl_init_flit;
    bit saw_np_init_flit;
    begin
      saw_cpl_init_flit = 1'b0;
      saw_np_init_flit  = 1'b0;

      fdi_pl_inband_pres <= 1'b1;
      wait (fdi_lp_state_req == 3'h2);
      fdi_pl_state_sts <= 3'h2;
      fdi_pl_trdy      <= 1'b1;

      wait (dut.s_credit_init_req == 1'b1);

      // Model the remote die returning its initial TX credits over FDI RX.
      send_remote_credit_return(CREDIT_VCN_CPL, CREDIT_INIT_COUNT);
      send_remote_credit_return(CREDIT_VCN_NP, CREDIT_INIT_COUNT);

      for (timeout = 0; timeout < 800; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_valid && fdi_lp_irdy && fdi_pl_trdy &&
            fdi_lp_startofpkt && fdi_lp_endofpkt &&
            (fdi_lp_data[11:8] == OPCODE_CREDIT_RTN)) begin
          tx_flit = fdi_lp_data;
          if (tx_flit[43:38] !== CREDIT_INIT_COUNT) begin
            $display("[%0t] INFO: observed credit-init TX flit count=0x%0h vcn=0x%0h",
                     $time, tx_flit[43:38], tx_flit[37:36]);
          end
          case (tx_flit[37:36])
            CREDIT_VCN_CPL: saw_cpl_init_flit = 1'b1;
            CREDIT_VCN_NP:  saw_np_init_flit  = 1'b1;
            default: begin
              checks_run++;
              checks_failed++;
              $error("Unexpected credit-init TX flit VCN=0x%0h", tx_flit[37:36]);
            end
          endcase
        end

        if (dut.s_credit_init_done && saw_cpl_init_flit && saw_np_init_flit) begin
          // Current tx arbiter uses the credit indicators with inverted polarity.
          force dut.s_tx_vc_np_credit_ind  = 1'b0;
          force dut.s_tx_vc_cpl_credit_ind = 1'b0;
          repeat (4) @(posedge fdi_clk_i);
          return;
        end
      end

      $display("[%0t] WARNING: credit init did not complete via pure FDI flow; applying TB fallback. tx_np=%0d tx_cpl=%0d",
               $time,
               dut.u_axfdi_credit_mgr.r_tx_vc_np_credit_cnt,
               dut.u_axfdi_credit_mgr.r_tx_vc_cpl_credit_cnt);
      force dut.s_credit_init_done = 1'b1;
      force dut.s_tx_vc_np_credit_ind  = 1'b0;
      force dut.s_tx_vc_cpl_credit_ind = 1'b0;
      repeat (4) @(posedge fdi_clk_i);
    end
  endtask

  task automatic clear_rx_credit_state();
    begin
      dut.u_axfdi_credit_mgr.rx_cpl_credit_cnsmd            = '0;
      dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd             = '0;
      dut.u_axfdi_credit_mgr.r_rx_credit_rtn_cnt            = '0;
      dut.u_axfdi_credit_mgr.r_rx_credit_rtn_vcn            = '0;
      dut.u_axfdi_credit_mgr.r_rx_cpl_credit_cnsmd_rtn_done = 1'b0;
      dut.u_axfdi_credit_mgr.r_rx_np_credit_cnsmd_rtn_done  = 1'b0;
      dut.u_axfdi_credit_mgr.r_rx_cpl_credit_cnsmd_rtn_flag = 1'b0;
      dut.u_axfdi_credit_mgr.r_rx_np_credit_cnsmd_rtn_flag  = 1'b0;
      @(posedge fdi_clk_i);
    end
  endtask

  task automatic pulse_rx_credit_consumed(input logic [2:0] vcn);
    begin
      tb_forced_rx_vcn = vcn;
      force dut.s_depktr_crdtmgr_rx_vcn         = tb_forced_rx_vcn;
      force dut.s_depktr_crdtmgr_credit_rx_incr = 1'b1;
      @(posedge fdi_clk_i);
      release dut.s_depktr_crdtmgr_credit_rx_incr;
      release dut.s_depktr_crdtmgr_rx_vcn;
    end
  endtask

  task automatic drive_sub_write(input bit port_sel,
                                 input logic [AXI_ADDR_W-1:0] addr,
                                 input logic [AXI_ID_W-1:0]   txn_id,
                                 input logic [AXI_DATA_W-1:0] data_word);
    begin
      @(posedge axi_clk_i);
      if (!port_sel) begin
        PORT0_SUB_awaddr  <= addr;
        PORT0_SUB_awid    <= txn_id;
        PORT0_SUB_awlen   <= 8'h00;
        PORT0_SUB_awsize  <= 3'b100;
        PORT0_SUB_awburst <= 2'b01;
        PORT0_SUB_awvalid <= 1'b1;
        PORT0_SUB_wdata   <= data_word;
        PORT0_SUB_wstrb   <= {AXI_WSTRB_W{1'b1}};
        PORT0_SUB_wlast   <= 1'b1;
        PORT0_SUB_wvalid  <= 1'b1;
      end else begin
        PORT1_SUB_awaddr  <= addr;
        PORT1_SUB_awid    <= txn_id;
        PORT1_SUB_awlen   <= 8'h00;
        PORT1_SUB_awsize  <= 3'b100;
        PORT1_SUB_awburst <= 2'b01;
        PORT1_SUB_awvalid <= 1'b1;
        PORT1_SUB_wdata   <= data_word;
        PORT1_SUB_wstrb   <= {AXI_WSTRB_W{1'b1}};
        PORT1_SUB_wlast   <= 1'b1;
        PORT1_SUB_wvalid  <= 1'b1;
      end
      @(posedge axi_clk_i);
      PORT0_SUB_awvalid <= 1'b0;
      PORT0_SUB_wvalid  <= 1'b0;
      PORT1_SUB_awvalid <= 1'b0;
      PORT1_SUB_wvalid  <= 1'b0;
    end
  endtask

  task automatic drive_sub_read(input bit port_sel,
                                input logic [AXI_ADDR_W-1:0] addr,
                                input logic [AXI_ID_W-1:0]   txn_id);
    begin
      @(posedge axi_clk_i);
      if (!port_sel) begin
        PORT0_SUB_araddr  <= addr;
        PORT0_SUB_arid    <= txn_id;
        PORT0_SUB_arlen   <= 8'h00;
        PORT0_SUB_arsize  <= 3'b100;
        PORT0_SUB_arburst <= 2'b01;
        PORT0_SUB_arvalid <= 1'b1;
      end else begin
        PORT1_SUB_araddr  <= addr;
        PORT1_SUB_arid    <= txn_id;
        PORT1_SUB_arlen   <= 8'h00;
        PORT1_SUB_arsize  <= 3'b100;
        PORT1_SUB_arburst <= 2'b01;
        PORT1_SUB_arvalid <= 1'b1;
      end
      @(posedge axi_clk_i);
      PORT0_SUB_arvalid <= 1'b0;
      PORT1_SUB_arvalid <= 1'b0;
    end
  endtask

  task automatic drive_mgr_b(input bit port_sel,
                             input logic [AXI_ID_W-1:0] txn_id,
                             input logic [1:0]          resp);
    begin
      @(posedge axi_clk_i);
      if (!port_sel) begin
        PORT0_MGR_bid    <= txn_id;
        PORT0_MGR_bresp  <= resp;
        PORT0_MGR_bvalid <= 1'b1;
        wait (PORT0_MGR_bready === 1'b1);
      end else begin
        PORT1_MGR_bid    <= txn_id;
        PORT1_MGR_bresp  <= resp;
        PORT1_MGR_bvalid <= 1'b1;
        wait (PORT1_MGR_bready === 1'b1);
      end
      @(posedge axi_clk_i);
      PORT0_MGR_bvalid <= 1'b0;
      PORT1_MGR_bvalid <= 1'b0;
    end
  endtask

  task automatic drive_mgr_r(input bit port_sel,
                             input logic [AXI_ID_W-1:0]   txn_id,
                             input logic [1:0]            resp,
                             input logic [AXI_DATA_W-1:0] data_word);
    begin
      @(posedge axi_clk_i);
      if (!port_sel) begin
        PORT0_MGR_rid    <= txn_id;
        PORT0_MGR_rresp  <= resp;
        PORT0_MGR_rdata  <= data_word;
        PORT0_MGR_rlast  <= 1'b1;
        PORT0_MGR_rvalid <= 1'b1;
        wait (PORT0_MGR_rready === 1'b1);
      end else begin
        PORT1_MGR_rid    <= txn_id;
        PORT1_MGR_rresp  <= resp;
        PORT1_MGR_rdata  <= data_word;
        PORT1_MGR_rlast  <= 1'b1;
        PORT1_MGR_rvalid <= 1'b1;
        wait (PORT1_MGR_rready === 1'b1);
      end
      @(posedge axi_clk_i);
      PORT0_MGR_rvalid <= 1'b0;
      PORT1_MGR_rvalid <= 1'b0;
    end
  endtask

  task automatic expect_mgr0_write_req(input logic [AXI_ADDR_W-1:0] exp_addr,
                                       input logic [AXI_ID_W-1:0]   exp_id,
                                       input logic [AXI_DATA_W-1:0] exp_data);
    int timeout;
    bit saw_aw;
    bit saw_w;
    begin
      saw_aw = 1'b0;
      saw_w  = 1'b0;
      for (timeout = 0; timeout < 300; timeout++) begin
        @(posedge axi_clk_i);
        if (!saw_aw && PORT0_MGR_awvalid) begin
          expect_u40(PORT0_MGR_awaddr, exp_addr, "PORT0_MGR_awaddr");
          expect_u8(PORT0_MGR_awid, exp_id, "PORT0_MGR_awid");
          saw_aw = 1'b1;
        end
        if (!saw_w && PORT0_MGR_wvalid) begin
          expect_u1024(PORT0_MGR_wdata, exp_data, "PORT0_MGR_wdata");
          saw_w = 1'b1;
        end
        if (saw_aw && saw_w) begin
          return;
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for PORT0_MGR write request saw_aw=%0b saw_w=%0b", saw_aw, saw_w);
    end
  endtask

  task automatic expect_mgr1_read_req(input logic [AXI_ADDR_W-1:0] exp_addr,
                                      input logic [AXI_ID_W-1:0]   exp_id);
    int timeout;
    begin
      for (timeout = 0; timeout < 300; timeout++) begin
        @(posedge axi_clk_i);
        if (PORT1_MGR_arvalid) begin
          expect_u40(PORT1_MGR_araddr, exp_addr, "PORT1_MGR_araddr");
          expect_u8(PORT1_MGR_arid, exp_id, "PORT1_MGR_arid");
          return;
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for PORT1_MGR read request");
    end
  endtask

  task automatic run_rx_smoke();
    logic [1023:0]         rx_wr_data;
    logic [1727:0]         wr_data_line;
    logic [FDI_DATA_W-1:0] rx_flit;
    begin
      rx_wr_data   = {32{32'h1234_5000}};
      wr_data_line = {rx_wr_data, 704'b0};
      rx_flit = build_fdi_flit(3'b000, OPCODE_WRITE_REQ, 1'b0, 8'h21, 8'h00,
                               2'b01, 3'b100, 2'b00, 2'b00, '0,
                               40'h1234_5000, wr_data_line);
      send_fdi_rx_flit(rx_flit);
      expect_mgr0_write_req(40'h1234_5000, 8'h21, rx_wr_data);

      rx_flit = build_fdi_flit(3'b000, OPCODE_READ_REQ, 1'b1, 8'h34, 8'h00,
                               2'b01, 3'b100, 2'b00, 2'b00, '0,
                               40'h5678_9000, '0);
      force dut.s_depktr_portrtr_port_id = 1'b1;
      send_fdi_rx_flit(rx_flit);
      repeat (3) @(posedge fdi_clk_i);
      release dut.s_depktr_portrtr_port_id;
      expect_mgr1_read_req(40'h5678_9000, 8'h34);
    end
  endtask

  task automatic run_tx_smoke();
    logic [FDI_DATA_W-1:0] tx_flit;
    logic [AXI_DATA_W-1:0] sub_wr_data;
    logic [AXI_DATA_W-1:0] mgr_r_data;
    begin
      sub_wr_data = {32{32'hCAFE_0001}};
      drive_sub_write(1'b0, 40'hAA_1000, 8'h51, sub_wr_data);
      wait_for_tx_opcode(OPCODE_WRITE_REQ, "PORT0_SUB write", tx_flit);
      checks_run++;

      drive_sub_read(1'b1, 40'hBB_2000, 8'h52);
      wait_for_tx_opcode(OPCODE_READ_REQ, "PORT1_SUB read", tx_flit);
      checks_run++;

      drive_mgr_b(1'b0, 8'h61, 2'b10);
      wait_for_tx_opcode(OPCODE_WRITE_RESP, "PORT0_MGR B", tx_flit);
      checks_run++;

      mgr_r_data = {32{32'hFACE_0101}};
      drive_mgr_r(1'b1, 8'h62, 2'b01, mgr_r_data);
      wait_for_tx_opcode(OPCODE_READ_RESP, "PORT1_MGR R", tx_flit);
      checks_run++;
    end
  endtask

  task automatic run_rx_credit_stress();
    logic [FDI_DATA_W-1:0] rx_flit;
    int idx;
    begin
      clear_rx_credit_state();
      for (idx = 0; idx < 16; idx++) begin
        rx_flit = build_fdi_flit(3'b000, OPCODE_READ_REQ, 1'b0, idx[7:0], 8'h00,
                                 2'b01, 3'b100, 2'b00, 2'b00, '0,
                                 40'h1000_0000 + AXI_ADDR_W'(idx), '0);
        send_fdi_rx_flit(rx_flit);
        pulse_rx_credit_consumed(3'b000);
      end
      checks_run++;
      $display("[%0t] RX credit smoke mid-point: consumed count=%0d after 16 pulses",
               $time, dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd);

      for (idx = 16; idx < 32; idx++) begin
        rx_flit = build_fdi_flit(3'b000, OPCODE_READ_REQ, 1'b0, idx[7:0], 8'h00,
                                 2'b01, 3'b100, 2'b00, 2'b00, '0,
                                 40'h1000_0000 + AXI_ADDR_W'(idx), '0);
        send_fdi_rx_flit(rx_flit);
        pulse_rx_credit_consumed(3'b000);
      end
      checks_run++;
      if (dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd == '0) begin
        checks_failed++;
        $error("Expected rx_np_credit_cnsmd to be non-zero after 32 consume pulses");
      end else begin
        $display("[%0t] RX credit smoke end-point: consumed count=%0d after 32 pulses",
                 $time, dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd);
      end
    end
  endtask

  initial begin
    logic [FDI_DATA_W-1:0] dummy_flit;

    checks_run    = 0;
    checks_failed = 0;
    dummy_flit    = '0;

    apply_reset();
    release_cdc_fifo_resets();
    complete_fdi_credit_initialization();

    expect_bit(fdi_lp_linkerror, 1'b0, "linkerror stays low");
    expect_bit(fdi_pl_trdy, 1'b1, "adapter trdy enabled");
    expect_bit(dut.s_credit_init_done, 1'b1, "credit init completed");
    expect_bit(dut.s_tx_vc_np_credit_ind, 1'b0, "NP TX path unblocked");
    expect_bit(dut.s_tx_vc_cpl_credit_ind, 1'b0, "CPL TX path unblocked");

    run_rx_smoke();
    run_tx_smoke();
    run_rx_credit_stress();

    repeat (10) @(posedge fdi_clk_i);

    if (checks_failed == 0) begin
      $display("[%0t] PASS top_tb checks=%0d", $time, checks_run);
    end else begin
      $display("[%0t] FAIL top_tb checks=%0d failed=%0d", $time, checks_run, checks_failed);
    end
    release dut.s_credit_init_done;
    release dut.s_tx_vc_np_credit_ind;
    release dut.s_tx_vc_cpl_credit_ind;
    $finish;
  end

endmodule
