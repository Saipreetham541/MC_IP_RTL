module axfdi_bridge #(
 parameter axi_addr_w = 40,
 parameter axi_id_w = 8,
 parameter axi_len_w = 8,
 parameter axi_size_w = 3,
 parameter axi_burst_w = 2,
 parameter axi_data_w = 1024,
 parameter axi_wstrb_w = 128,
 parameter axi_resp_w = 2,
 parameter fdi_data_w = 2048,
 parameter fdi_status_w = 3
)(
  //clock and reset logic
  input logic                     fdi_clk_i,
  input logic                     axi_clk_i,
  input logic                     por_n_i,
  input logic                     axi_rst_n_i,
  input logic                     fdi_rst_n_i,

  //port 0 AXI SUB 0 signals
  //write address signals
  input logic [axi_addr_w-1:0]    PORT0_SUB0_awaddr,
  input logic [axi_id_w-1:0]      PORT0_SUB0_awid,
  input logic [axi_len_w-1:0]     PORT0_SUB0_awlen,
  input logic [axi_size_w-1:0]    PORT0_SUB0_awsize,
  input logic [axi_burst_w-1:0]   PORT0_SUB0_awburst,
  input logic                     PORT0_SUB0_awvalid,
  output logic                    PORT0_SUB0_awread,
  //write data signals
  input logic [axi_data_w-1:0]    PORT0_SUB0_wdata,
  input logic [axi_wstrb_w-1:0]   PORT0_SUB0_wstrb,
  output logic                    PORT0_SUB0_wlast,
  input logic                     PORT0_SUB0_wvalid,
  output logic                    PORT0_SUB0_wready,
  //write response signals
  output logic [axi_id_w-1:0]     PORT0_SUB0_bid ,
  output logic [axi_resp_w-1:0]   PORT0_SUB0_bresp,
  output logic                    PORT0_SUB0_bvalid,
  input logic                     PORT0_SUB0_bready,
  //read address signals
  input logic [axi_addr_w-1:0]    PORT0_SUB0_araddr,
  input logic [axi_id_w-1:0]      PORT0_SUB0_arid,
  input logic [axi_len_w-1:0]     PORT0_SUB0_arlen,
  input logic [axi_size_w-1:0]    PORT0_SUB0_arsize,
  input logic [axi_burst_w-1:0]   PORT0_SUB0_arburst,
  input logic                     PORT0_SUB0_arvalid,
  output logic                    PORT0_SUB0_arready,
  //read data signals
  output logic [axi_data_w-1:0]   PORT0_SUB0_rdata,
  output logic [axi_id_w-1:0]     PORT0_SUB0_rid,
  output logic [axi_resp_w-1:0]   PORT0_SUB0_rresp,
  output logic                    PORT0_SUB0_rlast,
  output logic                    PORT0_SUB0_rvalid,
  input logic                     PORT0_SUB0_rready,
  //port 1 AXI  SUB1 signals
  //write address signals
  input logic [axi_addr_w-1:0]    PORT1_SUB1_awaddr,
  input logic [axi_id_w-1:0]      PORT1_SUB1_awid,
  input logic [axi_len_w-1:0]     PORT1_SUB1_awlen,
  input logic [axi_size_w-1:0]    PORT1_SUB1_awsize,
  input logic [axi_burst_w-1:0]   PORT1_SUB1_awburst,
  input logic                     PORT1_SUB1_awvalid,
  output logic                    PORT1_SUB1_awread,
  //write data signals
  input logic [axi_data_w-1:0]    PORT1_SUB1_wdata,
  input logic [axi_wstrb_w-1:0]   PORT1_SUB1_wstrb,
  output logic                    PORT1_SUB1_wlast,
  input logic                     PORT1_SUB1_wvalid,
  output logic                    PORT1_SUB1_wready,
  //write response signals
  output logic [axi_id_w-1:0]     PORT1_SUB1_bid ,
  output logic [axi_resp_w-1:0]   PORT1_SUB1_bresp,
  output logic                    PORT1_SUB1_bvalid,
  input logic                     PORT1_SUB1_bready,
  //read address signals
  input logic [axi_addr_w-1:0]    PORT1_SUB1_araddr,
  input logic [axi_id_w-1:0]      PORT1_SUB1_arid,
  input logic [axi_len_w-1:0]     PORT1_SUB1_arlen,
  input logic [axi_size_w-1:0]    PORT1_SUB1_arsize,
  input logic [axi_burst_w-1:0]   PORT1_SUB1_arburst,
  input logic                     PORT1_SUB1_arvalid,
  output logic                    PORT1_SUB1_arready,
  //read data signals
  output logic [axi_data_w-1:0]   PORT1_SUB1_rdata,
  output logic [axi_id_w-1:0]     PORT1_SUB1_rid,
  output logic [axi_resp_w-1:0]   PORT1_SUB1_rresp,
  output logic                    PORT1_SUB1_rlast,
  output logic                    PORT1_SUB1_rvalid,
  input logic                     PORT1_SUB1_rready,
  //port 0 AXI MGR 0 signals
  //write address signals
  output logic [axi_addr_w-1:0]   PORT0_MGR0_awaddr,
  output logic [axi_id_w-1:0]     PORT0_MGR0_awid,
  output logic [axi_len_w-1:0]    PORT0_MGR0_awlen,
  output logic [axi_size_w-1:0]   PORT0_MGR0_awsize,
  output logic [axi_burst_w-1:0]  PORT0_MGR0_awburst,
  output logic                    PORT0_MGR0_awvalid,
  input logic                     PORT0_MGR0_awready,
  //write data signals
  output logic [axi_data_w-1:0]   PORT0_MGR0_wdata,
  output logic [axi_wstrb_w-1:0]  PORT0_MGR0_wstrb,
  input logic                     PORT0_MGR0_wlast,
  output logic                    PORT0_MGR0_wvalid,
  input logic                     PORT0_MGR0_wready,
  //write response signals
  input logic [axi_id_w-1:0]      PORT0_MGR0_bid ,
  input logic [axi_resp_w-1:0]    PORT0_MGR0_bresp,
  input logic                     PORT0_MGR0_bvalid,
  output logic                    PORT0_MGR0_bready,
  //read address signals
  output logic [axi_addr_w-1:0]   PORT0_MGR0_araddr,
  output logic [axi_id_w-1:0]     PORT0_MGR0_arid,
  output logic [axi_len_w-1:0]    PORT0_MGR0_arlen,
  output logic [axi_size_w-1:0]   PORT0_MGR0_arsize,
  output logic [axi_burst_w-1:0]  PORT0_MGR0_arburst,
  output logic                    PORT0_MGR0_arvalid,
  input logic                     PORT0_MGR0_arready,
  //read data signals
  input logic [axi_data_w-1:0]    PORT0_MGR0_rdata,
  input logic [axi_id_w-1:0]      PORT0_MGR0_rid,
  input logic [axi_resp_w-1:0]    PORT0_MGR0_rresp,
  input logic                     PORT0_MGR0_rlast,
  input logic                     PORT0_MGR0_rvalid,
  output logic                    PORT0_MGR0_rready,
  //port 1 AXI MGR 1 signals
  //write address signals
  output logic [axi_addr_w-1:0]   PORT1_MGR1_awaddr,
  output logic [axi_id_w-1:0]     PORT1_MGR1_awid,
  output logic [axi_len_w-1:0]    PORT1_MGR1_awlen,
  output logic [axi_size_w-1:0]   PORT1_MGR1_awsize,
  output logic [axi_burst_w-1:0]  PORT1_MGR1_awburst,
  output logic                    PORT1_MGR1_awvalid,
  input logic                     PORT1_MGR1_awready,
  //write data signals
  output logic [axi_data_w-1:0]   PORT1_MGR1_wdata,
  output logic [axi_wstrb_w-1:0]  PORT1_MGR1_wstrb,
  input logic                     PORT1_MGR1_wlast,
  output logic                    PORT1_MGR1_wvalid,
  input logic                     PORT1_MGR1_wready,
  //write response signals
  input logic [axi_id_w-1:0]      PORT1_MGR1_bid ,
  input logic [axi_resp_w-1:0]    PORT1_MGR1_bresp,
  input logic                     PORT1_MGR1_bvalid,
  output logic                    PORT1_MGR1_bready,
  //read address signals
  output logic [axi_addr_w-1:0]   PORT1_MGR1_araddr,
  output logic [axi_id_w-1:0]     PORT1_MGR1_arid,
  output logic [axi_len_w-1:0]    PORT1_MGR1_arlen,
  output logic [axi_size_w-1:0]   PORT1_MGR1_arsize,
  output logic [axi_burst_w-1:0]  PORT1_MGR1_arburst,
  output logic                    PORT1_MGR1_arvalid,
  input logic                     PORT1_MGR1_arready,
  //read data signals
  input logic [axi_data_w-1:0]    PORT1_MGR1_rdata,
  input logic [axi_id_w-1:0]      PORT1_MGR1_rid,
  input logic [axi_resp_w-1:0]    PORT1_MGR1_rresp,
  input logic                     PORT1_MGR1_rlast,
  input logic                     PORT1_MGR1_rvalid,
  output logic                    PORT1_MGR1_rready,

  //FDI Interface
  //local to adapter
  output logic [fdi_data_w-1:0]   fdi_lp_data,
  output logic                    fdi_lp_valid,
  output logic                    fdi_lp_irdy,
  output logic                    fdi_lp_startofpkt,
  output logic                    fdi_lp_endofpkt,
  input logic                     fdi_pl_trdy,
  output logic [fdi_status_w-1:0] fdi_lp_state_req,
  output logic                    fdi_lp_linkerror,
  //adapter to local
  input logic [fdi_data_w-1:0]    fdi_pl_data,
  input logic                     fdi_pl_valid,
  input logic                     fdi_pl_irdy,
  input logic                     fdi_pl_startofpkt,
  input logic                     fdi_pl_endofpkt,
  output logic                    fdi_lp_trdy,
  input logic [fdi_status_w-1:0]  fdi_pl_state_sts,
  input logic                     fdi_pl_inband_pres
);


