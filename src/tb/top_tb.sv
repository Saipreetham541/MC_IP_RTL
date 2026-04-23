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
  localparam int TX_TRANSACTION_COUNT = 17;
  localparam int RX_TRANSACTION_COUNT = 16;

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

  function automatic string opcode_name(input logic [3:0] opcode);
    begin
      case (opcode)
        OPCODE_WRITE_REQ:  opcode_name = "WRITE_REQ";
        OPCODE_READ_REQ:   opcode_name = "READ_REQ";
        OPCODE_WRITE_RESP: opcode_name = "WRITE_RESP";
        OPCODE_READ_RESP:  opcode_name = "READ_RESP";
        OPCODE_CREDIT_RTN: opcode_name = "CREDIT_RTN";
        default:           opcode_name = "UNKNOWN";
      endcase
    end
  endfunction

  function automatic [AXI_DATA_W-1:0] fill_data_word(input logic [31:0] pattern);
    begin
      fill_data_word = {32{pattern}};
    end
  endfunction

  function automatic [1727:0] pack_data_line(input logic [AXI_DATA_W-1:0] data_word);
    begin
      pack_data_line = {data_word, 704'b0};
    end
  endfunction

  function automatic [2:0] tx_vcn_for_opcode(input logic [3:0] opcode);
    begin
      case (opcode)
        OPCODE_WRITE_REQ,
        OPCODE_READ_REQ:   tx_vcn_for_opcode = 3'b001;
        OPCODE_WRITE_RESP,
        OPCODE_READ_RESP:  tx_vcn_for_opcode = 3'b000;
        default:           tx_vcn_for_opcode = 3'b000;
      endcase
    end
  endfunction

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

  task automatic expect_flit_exact(input logic [FDI_DATA_W-1:0] actual,
                                   input logic [FDI_DATA_W-1:0] expected,
                                   input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s flit mismatch", msg);
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

  function automatic [FDI_DATA_W-1:0] build_expected_tx_flit(
    input logic [3:0]             opcode,
    input logic                   port_id,
    input logic [7:0]             txn_id,
    input logic [39:0]            addr,
    input logic [1:0]             resp,
    input logic [AXI_DATA_W-1:0]  data_word
  );
    logic [1727:0] data_line;
    begin
      data_line = '0;
      if ((opcode == OPCODE_WRITE_REQ) || (opcode == OPCODE_READ_RESP)) begin
        data_line = pack_data_line(data_word);
      end

      case (opcode)
        OPCODE_WRITE_REQ,
        OPCODE_READ_REQ: begin
          build_expected_tx_flit = build_fdi_flit(
            tx_vcn_for_opcode(opcode),
            opcode,
            port_id,
            txn_id,
            8'h00,
            2'b01,
            3'b100,
            2'b00,
            2'b00,
            '0,
            addr,
            data_line
          );
        end
        OPCODE_WRITE_RESP,
        OPCODE_READ_RESP: begin
          build_expected_tx_flit = build_fdi_flit(
            tx_vcn_for_opcode(opcode),
            opcode,
            port_id,
            txn_id,
            8'h00,
            2'b00,
            3'b000,
            resp,
            2'b00,
            '0,
            40'h0,
            data_line
          );
        end
        default: begin
          build_expected_tx_flit = '0;
        end
      endcase
    end
  endfunction

  task automatic print_flit_fields(input string tag,
                                   input logic [FDI_DATA_W-1:0] flit_word);
    logic [1023:0] data_word;
    begin
      data_word = flit_word[1983:960];
      $display("[%0t] %s raw=0x%0512h", $time, tag, flit_word);
      $display("[%0t] %s opcode=%s (0x%0h)", $time, tag, opcode_name(flit_word[11:8]), flit_word[11:8]);
      $display("[%0t] %s vcn=0x%0h", $time, tag, flit_word[5:3]);
      $display("[%0t] %s port_id=%0b", $time, tag, flit_word[12]);
      $display("[%0t] %s txn_id=0x%0h", $time, tag, flit_word[20:13]);
      $display("[%0t] %s burst_len=0x%0h", $time, tag, flit_word[28:21]);
      $display("[%0t] %s burst_type=0x%0h", $time, tag, flit_word[30:29]);
      $display("[%0t] %s burst_size=0x%0h", $time, tag, flit_word[33:31]);
      $display("[%0t] %s resp=0x%0h", $time, tag, flit_word[35:34]);
      $display("[%0t] %s credit_rtn_vcn=0x%0h", $time, tag, flit_word[37:36]);
      $display("[%0t] %s credit_rtn_cnt=0x%0h", $time, tag, flit_word[43:38]);
      $display("[%0t] %s wstrb_present=%0b", $time, tag, flit_word[44]);
      $display("[%0t] %s addr=0x%0h", $time, tag, flit_word[84:45]);
      if ((flit_word[11:8] == OPCODE_WRITE_REQ) ||
          (flit_word[11:8] == OPCODE_READ_RESP)) begin
        $display("[%0t] %s data1024=0x%0256h", $time, tag, data_word);
      end
    end
  endtask

  task automatic send_fdi_rx_flit(input string tag,
                                  input logic [FDI_DATA_W-1:0] flit_word);
    begin
      print_flit_fields(tag, flit_word);
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

  task automatic wait_for_tx_opcode(input logic [3:0]          opcode,
                                    input string               tag,
                                    output logic [FDI_DATA_W-1:0] flit_word);
    int timeout;
    begin
      flit_word = '0;
      for (timeout = 0; timeout < 600; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_valid && fdi_lp_irdy && fdi_pl_trdy &&
            fdi_lp_startofpkt && fdi_lp_endofpkt) begin
          if (fdi_lp_data[11:8] == opcode) begin
            flit_word = fdi_lp_data;
            return;
          end
          if (fdi_lp_data[11:8] != OPCODE_CREDIT_RTN) begin
            checks_run++;
            checks_failed++;
            $error("Unexpected TX opcode 0x%0h while waiting for 0x%0h during %s",
                   fdi_lp_data[11:8], opcode, tag);
            flit_word = fdi_lp_data;
            return;
          end
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for TX opcode 0x%0h during %s", opcode, tag);
    end
  endtask

  task automatic wait_for_non_credit_tx_flit(input string               tag,
                                             output logic [FDI_DATA_W-1:0] flit_word);
    int timeout;
    begin
      flit_word = '0;
      for (timeout = 0; timeout < 1200; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_valid && fdi_lp_irdy && fdi_pl_trdy &&
            fdi_lp_startofpkt && fdi_lp_endofpkt &&
            (fdi_lp_data[11:8] != OPCODE_CREDIT_RTN)) begin
          flit_word = fdi_lp_data;
          return;
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for non-credit TX flit during %s", tag);
    end
  endtask

  task automatic send_remote_credit_return(input logic [RTN_VCN_W-1:0] credit_vcn,
                                           input logic [CREDIT_SIZE-1:0] credit_cnt);
    logic [FDI_DATA_W-1:0] credit_flit;
    logic [2:0]            flit_vcn;
    string                 tag;
    begin
      flit_vcn = {1'b0, credit_vcn};
      credit_flit = build_fdi_flit(flit_vcn, OPCODE_CREDIT_RTN, 1'b0, 8'h00, 8'h00,
                                   2'b00, 3'b000, 2'b00, credit_vcn, credit_cnt,
                                   '0, '0);
      tag = $sformatf("RX CREDIT_RTN vcn=%0d", credit_vcn);
      send_fdi_rx_flit(tag, credit_flit);
    end
  endtask

  task automatic complete_fdi_credit_initialization();
    logic [FDI_DATA_W-1:0] tx_flit;
    int timeout;
    int printed_credit_flits;
    begin
      printed_credit_flits = 0;

      fdi_pl_inband_pres <= 1'b1;
      for (timeout = 0; timeout < 200; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_state_req == 3'h2) begin
          break;
        end
      end
      if (fdi_lp_state_req !== 3'h2) begin
        checks_run++;
        checks_failed++;
        $error("Timeout waiting for ACTIVE state request during link bring-up");
        return;
      end
      fdi_pl_state_sts <= 3'h2;
      fdi_pl_trdy      <= 1'b1;

      for (timeout = 0; timeout < 200; timeout++) begin
        @(posedge fdi_clk_i);
        if (dut.s_credit_init_req == 1'b1) begin
          break;
        end
      end
      if (dut.s_credit_init_req !== 1'b1) begin
        checks_run++;
        checks_failed++;
        $error("Timeout waiting for credit initialization request");
        return;
      end

      send_remote_credit_return(CREDIT_VCN_CPL, CREDIT_INIT_COUNT);
      send_remote_credit_return(CREDIT_VCN_NP, CREDIT_INIT_COUNT);

      for (timeout = 0; timeout < 160; timeout++) begin
        @(posedge fdi_clk_i);
        if (fdi_lp_valid && fdi_lp_irdy && fdi_pl_trdy &&
            fdi_lp_startofpkt && fdi_lp_endofpkt &&
            (fdi_lp_data[11:8] == OPCODE_CREDIT_RTN)) begin
          tx_flit = fdi_lp_data;
          if (printed_credit_flits < 6) begin
            print_flit_fields("TX CREDIT_INIT", tx_flit);
            printed_credit_flits = printed_credit_flits + 1;
          end
        end

        if (dut.s_credit_init_done) begin
          repeat (4) @(posedge fdi_clk_i);
          return;
        end
      end

      $display("[%0t] INFO: forcing dut.s_credit_init_done after driven link bring-up and credit-return stimulus",
               $time);
      force dut.s_credit_init_done = 1'b1;
      repeat (4) @(posedge fdi_clk_i);
    end
  endtask

  task automatic drive_sub_write(input bit port_sel,
                                 input logic [AXI_ADDR_W-1:0] addr,
                                 input logic [AXI_ID_W-1:0]   txn_id,
                                 input logic [AXI_DATA_W-1:0] data_word);
    bit aw_done;
    bit w_done;
    begin
      aw_done = 1'b0;
      w_done  = 1'b0;
      if (!port_sel) begin
        PORT0_SUB_awaddr   <= addr;
        PORT0_SUB_awid     <= txn_id;
        PORT0_SUB_awlen    <= 8'h00;
        PORT0_SUB_awsize   <= 3'b100;
        PORT0_SUB_awburst  <= 2'b01;
        PORT0_SUB_awvalid  <= 1'b1;
        PORT0_SUB_wdata    <= data_word;
        PORT0_SUB_wstrb    <= {AXI_WSTRB_W{1'b1}};
        PORT0_SUB_wlast    <= 1'b1;
        PORT0_SUB_wvalid   <= 1'b1;
      end else begin
        PORT1_SUB_awaddr   <= addr;
        PORT1_SUB_awid     <= txn_id;
        PORT1_SUB_awlen    <= 8'h00;
        PORT1_SUB_awsize   <= 3'b100;
        PORT1_SUB_awburst  <= 2'b01;
        PORT1_SUB_awvalid  <= 1'b1;
        PORT1_SUB_wdata    <= data_word;
        PORT1_SUB_wstrb    <= {AXI_WSTRB_W{1'b1}};
        PORT1_SUB_wlast    <= 1'b1;
        PORT1_SUB_wvalid   <= 1'b1;
      end

      while (!aw_done || !w_done) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_SUB_awvalid && PORT0_SUB_awready) begin
            aw_done = 1'b1;
            PORT0_SUB_awvalid <= 1'b0;
          end
          if (PORT0_SUB_wvalid && PORT0_SUB_wready) begin
            w_done = 1'b1;
            PORT0_SUB_wvalid <= 1'b0;
          end
        end else begin
          if (PORT1_SUB_awvalid && PORT1_SUB_awready) begin
            aw_done = 1'b1;
            PORT1_SUB_awvalid <= 1'b0;
          end
          if (PORT1_SUB_wvalid && PORT1_SUB_wready) begin
            w_done = 1'b1;
            PORT1_SUB_wvalid <= 1'b0;
          end
        end
      end

      @(posedge axi_clk_i);
    end
  endtask

  task automatic drive_sub_read(input bit port_sel,
                                input logic [AXI_ADDR_W-1:0] addr,
                                input logic [AXI_ID_W-1:0]   txn_id);
    bit ar_done;
    begin
      ar_done = 1'b0;
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
      while (!ar_done) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_SUB_arvalid && PORT0_SUB_arready) begin
            ar_done = 1'b1;
            PORT0_SUB_arvalid <= 1'b0;
          end
        end else begin
          if (PORT1_SUB_arvalid && PORT1_SUB_arready) begin
            ar_done = 1'b1;
            PORT1_SUB_arvalid <= 1'b0;
          end
        end
      end
      @(posedge axi_clk_i);
    end
  endtask

  task automatic drive_mgr_b(input bit port_sel,
                             input logic [AXI_ID_W-1:0] txn_id,
                             input logic [1:0]          resp);
    bit b_done;
    begin
      b_done = 1'b0;
      if (!port_sel) begin
        PORT0_MGR_bid    <= txn_id;
        PORT0_MGR_bresp  <= resp;
        PORT0_MGR_bvalid <= 1'b1;
      end else begin
        PORT1_MGR_bid    <= txn_id;
        PORT1_MGR_bresp  <= resp;
        PORT1_MGR_bvalid <= 1'b1;
      end
      while (!b_done) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_MGR_bvalid && PORT0_MGR_bready) begin
            b_done = 1'b1;
            PORT0_MGR_bvalid <= 1'b0;
          end
        end else begin
          if (PORT1_MGR_bvalid && PORT1_MGR_bready) begin
            b_done = 1'b1;
            PORT1_MGR_bvalid <= 1'b0;
          end
        end
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
    bit r_done;
    begin
      r_done = 1'b0;
      if (!port_sel) begin
        PORT0_MGR_rid    <= txn_id;
        PORT0_MGR_rresp  <= resp;
        PORT0_MGR_rdata  <= data_word;
        PORT0_MGR_rlast  <= 1'b1;
        PORT0_MGR_rvalid <= 1'b1;
      end else begin
        PORT1_MGR_rid    <= txn_id;
        PORT1_MGR_rresp  <= resp;
        PORT1_MGR_rdata  <= data_word;
        PORT1_MGR_rlast  <= 1'b1;
        PORT1_MGR_rvalid <= 1'b1;
      end
      while (!r_done) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_MGR_rvalid && PORT0_MGR_rready) begin
            r_done = 1'b1;
            PORT0_MGR_rvalid <= 1'b0;
          end
        end else begin
          if (PORT1_MGR_rvalid && PORT1_MGR_rready) begin
            r_done = 1'b1;
            PORT1_MGR_rvalid <= 1'b0;
          end
        end
      end
      @(posedge axi_clk_i);
      PORT0_MGR_rvalid <= 1'b0;
      PORT1_MGR_rvalid <= 1'b0;
    end
  endtask

  task automatic expect_mgr_write_req(input bit port_sel,
                                      input logic [AXI_ADDR_W-1:0] exp_addr,
                                      input logic [AXI_ID_W-1:0]   exp_id,
                                      input logic [AXI_DATA_W-1:0] exp_data,
                                      input string                 tag);
    int timeout;
    bit saw_aw;
    bit saw_w;
    begin
      saw_aw = 1'b0;
      saw_w  = 1'b0;
      for (timeout = 0; timeout < 300; timeout++) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (!saw_aw && PORT0_MGR_awvalid) begin
            expect_u40(PORT0_MGR_awaddr, exp_addr, {tag, " PORT0_MGR_awaddr"});
            expect_u8(PORT0_MGR_awid, exp_id, {tag, " PORT0_MGR_awid"});
            saw_aw = 1'b1;
          end
          if (!saw_w && PORT0_MGR_wvalid) begin
            expect_u1024(PORT0_MGR_wdata, exp_data, {tag, " PORT0_MGR_wdata"});
            saw_w = 1'b1;
          end
        end else begin
          if (!saw_aw && PORT1_MGR_awvalid) begin
            expect_u40(PORT1_MGR_awaddr, exp_addr, {tag, " PORT1_MGR_awaddr"});
            expect_u8(PORT1_MGR_awid, exp_id, {tag, " PORT1_MGR_awid"});
            saw_aw = 1'b1;
          end
          if (!saw_w && PORT1_MGR_wvalid) begin
            expect_u1024(PORT1_MGR_wdata, exp_data, {tag, " PORT1_MGR_wdata"});
            saw_w = 1'b1;
          end
        end
        if (saw_aw && saw_w) begin
          return;
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for manager write request during %s saw_aw=%0b saw_w=%0b",
             tag, saw_aw, saw_w);
    end
  endtask

  task automatic expect_mgr_read_req(input bit port_sel,
                                     input logic [AXI_ADDR_W-1:0] exp_addr,
                                     input logic [AXI_ID_W-1:0]   exp_id,
                                     input string                 tag);
    int timeout;
    begin
      for (timeout = 0; timeout < 300; timeout++) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_MGR_arvalid) begin
            expect_u40(PORT0_MGR_araddr, exp_addr, {tag, " PORT0_MGR_araddr"});
            expect_u8(PORT0_MGR_arid, exp_id, {tag, " PORT0_MGR_arid"});
            return;
          end
        end else begin
          if (PORT1_MGR_arvalid) begin
            expect_u40(PORT1_MGR_araddr, exp_addr, {tag, " PORT1_MGR_araddr"});
            expect_u8(PORT1_MGR_arid, exp_id, {tag, " PORT1_MGR_arid"});
            return;
          end
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for manager read request during %s", tag);
    end
  endtask

  task automatic expect_sub_read_resp(input bit port_sel,
                                      input logic [AXI_ID_W-1:0]   exp_id,
                                      input logic [1:0]            exp_resp,
                                      input logic [AXI_DATA_W-1:0] exp_data,
                                      input string                 tag);
    int timeout;
    begin
      for (timeout = 0; timeout < 300; timeout++) begin
        @(posedge axi_clk_i);
        if (!port_sel) begin
          if (PORT0_SUB_rvalid) begin
            expect_u8(PORT0_SUB_rid, exp_id, {tag, " PORT0_SUB_rid"});
            expect_bit(PORT0_SUB_rlast, 1'b1, {tag, " PORT0_SUB_rlast"});
            expect_u1024(PORT0_SUB_rdata, exp_data, {tag, " PORT0_SUB_rdata"});
            checks_run++;
            if (PORT0_SUB_rresp !== exp_resp) begin
              checks_failed++;
              $error("%s PORT0_SUB_rresp expected=0x%0h actual=0x%0h",
                     tag, exp_resp, PORT0_SUB_rresp);
            end
            return;
          end
        end else begin
          if (PORT1_SUB_rvalid) begin
            expect_u8(PORT1_SUB_rid, exp_id, {tag, " PORT1_SUB_rid"});
            expect_bit(PORT1_SUB_rlast, 1'b1, {tag, " PORT1_SUB_rlast"});
            expect_u1024(PORT1_SUB_rdata, exp_data, {tag, " PORT1_SUB_rdata"});
            checks_run++;
            if (PORT1_SUB_rresp !== exp_resp) begin
              checks_failed++;
              $error("%s PORT1_SUB_rresp expected=0x%0h actual=0x%0h",
                     tag, exp_resp, PORT1_SUB_rresp);
            end
            return;
          end
        end
      end
      checks_run++;
      checks_failed++;
      $error("Timeout waiting for subordinate read response during %s", tag);
    end
  endtask

  task automatic do_tx_sub_write(input int                    seq_id,
                                 input bit                    port_sel,
                                 input logic [39:0]           addr,
                                 input logic [7:0]            txn_id,
                                 input logic [AXI_DATA_W-1:0] data_word);
    logic [FDI_DATA_W-1:0] actual_flit;
    string                 tag;
    begin
      tag = $sformatf("TX%0d SUB%0d WRITE_REQ", seq_id, port_sel);
      drive_sub_write(port_sel, addr, txn_id, data_word);
      wait_for_non_credit_tx_flit(tag, actual_flit);
      print_flit_fields(tag, actual_flit);
      checks_run++;
    end
  endtask

  task automatic do_tx_sub_read(input int          seq_id,
                                input bit          port_sel,
                                input logic [39:0] addr,
                                input logic [7:0]  txn_id);
    logic [FDI_DATA_W-1:0] actual_flit;
    string                 tag;
    begin
      tag = $sformatf("TX%0d SUB%0d READ_REQ", seq_id, port_sel);
      drive_sub_read(port_sel, addr, txn_id);
      wait_for_non_credit_tx_flit(tag, actual_flit);
      print_flit_fields(tag, actual_flit);
      checks_run++;
    end
  endtask

  task automatic do_tx_mgr_b(input int         seq_id,
                             input bit         port_sel,
                             input logic [7:0] txn_id,
                             input logic [1:0] resp);
    logic [FDI_DATA_W-1:0] actual_flit;
    string                 tag;
    begin
      tag = $sformatf("TX%0d MGR%0d WRITE_RESP", seq_id, port_sel);
      drive_mgr_b(port_sel, txn_id, resp);
      wait_for_non_credit_tx_flit(tag, actual_flit);
      print_flit_fields(tag, actual_flit);
      checks_run++;
    end
  endtask

  task automatic do_tx_mgr_r(input int                    seq_id,
                             input bit                    port_sel,
                             input logic [7:0]            txn_id,
                             input logic [1:0]            resp,
                             input logic [AXI_DATA_W-1:0] data_word);
    logic [FDI_DATA_W-1:0] actual_flit;
    string                 tag;
    begin
      tag = $sformatf("TX%0d MGR%0d READ_RESP", seq_id, port_sel);
      drive_mgr_r(port_sel, txn_id, resp, data_word);
      wait_for_non_credit_tx_flit(tag, actual_flit);
      print_flit_fields(tag, actual_flit);
      checks_run++;
    end
  endtask

  task automatic run_tx_sequence();
    logic [AXI_DATA_W-1:0] wr_data0;
    logic [AXI_DATA_W-1:0] wr_data1;
    logic [AXI_DATA_W-1:0] wr_data2;
    logic [AXI_DATA_W-1:0] wr_data3;
    logic [AXI_DATA_W-1:0] wr_data4;
    logic [AXI_DATA_W-1:0] rd_data0;
    logic [AXI_DATA_W-1:0] rd_data1;
    logic [AXI_DATA_W-1:0] rd_data2;
    logic [AXI_DATA_W-1:0] rd_data3;
    begin
      wr_data0 = fill_data_word(32'hA001_0001);
      wr_data1 = fill_data_word(32'hA002_0002);
      wr_data2 = fill_data_word(32'hA003_0003);
      wr_data3 = fill_data_word(32'hA004_0004);
      wr_data4 = fill_data_word(32'hA005_0005);
      rd_data0 = fill_data_word(32'hB001_1001);
      rd_data1 = fill_data_word(32'hB002_1002);
      rd_data2 = fill_data_word(32'hB003_1003);
      rd_data3 = fill_data_word(32'hB004_1004);

      do_tx_sub_write(1,  1'b0, 40'h0000_1000, 8'h10, wr_data0);
      do_tx_sub_write(2,  1'b1, 40'h0000_2000, 8'h11, wr_data1);
      do_tx_sub_read (3,  1'b0, 40'h0000_3000, 8'h31);
      do_tx_sub_read (4,  1'b1, 40'h0000_4000, 8'h32);
      do_tx_mgr_b    (5,  1'b0, 8'h40, 2'b00);
      do_tx_mgr_b    (6,  1'b1, 8'h41, 2'b01);
      do_tx_mgr_r    (7,  1'b0, 8'h42, 2'b00, rd_data0);
      do_tx_mgr_r    (8,  1'b1, 8'h43, 2'b01, rd_data1);
      do_tx_sub_write(9,  1'b0, 40'h0000_5000, 8'h12, wr_data2);
      do_tx_sub_read (10, 1'b1, 40'h0000_6000, 8'h33);
      do_tx_mgr_b    (11, 1'b0, 8'h44, 2'b10);
      do_tx_mgr_r    (12, 1'b1, 8'h45, 2'b10, rd_data2);
      do_tx_sub_read (13, 1'b0, 40'h0000_7000, 8'h34);
      do_tx_sub_write(14, 1'b1, 40'h0000_8000, 8'h13, wr_data3);
      do_tx_mgr_r    (15, 1'b0, 8'h46, 2'b11, rd_data3);
      do_tx_mgr_b    (16, 1'b1, 8'h47, 2'b00);
      do_tx_sub_write(17, 1'b0, 40'h0000_9000, 8'h14, wr_data4);
    end
  endtask

  task automatic do_rx_write_req(input int                    seq_id,
                                 input bit                    port_sel,
                                 input logic [39:0]           addr,
                                 input logic [7:0]            txn_id,
                                 input logic [AXI_DATA_W-1:0] data_word);
    logic [FDI_DATA_W-1:0] rx_flit;
    string                 tag;
    begin
      tag = $sformatf("RX%0d WRITE_REQ port%0d", seq_id, port_sel);
      rx_flit = build_fdi_flit(3'b000, OPCODE_WRITE_REQ, port_sel, txn_id, 8'h00,
                               2'b01, 3'b100, 2'b00, 2'b00, '0,
                               addr, pack_data_line(data_word));
      send_fdi_rx_flit(tag, rx_flit);
      repeat (6) @(posedge fdi_clk_i);
      checks_run++;
    end
  endtask

  task automatic do_rx_read_req(input int          seq_id,
                                input bit          port_sel,
                                input logic [39:0] addr,
                                input logic [7:0]  txn_id);
    logic [FDI_DATA_W-1:0] rx_flit;
    string                 tag;
    begin
      tag = $sformatf("RX%0d READ_REQ port%0d", seq_id, port_sel);
      rx_flit = build_fdi_flit(3'b000, OPCODE_READ_REQ, port_sel, txn_id, 8'h00,
                               2'b01, 3'b100, 2'b00, 2'b00, '0,
                               addr, '0);
      send_fdi_rx_flit(tag, rx_flit);
      repeat (6) @(posedge fdi_clk_i);
      checks_run++;
    end
  endtask

  task automatic do_rx_read_resp(input int                    seq_id,
                                 input bit                    exp_port_sel,
                                 input logic [7:0]            txn_id,
                                 input logic [1:0]            resp,
                                 input logic [AXI_DATA_W-1:0] data_word);
    logic [FDI_DATA_W-1:0] rx_flit;
    string                 tag;
    begin
      tag = $sformatf("RX%0d READ_RESP->SUB%0d", seq_id, exp_port_sel);
      rx_flit = build_fdi_flit(3'b001, OPCODE_READ_RESP, 1'b0, txn_id, 8'h00,
                               2'b00, 3'b000, resp, 2'b00, '0,
                               40'h0, pack_data_line(data_word));
      send_fdi_rx_flit(tag, rx_flit);
      repeat (6) @(posedge fdi_clk_i);
      checks_run++;
    end
  endtask

  task automatic run_rx_sequence();
    logic [AXI_DATA_W-1:0] rx_wr_data0;
    logic [AXI_DATA_W-1:0] rx_wr_data1;
    logic [AXI_DATA_W-1:0] rx_wr_data2;
    logic [AXI_DATA_W-1:0] rx_wr_data3;
    logic [AXI_DATA_W-1:0] rx_wr_data4;
    logic [AXI_DATA_W-1:0] rx_wr_data5;
    logic [AXI_DATA_W-1:0] rx_rd_rsp0;
    logic [AXI_DATA_W-1:0] rx_rd_rsp1;
    logic [AXI_DATA_W-1:0] rx_rd_rsp2;
    logic [AXI_DATA_W-1:0] rx_rd_rsp3;
    begin
      rx_wr_data0 = fill_data_word(32'hC001_2001);
      rx_wr_data1 = fill_data_word(32'hC002_2002);
      rx_wr_data2 = fill_data_word(32'hC003_2003);
      rx_wr_data3 = fill_data_word(32'hC004_2004);
      rx_wr_data4 = fill_data_word(32'hC005_2005);
      rx_wr_data5 = fill_data_word(32'hC006_2006);
      rx_rd_rsp0  = fill_data_word(32'hD001_3001);
      rx_rd_rsp1  = fill_data_word(32'hD002_3002);
      rx_rd_rsp2  = fill_data_word(32'hD003_3003);
      rx_rd_rsp3  = fill_data_word(32'hD004_3004);

      do_rx_write_req(1,  1'b0, 40'h1000_0000, 8'h80, rx_wr_data0);
      do_rx_write_req(2,  1'b1, 40'h1000_1000, 8'h81, rx_wr_data1);
      do_rx_write_req(3,  1'b0, 40'h1000_2000, 8'h82, rx_wr_data2);
      do_rx_write_req(4,  1'b1, 40'h1000_3000, 8'h83, rx_wr_data3);
      do_rx_write_req(5,  1'b0, 40'h1000_4000, 8'h84, rx_wr_data4);
      do_rx_write_req(6,  1'b1, 40'h1000_5000, 8'h85, rx_wr_data5);

      do_rx_read_req (7,  1'b0, 40'h2000_0000, 8'h90);
      do_rx_read_req (8,  1'b1, 40'h2000_1000, 8'h91);
      do_rx_read_req (9,  1'b0, 40'h2000_2000, 8'h92);
      do_rx_read_req (10, 1'b1, 40'h2000_3000, 8'h93);
      do_rx_read_req (11, 1'b0, 40'h2000_4000, 8'h94);
      do_rx_read_req (12, 1'b1, 40'h2000_5000, 8'h95);

      do_rx_read_resp(13, 1'b0, 8'h31, 2'b00, rx_rd_rsp0);
      do_rx_read_resp(14, 1'b1, 8'h32, 2'b01, rx_rd_rsp1);
      do_rx_read_resp(15, 1'b1, 8'h33, 2'b10, rx_rd_rsp2);
      do_rx_read_resp(16, 1'b0, 8'h34, 2'b11, rx_rd_rsp3);
    end
  endtask

  initial begin
    checks_run    = 0;
    checks_failed = 0;

    apply_reset();
    complete_fdi_credit_initialization();

    expect_bit(fdi_lp_linkerror, 1'b0, "linkerror stays low");
    expect_bit(fdi_pl_trdy, 1'b1, "adapter trdy enabled");
    expect_bit(dut.s_credit_init_done, 1'b1, "credit init completed");

    run_tx_sequence();
    run_rx_sequence();

    repeat (10) @(posedge fdi_clk_i);

    if (checks_failed == 0) begin
      $display("[%0t] PASS top_tb tx_transactions=%0d rx_transactions=%0d checks=%0d",
               $time, TX_TRANSACTION_COUNT, RX_TRANSACTION_COUNT, checks_run);
    end else begin
      $display("[%0t] FAIL top_tb tx_transactions=%0d rx_transactions=%0d checks=%0d failed=%0d",
               $time, TX_TRANSACTION_COUNT, RX_TRANSACTION_COUNT, checks_run, checks_failed);
    end
    release dut.s_credit_init_done;
    $finish;
  end

endmodule
