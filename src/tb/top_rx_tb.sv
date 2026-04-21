`timescale 1ns/1ps

module top_rx_tb;

  localparam int AXI_ADDR_W   = 40;
  localparam int AXI_ID_W     = 8;
  localparam int AXI_LEN_W    = 8;
  localparam int AXI_SIZE_W   = 3;
  localparam int AXI_BURST_W  = 2;
  localparam int AXI_DATA_W   = 1024;
  localparam int AXI_WSTRB_W  = 128;
  localparam int AXI_RESP_W   = 2;
  localparam int FDI_DATA_W   = 2048;
  localparam int FDI_STATUS_W = 3;
  localparam int CDC_AW_D_W   = 61;
  localparam int CDC_W_D_W    = 1153;
  localparam int CDC_AR_D_W   = 61;
  localparam int CDC_B_D_W    = 10;
  localparam int CDC_R_D_W    = 1035;
  localparam int CREDIT_SIZE  = 6;
  localparam int RTN_VCN_W    = 2;
  localparam int VCN_W        = 3;

  logic                     fdi_clk_i;
  logic                     por_n_i;
  logic                     fdi_rst_n_i;

  logic [FDI_DATA_W-1:0]    fdi_lp_data;
  logic                     fdi_lp_valid;
  logic                     fdi_lp_irdy;
  logic                     fdi_lp_startofpkt;
  logic                     fdi_lp_endofpkt;
  logic                     fdi_pl_trdy;
  logic [FDI_STATUS_W-1:0]  fdi_lp_state_req;
  logic                     fdi_lp_linkerror;

  logic [FDI_DATA_W-1:0]    fdi_pl_data;
  logic                     fdi_pl_valid;
  logic                     fdi_pl_irdy;
  logic                     fdi_pl_startofpkt;
  logic                     fdi_pl_endofpkt;
  logic                     fdi_lp_trdy;
  logic [FDI_STATUS_W-1:0]  fdi_pl_state_sts;
  logic                     fdi_pl_inband_pres;

  logic [CDC_AW_D_W-1:0]    port0_cdc_aw_d;
  logic                     port0_cdc_aw_d_wr_en;
  logic                     port0_cdc_aw_d_full;
  logic [CDC_W_D_W-1:0]     port0_cdc_w_d;
  logic                     port0_cdc_w_d_wr_en;
  logic                     port0_cdc_w_d_full;
  logic [CDC_AR_D_W-1:0]    port0_cdc_ar_d;
  logic                     port0_cdc_ar_d_wr_en;
  logic                     port0_cdc_ar_d_full;
  logic [CDC_B_D_W-1:0]     port0_cdc_b_d;
  logic                     port0_cdc_b_d_wr_en;
  logic                     port0_cdc_b_d_full;
  logic [CDC_R_D_W-1:0]     port0_cdc_r_d;
  logic                     port0_cdc_r_d_wr_en;
  logic                     port0_cdc_r_d_full;

  logic [CDC_AW_D_W-1:0]    port1_cdc_aw_d;
  logic                     port1_cdc_aw_d_wr_en;
  logic                     port1_cdc_aw_d_full;
  logic [CDC_W_D_W-1:0]     port1_cdc_w_d;
  logic                     port1_cdc_w_d_wr_en;
  logic                     port1_cdc_w_d_full;
  logic [CDC_AR_D_W-1:0]    port1_cdc_ar_d;
  logic                     port1_cdc_ar_d_wr_en;
  logic                     port1_cdc_ar_d_full;
  logic [CDC_B_D_W-1:0]     port1_cdc_b_d;
  logic                     port1_cdc_b_d_wr_en;
  logic                     port1_cdc_b_d_full;
  logic [CDC_R_D_W-1:0]     port1_cdc_r_d;
  logic                     port1_cdc_r_d_wr_en;
  logic                     port1_cdc_r_d_full;

  logic                     tx_vc_cpl_credit_ind;
  logic                     tx_vc_np_credit_ind;

  int unsigned              checks_run;
  int unsigned              checks_failed;

  top_rx dut (
    .fdi_clk_i            (fdi_clk_i),
    .por_n_i              (por_n_i),
    .fdi_rst_n_i          (fdi_rst_n_i),
    .fdi_lp_data          (fdi_lp_data),
    .fdi_lp_valid         (fdi_lp_valid),
    .fdi_lp_irdy          (fdi_lp_irdy),
    .fdi_lp_startofpkt    (fdi_lp_startofpkt),
    .fdi_lp_endofpkt      (fdi_lp_endofpkt),
    .fdi_pl_trdy          (fdi_pl_trdy),
    .fdi_lp_state_req     (fdi_lp_state_req),
    .fdi_lp_linkerror     (fdi_lp_linkerror),
    .fdi_pl_data          (fdi_pl_data),
    .fdi_pl_valid         (fdi_pl_valid),
    .fdi_pl_irdy          (fdi_pl_irdy),
    .fdi_pl_startofpkt    (fdi_pl_startofpkt),
    .fdi_pl_endofpkt      (fdi_pl_endofpkt),
    .fdi_lp_trdy          (fdi_lp_trdy),
    .fdi_pl_state_sts     (fdi_pl_state_sts),
    .fdi_pl_inband_pres   (fdi_pl_inband_pres),
    .port0_cdc_aw_d       (port0_cdc_aw_d),
    .port0_cdc_aw_d_wr_en (port0_cdc_aw_d_wr_en),
    .port0_cdc_aw_d_full  (port0_cdc_aw_d_full),
    .port0_cdc_w_d        (port0_cdc_w_d),
    .port0_cdc_w_d_wr_en  (port0_cdc_w_d_wr_en),
    .port0_cdc_w_d_full   (port0_cdc_w_d_full),
    .port0_cdc_ar_d       (port0_cdc_ar_d),
    .port0_cdc_ar_d_wr_en (port0_cdc_ar_d_wr_en),
    .port0_cdc_ar_d_full  (port0_cdc_ar_d_full),
    .port0_cdc_b_d        (port0_cdc_b_d),
    .port0_cdc_b_d_wr_en  (port0_cdc_b_d_wr_en),
    .port0_cdc_b_d_full   (port0_cdc_b_d_full),
    .port0_cdc_r_d        (port0_cdc_r_d),
    .port0_cdc_r_d_wr_en  (port0_cdc_r_d_wr_en),
    .port0_cdc_r_d_full   (port0_cdc_r_d_full),
    .port1_cdc_aw_d       (port1_cdc_aw_d),
    .port1_cdc_aw_d_wr_en (port1_cdc_aw_d_wr_en),
    .port1_cdc_aw_d_full  (port1_cdc_aw_d_full),
    .port1_cdc_w_d        (port1_cdc_w_d),
    .port1_cdc_w_d_wr_en  (port1_cdc_w_d_wr_en),
    .port1_cdc_w_d_full   (port1_cdc_w_d_full),
    .port1_cdc_ar_d       (port1_cdc_ar_d),
    .port1_cdc_ar_d_wr_en (port1_cdc_ar_d_wr_en),
    .port1_cdc_ar_d_full  (port1_cdc_ar_d_full),
    .port1_cdc_b_d        (port1_cdc_b_d),
    .port1_cdc_b_d_wr_en  (port1_cdc_b_d_wr_en),
    .port1_cdc_b_d_full   (port1_cdc_b_d_full),
    .port1_cdc_r_d        (port1_cdc_r_d),
    .port1_cdc_r_d_wr_en  (port1_cdc_r_d_wr_en),
    .port1_cdc_r_d_full   (port1_cdc_r_d_full),
    .tx_vc_cpl_credit_ind (tx_vc_cpl_credit_ind),
    .tx_vc_np_credit_ind  (tx_vc_np_credit_ind)
  );

  initial fdi_clk_i = 1'b0;
  always #5 fdi_clk_i = ~fdi_clk_i;

  task automatic drive_defaults();
    por_n_i             = 1'b0;
    fdi_rst_n_i         = 1'b0;
    fdi_pl_trdy         = 1'b0;
    fdi_pl_data         = '0;
    fdi_pl_valid        = 1'b0;
    fdi_pl_irdy         = 1'b0;
    fdi_pl_startofpkt   = 1'b0;
    fdi_pl_endofpkt     = 1'b0;
    fdi_pl_state_sts    = '0;
    fdi_pl_inband_pres  = 1'b0;
    port0_cdc_aw_d_full = 1'b0;
    port0_cdc_w_d_full  = 1'b0;
    port0_cdc_ar_d_full = 1'b0;
    port0_cdc_b_d_full  = 1'b0;
    port0_cdc_r_d_full  = 1'b0;
    port1_cdc_aw_d_full = 1'b0;
    port1_cdc_w_d_full  = 1'b0;
    port1_cdc_ar_d_full = 1'b0;
    port1_cdc_b_d_full  = 1'b0;
    port1_cdc_r_d_full  = 1'b0;
  endtask

  task automatic force_absent_tx_path_idle();
    force dut.s_flit_tx_data             = '0;
    force dut.s_flit_tx_data_valid       = 1'b0;
    force dut.s_fdi_pktr_tx_sop          = 1'b0;
    force dut.s_fdi_pktr_tx_eop          = 1'b0;
    force dut.s_pending_tx_available     = 1'b0;
    force dut.s_credit_rtn_done          = 1'b0;
    force dut.s_tx_credit_vcn            = '0;
    force dut.s_tx_credit_decr_flag      = 1'b0;
    force dut.s_pktr_cmpltkr_tx_vcn      = 1'b0;
    force dut.s_pktr_cmpltkr_tx_txn_id   = '0;
    force dut.s_pktr_cmpltkr_tx_port_id  = 1'b0;
    force dut.s_pktr_cmpltkr_tx_write_done = 1'b0;
    force dut.s_pktr_cmpltkr_tx_txn_valid  = 1'b0;
    force dut.s_portrtr_depktr_read_done = 1'b0;
  endtask

  task automatic sanitize_internal_state();
    dut.u_axfdi_credit_mgr.rx_cpl_credit_cnsmd            = '0;
    dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd             = '0;
    dut.u_axfdi_credit_mgr.r_rx_cpl_credit_init           = '0;
    dut.u_axfdi_credit_mgr.r_rx_np_credit_init            = '0;
    dut.u_axfdi_credit_mgr.r_rx_cpl_credit_init_en        = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_np_credit_init_en         = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_cpl_credit_init_done      = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_np_credit_init_done       = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_credit_rtn_cnt            = '0;
    dut.u_axfdi_credit_mgr.r_rx_credit_rtn_vcn            = '0;
    dut.u_axfdi_credit_mgr.r_rx_cpl_credit_cnsmd_rtn_done = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_np_credit_cnsmd_rtn_done  = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_cpl_credit_cnsmd_rtn_flag = 1'b0;
    dut.u_axfdi_credit_mgr.r_rx_np_credit_cnsmd_rtn_flag  = 1'b0;
    @(posedge fdi_clk_i);
  endtask

  task automatic apply_reset();
    drive_defaults();
    force_absent_tx_path_idle();
    repeat (3) @(posedge fdi_clk_i);
    por_n_i = 1'b1;
    repeat (2) @(posedge fdi_clk_i);
    fdi_rst_n_i = 1'b1;
    @(posedge fdi_clk_i);
    sanitize_internal_state();
  endtask

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

  task automatic expect_vec6(input logic [5:0] actual,
                             input logic [5:0] expected,
                             input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_vec128(input logic [127:0] actual,
                               input logic [127:0] expected,
                               input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%032h actual=0x%032h", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_vec40(input logic [39:0] actual,
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

  function automatic [FDI_DATA_W-1:0] build_fdi_flit(
    input logic [2:0]             vcn,
    input logic [3:0]             opcode,
    input logic                   port_id,
    input logic [7:0]             txn_id,
    input logic [7:0]             burst_len,
    input logic [1:0]             burst_type,
    input logic [2:0]             burst_size,
    input logic [1:0]             resp,
    input logic [1:0]             credit_rtn_vcn,
    input logic [5:0]             credit_rtn_cnt,
    input logic                   wstrb_present,
    input logic [39:0]            addr,
    input logic [127:0]           wstrb,
    input logic [1727:0]          data_line
  );
    logic [FDI_DATA_W-1:0] flit_word;
    begin
      flit_word = '0;
      flit_word[2:0]      = 3'b110;
      flit_word[5:3]      = vcn;
      flit_word[6]        = 1'b1;
      flit_word[7]        = 1'b1;
      flit_word[11:8]     = opcode;
      flit_word[12]       = port_id;
      flit_word[20:13]    = txn_id;
      flit_word[28:21]    = burst_len;
      flit_word[30:29]    = burst_type;
      flit_word[33:31]    = burst_size;
      flit_word[35:34]    = resp;
      flit_word[37:36]    = credit_rtn_vcn;
      flit_word[43:38]    = credit_rtn_cnt;
      flit_word[44]       = wstrb_present;
      flit_word[84:45]    = addr;
      flit_word[255:128]  = wstrb;
      flit_word[1983:256] = data_line;
      build_fdi_flit = flit_word;
    end
  endfunction

  task automatic send_rx_flit(input logic [FDI_DATA_W-1:0] flit_word);
    begin
      fdi_pl_data       = flit_word;
      fdi_pl_valid      = 1'b1;
      fdi_pl_irdy       = 1'b1;
      fdi_pl_startofpkt = 1'b1;
      fdi_pl_endofpkt   = 1'b1;
      @(posedge fdi_clk_i);
      fdi_pl_valid      = 1'b0;
      fdi_pl_irdy       = 1'b0;
      fdi_pl_startofpkt = 1'b0;
      fdi_pl_endofpkt   = 1'b0;
      fdi_pl_data       = '0;
      repeat (2) @(posedge fdi_clk_i);
    end
  endtask

  task automatic bring_link_up_to_credit_init();
    begin
      fdi_pl_inband_pres = 1'b1;
      @(posedge fdi_clk_i);
      wait (fdi_lp_state_req == 3'h2);
      fdi_pl_state_sts = 3'h2;
      fdi_pl_trdy      = 1'b1;
      repeat (2) @(posedge fdi_clk_i);
    end
  endtask

  task automatic force_txrx_mode();
    begin
      force dut.s_credit_init_done = 1'b1;
      repeat (2) @(posedge fdi_clk_i);
      release dut.s_credit_init_done;
      repeat (2) @(posedge fdi_clk_i);
    end
  endtask

  task automatic pulse_router_read_done();
    begin
      force dut.s_portrtr_depktr_read_done = 1'b1;
      @(posedge fdi_clk_i);
      force dut.s_portrtr_depktr_read_done = 1'b0;
      @(posedge fdi_clk_i);
    end
  endtask

  task automatic clear_completion_tracker();
    begin
      for (int idx = 0; idx < dut.u_axfdi_completion_tracker.tracker_depth; idx++) begin
        dut.u_axfdi_completion_tracker.completion_tracker[idx].port_id    = 1'b0;
        dut.u_axfdi_completion_tracker.completion_tracker[idx].vcn        = 1'b0;
        dut.u_axfdi_completion_tracker.completion_tracker[idx].txn_id     = '0;
        dut.u_axfdi_completion_tracker.completion_tracker[idx].data_valid = 1'b0;
      end
    end
  endtask

  task automatic seed_completion_entry(input int unsigned idx,
                                       input logic port_id,
                                       input logic vcn,
                                       input logic [AXI_ID_W-1:0] txn_id);
    begin
      dut.u_axfdi_completion_tracker.completion_tracker[idx].port_id    = port_id;
      dut.u_axfdi_completion_tracker.completion_tracker[idx].vcn        = vcn;
      dut.u_axfdi_completion_tracker.completion_tracker[idx].txn_id     = txn_id;
      dut.u_axfdi_completion_tracker.completion_tracker[idx].data_valid = 1'b1;
    end
  endtask

  task automatic run_single_sequence();
    logic [1023:0]      wr_payload_ok;
    logic [1023:0]      wr_payload_bug;
    logic [1023:0]      rsp_payload;
    logic [1727:0]      wr_data_ok;
    logic [1727:0]      wr_data_bug;
    logic [1727:0]      rsp_data;
    logic [FDI_DATA_W-1:0] credit_flit;
    logic [FDI_DATA_W-1:0] wr_flit_ok;
    logic [FDI_DATA_W-1:0] rd_flit_bug;
    logic [FDI_DATA_W-1:0] wr_flit_bug;
    logic [FDI_DATA_W-1:0] rd_flit_credit;
    logic [FDI_DATA_W-1:0] rsp_flit;
    logic [127:0]          exp_wstrb;
    begin
      $display("[%0t] Single-sequence RX top test", $time);
      apply_reset();
      bring_link_up_to_credit_init();

      $display("[%0t] Phase 1: credit init bring-up", $time);
      expect_bit(dut.s_credit_init_req, 1'b1, "FDI IF should request credit initialization");
      expect_bit(fdi_lp_valid, 1'b1, "SPEC BUG: credit initialization should drive an LP flit");

      force_txrx_mode();
      expect_bit(dut.u_axfdi_fdi_if.CS == dut.u_axfdi_fdi_if.ST_TX_RX, 1'b1,
                 "Top should enter TX_RX after forced credit-init completion");

      $display("[%0t] Phase 2: incoming CREDIT_RTN updates TX credit", $time);

      credit_flit = build_fdi_flit(
        3'h0, 4'h4, 1'b0, 8'h00, 8'h00, 2'b00, 3'b000, 2'b00,
        2'h0, 6'd5, 1'b0, 40'h0, '0, '0
      );
      send_rx_flit(credit_flit);

      expect_vec6(dut.u_axfdi_credit_mgr.r_tx_vc_np_credit_cnt, 6'd5,
                  "Incoming CREDIT_RTN flit should add NP TX credits");

      $display("[%0t] Phase 3: valid one-beat WRITE_REQ to port0", $time);
      wr_payload_ok             = '0;
      wr_payload_ok[31:0]       = 32'h89AB_CDEF;
      wr_payload_ok[63:32]      = 32'h0123_4567;
      wr_data_ok                = '0;
      wr_data_ok[1727:704]      = wr_payload_ok;
      wr_flit_ok = build_fdi_flit(
        3'h0, 4'h0, 1'b0, 8'h21, 8'h00, 2'b01, 3'b100, 2'b00,
        2'h0, 6'd0, 1'b0, 40'h12_3456_789A, 128'h0, wr_data_ok
      );
      send_rx_flit(wr_flit_ok);

      expect_bit(port0_cdc_aw_d_wr_en, 1'b1, "Port0 AW CDC write-enable should pulse for WRITE_REQ");
      expect_bit(port0_cdc_w_d_wr_en, 1'b1, "Port0 W CDC write-enable should pulse for WRITE_REQ");
      expect_vec40(port0_cdc_aw_d[39:0], 40'h12_3456_789A, "Port0 AW payload should carry AXI address");

      $display("[%0t] Phase 4: READ_REQ port1 routing bug", $time);
      rd_flit_bug = build_fdi_flit(
        3'h0, 4'h1, 1'b1, 8'h33, 8'h00, 2'b01, 3'b100, 2'b00,
        2'h0, 6'd0, 1'b0, 40'h00_0000_4444, 128'h0, '0
      );
      send_rx_flit(rd_flit_bug);

      expect_bit(port1_cdc_ar_d_wr_en, 1'b1,
                 "SPEC BUG: READ_REQ with PORT_ID=1 should target port1 AR CDC");

      $display("[%0t] Phase 5: WRITE_REQ WSTRB_PRESENT bug", $time);
      wr_payload_bug             = '0;
      wr_payload_bug[31:0]       = 32'hDEAD_BEEF;
      wr_data_bug                = '0;
      wr_data_bug[1727:704]      = wr_payload_bug;
      exp_wstrb           = 128'hF0F0_0F0F_AAAA_5555_1234_5678_9ABC_DEF0;

      wr_flit_bug = build_fdi_flit(
        3'h0, 4'h0, 1'b0, 8'h44, 8'h00, 2'b01, 3'b100, 2'b00,
        2'h0, 6'd0, 1'b1, 40'h55, exp_wstrb, wr_data_bug
      );
      send_rx_flit(wr_flit_bug);

      expect_vec128(port0_cdc_w_d[128:1], exp_wstrb,
                    "SPEC BUG: port0 W CDC WSTRB should match incoming header WSTRB");

      $display("[%0t] Phase 6: RX credit-consume timing", $time);
      rd_flit_credit = build_fdi_flit(
        3'h0, 4'h1, 1'b0, 8'h52, 8'h00, 2'b01, 3'b100, 2'b00,
        2'h0, 6'd0, 1'b0, 40'hAA, 128'h0, '0
      );
      send_rx_flit(rd_flit_credit);

      expect_vec6(dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd, 6'd1,
                  "SPEC BUG: RX credit-consumed counter should increment when packet is received");

      pulse_router_read_done();
      expect_vec6(dut.u_axfdi_credit_mgr.rx_np_credit_cnsmd, 6'd1,
                  "Current RTL increments RX consumed credit only after read_done");

      $display("[%0t] Phase 7: READ_RESP completion-tracker routing", $time);
      clear_completion_tracker();
      seed_completion_entry(0, 1'b1, 1'b1, 8'h77);

      rsp_payload             = '0;
      rsp_payload[31:0]       = 32'hCAFE_BABE;
      rsp_data                = '0;
      rsp_data[1727:704]      = rsp_payload;

      rsp_flit = build_fdi_flit(
        3'h1, 4'h3, 1'b0, 8'h77, 8'h00, 2'b01, 3'b100, 2'b00,
        2'h0, 6'd0, 1'b0, 40'h0, 128'h0, rsp_data
      );
      send_rx_flit(rsp_flit);

      expect_bit(port1_cdc_r_d_wr_en, 1'b1,
                 "SPEC BUG: READ_RESP should be routed using completion-tracker port_id");
    end
  endtask

  initial begin
    checks_run    = 0;
    checks_failed = 0;

    run_single_sequence();

    repeat (4) @(posedge fdi_clk_i);
    $display("[%0t] top_rx TB completed: checks_run=%0d checks_failed=%0d",
             $time, checks_run, checks_failed);
    if (checks_failed != 0) begin
      $fatal(1, "top_rx_tb detected %0d failing checks", checks_failed);
    end
    $finish;
  end

endmodule