axfdi_fdi_if #(
  .fdi_flit_width(2048),
)(
  //clock and reset wires
  .fdi_clk(),
  .fdi_rst_n(),
  .por_n(),

  .fdi_lp_data(),
  .fdi_lp_valid(),
  .fdi_lp_irdy(),
  .fdi_lp_startofpkt(),
  .fdi_lp_endofpkt(),
  .fdi_pl_trdy(),
  .fdi_lp_state_req(),
  .fdi_lp_linkerror(),

  .fdi_pl_data(),
  .fdi_pl_valid(),
  .fdi_pl_irdy(),
  .fdi_pl_startofpkt(),
  .fdi_pl_endofpkt(),
  .fdi_lp_trdy(),
  .fdi_pl_state_sts(),
  .fdi_pl_inband_pres(),

  .flit_tx_data(),
  .flit_tx_data_valid(),
  .fdi_depktr_tx_sop(),
  .fdi_depktr_tx_eop(),

  .flit_rx_data(),
  .flit_rx_data_valid(),
  .fdi_crdtmgr_rx_trdy(),
  .fdi_depktr_rx_sop(),
  .fdi_depktr_rx_eop(),

  .credit_init_req(),
  .credit_init_done()
  );

axfdi_port_router #(
  .axi_data_w(),
  .axi_burst_len_w (),
  .axi_burst_type_w () ,
  .axi_burst_size_w (),
  .axi_resp_w(),
  .axi_addr_w(),
  .axi_wstrb_w(),
  .axi_id_w(),
  .cdc_aw_d_w(),
  .cdc_w_d_w(),
  .cdc_ar_d_w(),
  .cdc_b_d_w(),
  .cdc_r_d_w()
)u_axfdi_port_router(
  //clock and reset signals
  .fdi_clk(),
  .fdi_rst_n(),
  .por_n(),

  .depktr_portrtr_axi_data(),
  .depktr_portrtr_axi_burst_len(),
  .depktr_portrtr_axi_burst_type(),
  .depktr_portrtr_axi_burst_size(),
  .depktr_portrtr_axi_resp(),
  .depktr_portrtr_axi_addr(),
  .depktr_portrtr_axi_wstrb(),
  .depktr_portrtr_flit_eop(),
  .depktr_portrtr_flit_sop(),
  .portrtr_depktr_read_done(), //indicating port router has performed read
  .depktr_portrtr_write_req_valid(),
  .depktr_portrtr_read_req_valid(),
  .depktr_portrtr_write_resp_valid(),
  .depktr_portrtr_read_resp_valid(),
  .depktr_portrtr_port_id(),
  .depktr_portrtr_txn_id(),

  .port0_cdc_aw_d(),
  .port0_cdc_aw_d_wr_en(),
  .port0_cdc_aw_d_full(),
  .port0_cdc_w_d(),
  .port0_cdc_w_d_wr_en(),
  .port0_cdc_w_d_full(),
  .port0_cdc_ar_d(),
  .port0_cdc_ar_d_wr_en(),
  .port0_cdc_ar_d_full(),
  .port0_cdc_b_d(),
  .port0_cdc_b_d_wr_en(),
  .port0_cdc_b_d_full(),
  .port0_cdc_r_d(),
  .port0_cdc_r_d_wr_en(),
  .port0_cdc_r_d_full(),
  .port1_cdc_aw_d(),
  .port1_cdc_aw_d_wr_en(),
  .port1_cdc_aw_d_full(),
  .port1_cdc_w_d(),
  .port1_cdc_w_d_wr_en(),
  .port1_cdc_w_d_full(),
  .port1_cdc_ar_d(),
  .port1_cdc_ar_d_wr_en(),
  .port1_cdc_ar_d_full(),
  .port1_cdc_b_d(),
  .port1_cdc_b_d_wr_en(),
  .port1_cdc_b_d_full(),
  .port1_cdc_r_d(),
  .port1_cdc_r_d_wr_en(),
  .port1_cdc_r_d_full(),
 );

axfdi_completion_tracker #(
.tracker_depth(),
  .txn_id_w()
)
u_axfdi_completion_tracker(
 //clock and reset logics
 .fdi_clk(),
 .fdi_rst_n(),
 .por_n(),

 //signals from the depacketizer
 .rx_resp_valid(),
 .rx_vcn(),
 .rx_txn_id(),
 .rx_resp_port_id(),
 .rx_resp_port_id_valid(),

 //signals from packetizer
 .tx_vcn(),
 .tx_txn_id(),
 .tx_port_id(),
 .tx_write_done(),
 .tx_txn_valid()
);

axfdi_credit_mgr #(
    .credit_size(),
    .rtn_vcn_w(),
    .vcn_w()
)u_axfdi_credit_mgr(
  .fdi_clk(),
  .fdi_rst_n(),
  .por_n(),
  //signls to the depacketizer for the returned crdit
  .tx_credit_rtn_vcn(),
  .tx_credit_rtn_cnt(),
  .tx_credit_rtn_valid(),
  //upon receiving flit increment the rx_consumed credit count
  .rx_credit_cnsmd_incr_flag(),
  .rx_credit_cnsmd_incr_vcn(),

  //signals from the packetizer indicating tx done
  .tx_credit_vcn(),
  .tx_credit_decr_flag(),
  //signals indicating tx credits
  .tx_vc_cpl_credit_ind(),
  .tx_vc_np_credit_ind(),
  //piggyback the rtn credit or standalone tx
  .credit_rtn_opcode_en(),
  .rx_credit_rtn_cnt(),
  .rx_credit_rtn_vcn(),
  .credit_rtn_piggy_en(),
  //indicator
  .pending_tx_available(),
  .credit_rtn_done(),

  //credit init req from FDI interface
  .credit_init_req(),
  .credit_init_done()
);


module axfdi_depacketizer #(
   .fdi_flit_width(),
   .axi_data_width()
)(
//clock and reset
  .fdi_clk(),
  .fdi_rst_n(),
  .por_n(), //global reset

  .flit_rx_data(),
  .flit_rx_data_valid(),

  //signals to the credit manager
  .depktr_crdtmgr_credit_vcn(),//credit_rtn_vcn
  .depktr_crdtmgr_credit_cnt(),
  .depktr_crdtmgr_rtn_valid(),
  .depktr_crdtmgr_credit_rx_incr(),
  .depktr_crdtmgr_rx_vcn(), //vcn from header

  //signals to the port router
  .depktr_portrtr_axi_data(),
  .depktr_portrtr_axi_burst_len(),
  .depktr_portrtr_axi_burst_type(),
  .depktr_portrt_axi_burst_size(),
  .depktr_portrtr_axi_resp(),
  .depkrt_portrtr_axi_addr(),
  .depktr_portrtr_axi_wstrb(),
//  input logic                       portrtr_depktr_bakpres, //backpressure from the port router
  .portrtr_depktr_read_done(), //indicating port router has performed read
  .depktr_portrtr_write_req_valid(),
  .depktr_portrtr_read_req_valid(),
  .depktr_portrtr_write_resp_valid(),
  .depktr_portrtr_read_resp_valid(),
  .depktr_portrtr_port_id(),
  .depktr_portrtr_txn_id(),

  //signals completion tracker
  .depktr_cmpltkr_resp_valid(),
  .depktr_cmpltkr_vcn(),
  .depktr_cmpltkr_txn_id(),
  .cmpltkr_depktr_port_id(),
  .cmpltkr_depktr_port_id_valid()

);

 axfdi_axi_mgr  #(
    .AXI_DATA_W(),
    .AXI_ADDR_W(),
    .AXI_ID_W()
)u_axfdi_axi_mgr0 (
   // clock and reset
   .axi_clk(),
   .axi_rst_n(),

    // Write Address Channel
   .awaddr(),
   .awid(),
   .awlen(),
   .awsize(),
   .awburst(),
   .awvalid(),
   .awready(),

    // Write Data Channel
   .wdata(),
   .wstrb(),
   .wlast(),
   .wvalid(),
   .wready(),

    // Write Response Channel
   .bid(),
   .bresp(),
   .bvalid(),
   .bready(),

    // Read Address Channel
   .araddr(),
   .arid(),
   .arlen(),
   .arsize(),
   .arburst(),
   .arvalid(),
   .arready(),

    // Read Data Channel
   .rdata(),
   .rid(),
   .rresp(),
   .rlast(),
   .rvalid(),
   .rready(),

    // CDC to mng
   .AW_cdc_data(),
   .AW_cdc_empty(),
   .AW_cdc_rd_en(),

   .W_cdc_data(),
   .W_cdc_empty(),
   .W_cdc_rd_en(),

   .AR_cdc_data(),
   .AR_cdc_empty(),
   .AR_cdc_rd_en(),

   .R_cdc_data(),
   .R_cdc_full(),
   .R_cdc_wr_en(),

   .B_cdc_data(),
   .B_cdc_full(),
   .B_cdc_wr_en()
);


 axfdi_axi_mgr  #(
    .AXI_DATA_W(),
    .AXI_ADDR_W(),
    .AXI_ID_W()
) u_axfdi_axi_mgr1(
   // clock and reset
   .axi_clk(),
   .axi_rst_n(),

    // Write Address Channel
   .awaddr(),
   .awid(),
   .awlen(),
   .awsize(),
   .awburst(),
   .awvalid(),
   .awready(),

    // Write Data Channel
   .wdata(),
   .wstrb(),
   .wlast(),
   .wvalid(),
   .wready(),

    // Write Response Channel
   .bid(),
   .bresp(),
   .bvalid(),
   .bready(),

    // Read Address Channel
   .araddr(),
   .arid(),
   .arlen(),
   .arsize(),
   .arburst(),
   .arvalid(),
   .arready(),

    // Read Data Channel
   .rdata(),
   .rid(),
   .rresp(),
   .rlast(),
   .rvalid(),
   .rready(),

    // CDC to mng
   .AW_cdc_data(),
   .AW_cdc_empty(),
   .AW_cdc_rd_en(),

   .W_cdc_data(),
   .W_cdc_empty(),
   .W_cdc_rd_en(),

   .AR_cdc_data(),
   .AR_cdc_empty(),
   .AR_cdc_rd_en(),

   .R_cdc_data(),
   .R_cdc_full(),
   .R_cdc_wr_en(),

   .B_cdc_data(),
   .B_cdc_full(),
   .B_cdc_wr_en()
);


 axfdi_axi_sub #(
    .AXI_DATA_W(),
    .AXI_ADDR_W(),
    .AXI_ID_W()
) u_axfdi_axi_sub0(
    // clock and reset
    .axi_clk(),
    .axi_rst_n(),

    // Write Address Channel
    .awaddr(),
    .awid(),
    . awlen(),
    . awsize(),
    . awburst(),
    . awvalid(),
    . awready(),

    // Write Data Channel
   .wdata(),
   .wstrb(),
   .wlast(),
   .wvalid(),
   .wready(),

    // Write Response Channel
    .bid(),
    .bresp(),
    .bvalid(),
    .bready(),

    // Read Address Channel
    .araddr(),
    .arid(),
    .arlen(),
    .arsize(),
    .arburst(),
    .arvalid(),
    .arready(),

    // Read Data Channel
    .rdata(),
    .rid(),
    .rresp(),
    .rlast(),
    .rvalid(),
    .rready(),

    // CDC FIFO ports — TX side
    .AW_cdc_full(),
    .AW_cdc_data(),    // {awid,awlen,awburst,awsize,awaddr}
    .AW_cdc_wr_en(),
    .W_cdc_full(),
    .W_cdc_data(),     // {wdata,wstrb,wlast}
    .W_cdc_wr_en(),

    .AR_cdc_full(),
    .AR_cdc_data(),    // {arid,arlen,arburst,arsize,araddr}
    .AR_cdc_wr_en(),

    // CDC FIFO ports — RX side
    .B_cdc_empty(),
    .B_cdc_data(),     // {bid,bresp}
    .B_cdc_rd_en(),

    .R_cdc_empty(),
    .R_cdc_data(),     // {rdata,rid,rresp,rlast}
    .R_cdc_rd_en()
   );


 axfdi_axi_sub #(
    .AXI_DATA_W(),
    .AXI_ADDR_W(),
    .AXI_ID_W()
) u_axfdi_axi_sub1(
    // clock and reset
    .axi_clk(),
    .axi_rst_n(),

    // Write Address Channel
    .awaddr(),
    .awid(),
    . awlen(),
    . awsize(),
    . awburst(),
    . awvalid(),
    . awready(),

    // Write Data Channel
   .wdata(),
   .wstrb(),
   .wlast(),
   .wvalid(),
   .wready(),

    // Write Response Channel
    .bid(),
    .bresp(),
    .bvalid(),
    .bready(),

    // Read Address Channel
    .araddr(),
    .arid(),
    .arlen(),
    .arsize(),
    .arburst(),
    .arvalid(),
    .arready(),

    // Read Data Channel
    .rdata(),
    .rid(),
    .rresp(),
    .rlast(),
    .rvalid(),
    .rready(),

    // CDC FIFO ports — TX side
    .AW_cdc_full(),
    .AW_cdc_data(),    // {awid,awlen,awburst,awsize,awaddr}
    .AW_cdc_wr_en(),
    .W_cdc_full(),
    .W_cdc_data(),     // {wdata,wstrb,wlast}
    .W_cdc_wr_en(),

    .AR_cdc_full(),
    .AR_cdc_data(),    // {arid,arlen,arburst,arsize,araddr}
    .AR_cdc_wr_en(),

    // CDC FIFO ports — RX side
    .B_cdc_empty(),
    .B_cdc_data(),     // {bid,bresp}
    .B_cdc_rd_en(),

    .R_cdc_empty(),
    .R_cdc_data(),     // {rdata,rid,rresp,rlast}
    .R_cdc_rd_en()
   );
   
endmodule
