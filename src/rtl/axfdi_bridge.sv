//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-17 00:40
// File Name: axfdi_bridge.sv
// Project Name: AXFDI Bridge
// Description: Top file Bridge
//
// Last Updated: 2026-04-17 00:40
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module axfdi_bridge
#(
  parameter axi_addr_w = 40,
  parameter axi_id_w = 8,
  parameter axi_len_w = 8,
  parameter axi_size_w = 3,
  parameter axi_burst_w = 2,
  parameter axi_data_w = 1024,
  parameter axi_wstrb_w = 128,
  parameter axi_resp_w = 2,
  parameter fdi_data_w = 2048,
  parameter fdi_status_w = 3,
  parameter cdc_aw_d_w = 61,
  parameter cdc_w_d_w = 1153,
  parameter cdc_ar_d_w = 61,
  parameter cdc_b_d_w = 10,
  parameter cdc_r_d_w = 1035,
  parameter cdc_depth = 16,
  parameter cdc_addr_w = $clog2(cdc_depth),
  parameter credit_size = 6,
  parameter rtn_vcn_w = 2,
  parameter vcn_w = 3,
  parameter completion_tracker_w = 256,
  parameter AW_DEPTH   = 32,
  parameter W_DEPTH    = 64,
  parameter AR_DEPTH   = 32,
  parameter AW_W = axi_id_w + 8 + 2 + 3 + axi_addr_w,
  parameter W_W  = axi_data_w + 128 + 1,
  parameter AR_W = axi_id_w + 8 + 2 + 3 + axi_addr_w,
  parameter B_W  = axi_id_w + 2,
  parameter R_W  = axi_data_w + axi_id_w + 2 + 1
)(
  //clock and reset logic
  input logic                     fdi_clk_i,
  input logic                     axi_clk_i,
  input logic                     por_n_i,
  input logic                     axi_rst_n_i,
  input logic                     fdi_rst_n_i,

  //port 0 AXI SUB 0 signals
  //write address signals
  input logic [axi_addr_w-1:0]    PORT0_SUB_awaddr,
  input logic [axi_id_w-1:0]      PORT0_SUB_awid,
  input logic [axi_len_w-1:0]     PORT0_SUB_awlen,
  input logic [axi_size_w-1:0]    PORT0_SUB_awsize,
  input logic [axi_burst_w-1:0]   PORT0_SUB_awburst,
  input logic                     PORT0_SUB_awvalid,
  output logic                    PORT0_SUB_awready,
  //write data signals
  input logic [axi_data_w-1:0]    PORT0_SUB_wdata,
  input logic [axi_wstrb_w-1:0]   PORT0_SUB_wstrb,
  input logic                    PORT0_SUB_wlast,
  input logic                     PORT0_SUB_wvalid,
  output logic                    PORT0_SUB_wready,
  //write response signals
  output logic [axi_id_w-1:0]     PORT0_SUB_bid ,
  output logic [axi_resp_w-1:0]   PORT0_SUB_bresp,
  output logic                    PORT0_SUB_bvalid,
  input logic                     PORT0_SUB_bready,
  //read address signals
  input logic [axi_addr_w-1:0]    PORT0_SUB_araddr,
  input logic [axi_id_w-1:0]      PORT0_SUB_arid,
  input logic [axi_len_w-1:0]     PORT0_SUB_arlen,
  input logic [axi_size_w-1:0]    PORT0_SUB_arsize,
  input logic [axi_burst_w-1:0]   PORT0_SUB_arburst,
  input logic                     PORT0_SUB_arvalid,
  output logic                    PORT0_SUB_arready,
  //read data signals
  output logic [axi_data_w-1:0]   PORT0_SUB_rdata,
  output logic [axi_id_w-1:0]     PORT0_SUB_rid,
  output logic [axi_resp_w-1:0]   PORT0_SUB_rresp,
  output logic                    PORT0_SUB_rlast,
  output logic                    PORT0_SUB_rvalid,
  input logic                     PORT0_SUB_rready,
  //port 1 AXI  SUB1 signals
  //write address signals
  input logic [axi_addr_w-1:0]    PORT1_SUB_awaddr,
  input logic [axi_id_w-1:0]      PORT1_SUB_awid,
  input logic [axi_len_w-1:0]     PORT1_SUB_awlen,
  input logic [axi_size_w-1:0]    PORT1_SUB_awsize,
  input logic [axi_burst_w-1:0]   PORT1_SUB_awburst,
  input logic                     PORT1_SUB_awvalid,
  output logic                    PORT1_SUB_awready,
  //write data signals
  input logic [axi_data_w-1:0]    PORT1_SUB_wdata,
  input logic [axi_wstrb_w-1:0]   PORT1_SUB_wstrb,
  input logic                     PORT1_SUB_wlast,
  input logic                     PORT1_SUB_wvalid,
  output logic                    PORT1_SUB_wready,
  //write response signals
  output logic [axi_id_w-1:0]     PORT1_SUB_bid ,
  output logic [axi_resp_w-1:0]   PORT1_SUB_bresp,
  output logic                    PORT1_SUB_bvalid,
  input logic                     PORT1_SUB_bready,
  //read address signals
  input logic [axi_addr_w-1:0]    PORT1_SUB_araddr,
  input logic [axi_id_w-1:0]      PORT1_SUB_arid,
  input logic [axi_len_w-1:0]     PORT1_SUB_arlen,
  input logic [axi_size_w-1:0]    PORT1_SUB_arsize,
  input logic [axi_burst_w-1:0]   PORT1_SUB_arburst,
  input logic                     PORT1_SUB_arvalid,
  output logic                    PORT1_SUB_arready,
  //read data signals
  output logic [axi_data_w-1:0]   PORT1_SUB_rdata,
  output logic [axi_id_w-1:0]     PORT1_SUB_rid,
  output logic [axi_resp_w-1:0]   PORT1_SUB_rresp,
  output logic                    PORT1_SUB_rlast,
  output logic                    PORT1_SUB_rvalid,
  input logic                     PORT1_SUB_rready,
  //port 0 AXI MGR 0 signals
  //write address signals
  output logic [axi_addr_w-1:0]   PORT0_MGR_awaddr,
  output logic [axi_id_w-1:0]     PORT0_MGR_awid,
  output logic [axi_len_w-1:0]    PORT0_MGR_awlen,
  output logic [axi_size_w-1:0]   PORT0_MGR_awsize,
  output logic [axi_burst_w-1:0]  PORT0_MGR_awburst,
  output logic                    PORT0_MGR_awvalid,
  input logic                     PORT0_MGR_awready,
  //write data signals
  output logic [axi_data_w-1:0]   PORT0_MGR_wdata,
  output logic [axi_wstrb_w-1:0]  PORT0_MGR_wstrb,
  output logic                    PORT0_MGR_wlast,
  output logic                    PORT0_MGR_wvalid,
  input logic                     PORT0_MGR_wready,
  //write response signals
  input logic [axi_id_w-1:0]      PORT0_MGR_bid ,
  input logic [axi_resp_w-1:0]    PORT0_MGR_bresp,
  input logic                     PORT0_MGR_bvalid,
  output logic                    PORT0_MGR_bready,
  //read address signals
  output logic [axi_addr_w-1:0]   PORT0_MGR_araddr,
  output logic [axi_id_w-1:0]     PORT0_MGR_arid,
  output logic [axi_len_w-1:0]    PORT0_MGR_arlen,
  output logic [axi_size_w-1:0]   PORT0_MGR_arsize,
  output logic [axi_burst_w-1:0]  PORT0_MGR_arburst,
  output logic                    PORT0_MGR_arvalid,
  input logic                     PORT0_MGR_arready,
  //read data signals
  input logic [axi_data_w-1:0]    PORT0_MGR_rdata,
  input logic [axi_id_w-1:0]      PORT0_MGR_rid,
  input logic [axi_resp_w-1:0]    PORT0_MGR_rresp,
  input logic                     PORT0_MGR_rlast,
  input logic                     PORT0_MGR_rvalid,
  output logic                    PORT0_MGR_rready,
  //port 1 AXI MGR 1 signals
  //write address signals
  output logic [axi_addr_w-1:0]   PORT1_MGR_awaddr,
  output logic [axi_id_w-1:0]     PORT1_MGR_awid,
  output logic [axi_len_w-1:0]    PORT1_MGR_awlen,
  output logic [axi_size_w-1:0]   PORT1_MGR_awsize,
  output logic [axi_burst_w-1:0]  PORT1_MGR_awburst,
  output logic                    PORT1_MGR_awvalid,
  input logic                     PORT1_MGR_awready,
  //write data signals
  output logic [axi_data_w-1:0]   PORT1_MGR_wdata,
  output logic [axi_wstrb_w-1:0]  PORT1_MGR_wstrb,
  output logic                    PORT1_MGR_wlast,
  output logic                    PORT1_MGR_wvalid,
  input logic                     PORT1_MGR_wready,
  //write response signals
  input logic [axi_id_w-1:0]      PORT1_MGR_bid ,
  input logic [axi_resp_w-1:0]    PORT1_MGR_bresp,
  input logic                     PORT1_MGR_bvalid,
  output logic                    PORT1_MGR_bready,
  //read address signals
  output logic [axi_addr_w-1:0]   PORT1_MGR_araddr,
  output logic [axi_id_w-1:0]     PORT1_MGR_arid,
  output logic [axi_len_w-1:0]    PORT1_MGR_arlen,
  output logic [axi_size_w-1:0]   PORT1_MGR_arsize,
  output logic [axi_burst_w-1:0]  PORT1_MGR_arburst,
  output logic                    PORT1_MGR_arvalid,
  input logic                     PORT1_MGR_arready,
  //read data signals
  input logic [axi_data_w-1:0]    PORT1_MGR_rdata,
  input logic [axi_id_w-1:0]      PORT1_MGR_rid,
  input logic [axi_resp_w-1:0]    PORT1_MGR_rresp,
  input logic                     PORT1_MGR_rlast,
  input logic                     PORT1_MGR_rvalid,
  output logic                    PORT1_MGR_rready,

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

   //signals in the FDI interface
   logic [fdi_data_w-1:0]         s_flit_tx_data;
   logic                          s_flit_tx_data_valid;
   logic                          s_fdi_pktr_tx_sop;
   logic                          s_fdi_pktr_tx_eop;
   logic                          s_flit_tx_ready;
   logic [fdi_data_w-1:0]         s_flit_rx_data;
   logic                          s_flit_rx_data_valid;
   logic                          s_fdi_depktr_rx_trdy;
   logic                          s_fdi_depktr_rx_startofpkt;
   logic                          s_fdi_depktr_rx_endofpkt;
   logic                          s_credit_init_req;
   logic                          s_credit_init_done;

   //From depacker to port router
   logic [axi_data_w-1:0]         s_depktr_portrtr_axi_data;
   logic [axi_len_w-1:0]          s_depktr_portrtr_axi_burst_len;
   logic [axi_burst_w-1:0]        s_depktr_portrtr_axi_burst_type;
   logic [axi_size_w-1:0]         s_depktr_portrtr_axi_burst_size;
   logic [axi_resp_w-1:0]         s_depktr_portrtr_axi_resp;
   logic [axi_addr_w-1:0]         s_depktr_portrtr_axi_addr;
   logic [axi_wstrb_w-1:0]        s_depktr_portrtr_axi_wstrb;
   logic                          s_portrtr_depktr_bakpres;
   logic                          s_depktr_portrtr_flit_endofpkt;
   logic                          s_depktr_portrtr_flit_startofpkt;

   logic                          s_portrtr_depktr_read_done; //indicating port router has performed read
   logic                          s_depktr_portrtr_write_req_valid;
   logic                          s_depktr_portrtr_read_req_valid;
   logic                          s_depktr_portrtr_write_resp_valid;
   logic                          s_depktr_portrtr_read_resp_valid;
   logic                          s_depktr_portrtr_port_id;
   logic [axi_id_w-1:0]           s_depktr_portrtr_txn_id;

   //FROM depacketizer to Credit Manager
   logic [1:0]                    s_depktr_crdtmgr_credit_vcn;//credit_rtn_vcn
   logic [5:0]                    s_depktr_crdtmgr_credit_cnt;
   logic                          s_depktr_crdtmgr_rtn_valid;
   logic                          s_depktr_crdtmgr_credit_rx_incr;
   logic [2:0]                    s_depktr_crdtmgr_rx_vcn; //vcn from header
   // FROM depacketizer to completion tracker
   logic                          s_depktr_cmpltkr_resp_valid;
   logic                          s_depktr_cmpltkr_vcn;
   logic [7:0]                    s_depktr_cmpltkr_txn_id;
   logic                          s_cmpltkr_depktr_port_id;
   logic                          s_cmpltkr_depktr_port_id_valid;

   //from Packetizer to credit maanger
   logic                          s_credit_rtn_opcode_en;
   logic [credit_size-1:0]        s_rx_credit_rtn_cnt;
   logic [rtn_vcn_w-1:0]          s_rx_credit_rtn_vcn;
   logic                          s_credit_rtn_piggy_en;
   logic [vcn_w-1:0]              s_tx_credit_vcn;
   logic                          s_tx_credit_decr_flag;

   logic                          s_pending_tx_available;
   logic                          s_credit_rtn_done;
   //packetizer to completion tracker
   logic                          s_pktr_cmpltkr_tx_vcn;
   logic [axi_id_w-1:0]           s_pktr_cmpltkr_tx_txn_id;
   logic                          s_pktr_cmpltkr_tx_port_id;
   logic                          s_pktr_cmpltkr_tx_write_done;
   logic                          s_pktr_cmpltkr_tx_txn_valid;
   //TX side signals
   //from arbitar
   logic [2:0]                    s_arb_txn_type;
   logic [vcn_w-1:0]              s_arb_vcn_sel;
   logic                          s_arb_port_id;
   logic                          s_fdi_pktr_eop;

   logic                          s_tx_vc_cpl_credit_ind;
   logic                          s_tx_vc_np_credit_ind;

   logic                          s_portmrg_arb_port_id;
   logic                          s_portmrg_arb_write_req_vaild;
   logic                          s_portmrg_arb_read_req_vaild;
   logic                          s_portmrg_arb_write_resp_vaild;
   logic                          s_portmrg_arb_read_resp_vaild;



  //port0 CDC signals sub0
   logic [cdc_aw_d_w-1:0]         s_port0_sub_cdc_aw_d;
   logic                          s_port0_sub_cdc_aw_d_wr_en;
   logic                          s_port0_sub_cdc_aw_d_full;
   logic                          s_port0_sub_cdc_aw_d_empty;
   logic                          s_port0_sub_cdc_aw_d_rd_en;
   logic [cdc_aw_d_w-1:0]         s_port0_sub_cdc_aw_d_out;
   logic [cdc_w_d_w-1:0]          s_port0_sub_cdc_w_d;
   logic                          s_port0_sub_cdc_w_d_wr_en;
   logic                          s_port0_sub_cdc_w_d_full;
   logic                          s_port0_sub_cdc_w_d_empty;
   logic                          s_port0_sub_cdc_w_d_rd_en;
   logic [cdc_w_d_w-1:0]          s_port0_sub_cdc_w_d_out;
   logic [cdc_ar_d_w-1:0]         s_port0_sub_cdc_ar_d;
   logic                          s_port0_sub_cdc_ar_d_wr_en;
   logic                          s_port0_sub_cdc_ar_d_full;
   logic                          s_port0_sub_cdc_ar_d_empty;
   logic                          s_port0_sub_cdc_ar_d_rd_en;
   logic [cdc_ar_d_w-1:0]         s_port0_sub_cdc_ar_d_out;
   logic [cdc_b_d_w-1:0]          s_port0_sub_cdc_b_d;
   logic                          s_port0_sub_cdc_b_d_wr_en;
   logic                          s_port0_sub_cdc_b_d_full;
   logic                          s_port0_sub_cdc_b_d_empty;
   logic                          s_port0_sub_cdc_b_d_rd_en;
   logic [cdc_b_d_w-1:0]          s_port0_sub_cdc_b_d_out;
   logic [cdc_r_d_w-1:0]          s_port0_sub_cdc_r_d;
   logic                          s_port0_sub_cdc_r_d_wr_en;
   logic                          s_port0_sub_cdc_r_d_full;
   logic                          s_port0_sub_cdc_r_d_empty;
   logic                          s_port0_sub_cdc_r_d_rd_en;
   logic [cdc_r_d_w-1:0]          s_port0_sub_cdc_r_d_out;
   //port0 CDC signals MGR0
   logic [cdc_aw_d_w-1:0]         s_port0_mgr_cdc_aw_d;
   logic                          s_port0_mgr_cdc_aw_d_wr_en;
   logic                          s_port0_mgr_cdc_aw_d_full;
   logic                          s_port0_mgr_cdc_aw_d_empty;
   logic                          s_port0_mgr_cdc_aw_d_rd_en;
   logic [cdc_aw_d_w-1:0]         s_port0_mgr_cdc_aw_d_out;
   logic [cdc_w_d_w-1:0]          s_port0_mgr_cdc_w_d;
   logic                          s_port0_mgr_cdc_w_d_wr_en;
   logic                          s_port0_mgr_cdc_w_d_full;
   logic                          s_port0_mgr_cdc_w_d_empty;
   logic                          s_port0_mgr_cdc_w_d_rd_en;
   logic [cdc_w_d_w-1:0]         s_port0_mgr_cdc_w_d_out;
   logic [cdc_ar_d_w-1:0]         s_port0_mgr_cdc_ar_d;
   logic                          s_port0_mgr_cdc_ar_d_wr_en;
   logic                          s_port0_mgr_cdc_ar_d_full;
   logic                          s_port0_mgr_cdc_ar_d_empty;
   logic                          s_port0_mgr_cdc_ar_d_rd_en;
   logic [cdc_ar_d_w-1:0]         s_port0_mgr_cdc_ar_d_out;
   logic [cdc_b_d_w-1:0]          s_port0_mgr_cdc_b_d;
   logic                          s_port0_mgr_cdc_b_d_wr_en;
   logic                          s_port0_mgr_cdc_b_d_full;
   logic                          s_port0_mgr_cdc_b_d_empty;
   logic                          s_port0_mgr_cdc_b_d_rd_en;
   logic [cdc_b_d_w-1:0]          s_port0_mgr_cdc_b_d_out;
   logic [cdc_r_d_w-1:0]          s_port0_mgr_cdc_r_d;
   logic                          s_port0_mgr_cdc_r_d_wr_en;
   logic                          s_port0_mgr_cdc_r_d_full;
   logic                          s_port0_mgr_cdc_r_d_empty;
   logic                          s_port0_mgr_cdc_r_d_rd_en;
   logic [cdc_r_d_w-1:0]          s_port0_mgr_cdc_r_d_out;

  //port1 CDC signals SUB signal
   logic [cdc_aw_d_w-1:0]         s_port1_sub_cdc_aw_d;
   logic                          s_port1_sub_cdc_aw_d_wr_en;
   logic                          s_port1_sub_cdc_aw_d_full;
   logic                          s_port1_sub_cdc_aw_d_empty;
   logic                          s_port1_sub_cdc_aw_d_rd_en;
   logic [cdc_aw_d_w-1:0]         s_port1_sub_cdc_aw_d_out;
   logic [cdc_w_d_w-1:0]          s_port1_sub_cdc_w_d;
   logic                          s_port1_sub_cdc_w_d_wr_en;
   logic                          s_port1_sub_cdc_w_d_full;
   logic                          s_port1_sub_cdc_w_d_empty;
   logic                          s_port1_sub_cdc_w_d_rd_en;
   logic [cdc_w_d_w-1:0]          s_port1_sub_cdc_w_d_out;
   logic [cdc_ar_d_w-1:0]         s_port1_sub_cdc_ar_d;
   logic                          s_port1_sub_cdc_ar_d_wr_en;
   logic                          s_port1_sub_cdc_ar_d_full;
   logic                          s_port1_sub_cdc_ar_d_empty;
   logic                          s_port1_sub_cdc_ar_d_rd_en;
   logic [cdc_ar_d_w-1:0]         s_port1_sub_cdc_ar_d_out;
   logic [cdc_b_d_w-1:0]          s_port1_sub_cdc_b_d;
   logic                          s_port1_sub_cdc_b_d_wr_en;
   logic                          s_port1_sub_cdc_b_d_full;
   logic                          s_port1_sub_cdc_b_d_empty;
   logic                          s_port1_sub_cdc_b_d_rd_en;
   logic [cdc_b_d_w-1:0]          s_port1_sub_cdc_b_d_out;
   logic [cdc_r_d_w-1:0]          s_port1_sub_cdc_r_d;
   logic                          s_port1_sub_cdc_r_d_wr_en;
   logic                          s_port1_sub_cdc_r_d_full;
   logic                          s_port1_sub_cdc_r_d_empty;
   logic                          s_port1_sub_cdc_r_d_rd_en;
   logic [cdc_r_d_w-1:0]          s_port1_sub_cdc_r_d_out;
   //PORT1 CDC signals MGR
   logic [cdc_aw_d_w-1:0]         s_port1_mgr_cdc_aw_d;
   logic                          s_port1_mgr_cdc_aw_d_wr_en;
   logic                          s_port1_mgr_cdc_aw_d_full;
   logic                          s_port1_mgr_cdc_aw_d_empty;
   logic                          s_port1_mgr_cdc_aw_d_rd_en;
   logic [cdc_aw_d_w-1:0]         s_port1_mgr_cdc_aw_d_out;
   logic [cdc_w_d_w-1:0]          s_port1_mgr_cdc_w_d;
   logic                          s_port1_mgr_cdc_w_d_wr_en;
   logic                          s_port1_mgr_cdc_w_d_full;
   logic                          s_port1_mgr_cdc_w_d_empty;
   logic                          s_port1_mgr_cdc_w_d_rd_en;
   logic [cdc_w_d_w-1:0]          s_port1_mgr_cdc_w_d_out;
   logic [cdc_ar_d_w-1:0]         s_port1_mgr_cdc_ar_d;
   logic                          s_port1_mgr_cdc_ar_d_wr_en;
   logic                          s_port1_mgr_cdc_ar_d_full;
   logic                          s_port1_mgr_cdc_ar_d_empty;
   logic                          s_port1_mgr_cdc_ar_d_rd_en;
   logic [cdc_ar_d_w-1:0]         s_port1_mgr_cdc_ar_d_out;
   logic [cdc_b_d_w-1:0]          s_port1_mgr_cdc_b_d;
   logic                          s_port1_mgr_cdc_b_d_wr_en;
   logic                          s_port1_mgr_cdc_b_d_full;
   logic                          s_port1_mgr_cdc_b_d_empty;
   logic                          s_port1_mgr_cdc_b_d_rd_en;
   logic [cdc_b_d_w-1:0]          s_port1_mgr_cdc_b_d_out;
   logic [cdc_r_d_w-1:0]          s_port1_mgr_cdc_r_d;
   logic                          s_port1_mgr_cdc_r_d_wr_en;
   logic                          s_port1_mgr_cdc_r_d_full;
   logic                          s_port1_mgr_cdc_r_d_empty;
   logic                          s_port1_mgr_cdc_r_d_rd_en;
   logic [cdc_r_d_w-1:0]          s_port1_mgr_cdc_r_d_out;


   axfdi_fdi_if
     #(
       .fdi_flit_width(2048)
       )u_axfdi_fdi_if
       (
        //clock and reset wires
        .fdi_clk(fdi_clk_i),
        .fdi_rst_n(fdi_rst_n_i),
        .por_n(por_n_i),

        .fdi_lp_data(fdi_lp_data),
        .fdi_lp_valid(fdi_lp_valid),
        .fdi_lp_irdy(fdi_lp_irdy),
        .fdi_lp_startofpkt(fdi_lp_startofpkt),
        .fdi_lp_endofpkt(fdi_lp_endofpkt),
        .fdi_pl_trdy(fdi_pl_trdy),
        .fdi_lp_state_req(fdi_lp_state_req),
        .fdi_lp_linkerror(fdi_lp_linkerror),

        .fdi_pl_data(fdi_pl_data),
        .fdi_pl_valid(fdi_pl_valid),
        .fdi_pl_irdy(fdi_pl_irdy),
        .fdi_pl_startofpkt(fdi_pl_startofpkt),
        .fdi_pl_endofpkt(fdi_pl_endofpkt),
        .fdi_lp_trdy(fdi_lp_trdy),
        .fdi_pl_state_sts(fdi_pl_state_sts),
        .fdi_pl_inband_pres(fdi_pl_inband_pres),

        .flit_tx_data(s_flit_tx_data),
        .flit_tx_data_valid(s_flit_tx_data_valid),
        .fdi_pktr_tx_sop(s_fdi_pktr_tx_sop),
        .fdi_pktr_tx_eop(s_fdi_pktr_tx_eop),
        .fdi_tx_ready(s_flit_tx_ready),

        .flit_rx_data(s_flit_rx_data),
        .flit_rx_data_valid(s_flit_rx_data_valid),
        .fdi_depktr_rx_trdy(s_fdi_depktr_rx_trdy),
        .fdi_depktr_rx_startofpkt(s_fdi_depktr_rx_startofpkt),
        .fdi_depktr_rx_endofpkt(s_fdi_depktr_rx_endofpkt),

        .credit_init_req(s_credit_init_req),
        .credit_init_done(s_credit_init_done)
        );

   axfdi_port_router
     #(
       .axi_data_w(axi_data_w),
       .axi_burst_len_w (axi_len_w),
       .axi_burst_type_w (axi_burst_w),
       .axi_burst_size_w (axi_size_w),
       .axi_resp_w(axi_resp_w),
       .axi_addr_w(axi_addr_w),
       .axi_wstrb_w(axi_wstrb_w),
       .axi_id_w(axi_id_w),
       .cdc_aw_d_w(cdc_aw_d_w),
       .cdc_w_d_w(cdc_w_d_w),
       .cdc_ar_d_w(cdc_ar_d_w),
       .cdc_b_d_w(cdc_b_d_w),
       .cdc_r_d_w(cdc_r_d_w)
       )u_axfdi_port_router
       (
        //clock and reset signals
        .fdi_clk(fdi_clk_i),
        .fdi_rst_n(fdi_rst_n_i),
        .por_n(por_n_i),

        .depktr_portrtr_axi_data(s_depktr_portrtr_axi_data),
        .depktr_portrtr_axi_burst_len(s_depktr_portrtr_axi_burst_len),
        .depktr_portrtr_axi_burst_type(s_depktr_portrtr_axi_burst_type),
        .depktr_portrtr_axi_burst_size(s_depktr_portrtr_axi_burst_size),
        .depktr_portrtr_axi_resp(s_depktr_portrtr_axi_resp),
        .depktr_portrtr_axi_addr(s_depktr_portrtr_axi_addr),
        .depktr_portrtr_axi_wstrb(s_depktr_portrtr_axi_wstrb),
        .portrtr_depktr_bakpres(s_portrtr_depktr_bakpres),
        .depktr_portrtr_flit_endofpkt(s_depktr_portrtr_flit_endofpkt),
        .depktr_portrtr_flit_startofpkt(s_depktr_portrtr_flit_startofpkt),
        .portrtr_depktr_read_done(s_portrtr_depktr_read_done), //indicating port router has performed read
        .depktr_portrtr_write_req_valid(s_depktr_portrtr_write_req_valid),
        .depktr_portrtr_read_req_valid(s_depktr_portrtr_read_req_valid),
        .depktr_portrtr_write_resp_valid(s_depktr_portrtr_write_resp_valid),
        .depktr_portrtr_read_resp_valid(s_depktr_portrtr_read_resp_valid),
        .depktr_portrtr_port_id(s_depktr_portrtr_port_id),
        .depktr_portrtr_txn_id(s_depktr_portrtr_txn_id),

        .port0_cdc_aw_d(s_port0_mgr_cdc_aw_d),
        .port0_cdc_aw_d_wr_en(s_port0_mgr_cdc_aw_d_wr_en),
        .port0_cdc_aw_d_full(s_port0_mgr_cdc_aw_d_full),
        .port0_cdc_w_d(s_port0_mgr_cdc_w_d),
        .port0_cdc_w_d_wr_en(s_port0_mgr_cdc_w_d_wr_en),
        .port0_cdc_w_d_full(s_port0_mgr_cdc_w_d_full),
        .port0_cdc_ar_d(s_port0_mgr_cdc_ar_d),
        .port0_cdc_ar_d_wr_en(s_port0_mgr_cdc_ar_d_wr_en),
        .port0_cdc_ar_d_full(s_port0_mgr_cdc_ar_d_full),
        .port0_cdc_b_d(s_port0_sub_cdc_b_d),
        .port0_cdc_b_d_wr_en(s_port0_sub_cdc_b_d_wr_en),
        .port0_cdc_b_d_full(s_port0_sub_cdc_b_d_full),
        .port0_cdc_r_d(s_port0_sub_cdc_r_d),
        .port0_cdc_r_d_wr_en(s_port0_sub_cdc_r_d_wr_en),
        .port0_cdc_r_d_full(s_port0_sub_cdc_r_d_full),
        .port1_cdc_aw_d(s_port1_mgr_cdc_aw_d),
        .port1_cdc_aw_d_wr_en(s_port1_mgr_cdc_aw_d_wr_en),
        .port1_cdc_aw_d_full(s_port1_mgr_cdc_aw_d_full),
        .port1_cdc_w_d(s_port1_mgr_cdc_w_d),
        .port1_cdc_w_d_wr_en(s_port1_mgr_cdc_w_d_wr_en),
        .port1_cdc_w_d_full(s_port1_mgr_cdc_w_d_full),
        .port1_cdc_ar_d(s_port1_mgr_cdc_ar_d),
        .port1_cdc_ar_d_wr_en(s_port1_mgr_cdc_ar_d_wr_en),
        .port1_cdc_ar_d_full(s_port1_mgr_cdc_ar_d_full),
        .port1_cdc_b_d(s_port1_sub_cdc_b_d),
        .port1_cdc_b_d_wr_en(s_port1_sub_cdc_b_d_wr_en),
        .port1_cdc_b_d_full(s_port1_sub_cdc_b_d_full),
        .port1_cdc_r_d(s_port1_sub_cdc_r_d),
        .port1_cdc_r_d_wr_en(s_port1_sub_cdc_r_d_wr_en),
        .port1_cdc_r_d_full(s_port1_sub_cdc_r_d_full)
        );

   axfdi_completion_tracker
     #(
       .tracker_depth(completion_tracker_w),
       .txn_id_w(axi_id_w)
       )
   u_axfdi_completion_tracker
     (
      //clock and reset logics
      .fdi_clk(fdi_clk_i),
      .fdi_rst_n(fdi_rst_n_i),
      .por_n(por_n_i),

      //signals from the depacketizer
      .rx_resp_valid(s_depktr_cmpltkr_resp_valid),
      .rx_vcn(s_depktr_cmpltkr_vcn),
      .rx_txn_id(s_depktr_cmpltkr_txn_id) ,
      .rx_resp_port_id(s_cmpltkr_depktr_port_id),
      .rx_resp_port_id_valid(s_cmpltkr_depktr_port_id_valid),

      //signals from packetizer
      .tx_vcn(s_pktr_cmpltkr_tx_vcn),
      .tx_txn_id(s_pktr_cmpltkr_tx_txn_id),
      .tx_port_id(s_pktr_cmpltkr_tx_port_id),
      .tx_write_done(s_pktr_cmpltkr_tx_write_done),
      .tx_txn_valid(s_pktr_cmpltkr_tx_txn_valid)
      );

   axfdi_credit_mgr
     #(
       .credit_size(credit_size),
       .rtn_vcn_w(rtn_vcn_w),
       .vcn_w(vcn_w)
       )u_axfdi_credit_mgr
       (
        .fdi_clk(fdi_clk_i),
        .fdi_rst_n(fdi_rst_n_i),
        .por_n(por_n_i),
        //signls to the depacketizer for the returned crdit
        .tx_credit_rtn_vcn(s_depktr_crdtmgr_credit_vcn),
        .tx_credit_rtn_cnt(s_depktr_crdtmgr_credit_cnt),
        .tx_credit_rtn_valid(s_depktr_crdtmgr_rtn_valid),
        //upon receiving flit increment the rx_consumed credit count
        .rx_credit_cnsmd_incr_flag(s_depktr_crdtmgr_credit_rx_incr),
        .rx_credit_cnsmd_incr_vcn(s_depktr_crdtmgr_rx_vcn),

        //signals from the packetizer indicating tx done
        .tx_credit_vcn(s_tx_credit_vcn),
        .tx_credit_decr_flag(s_tx_credit_decr_flag),
        //signals indicating tx credits
        .tx_vc_cpl_credit_ind(s_tx_vc_cpl_credit_ind),
        .tx_vc_np_credit_ind(s_tx_vc_np_credit_ind),
        //piggyback the rtn credit or standalone tx
        .credit_rtn_opcode_en(s_credit_rtn_opcode_en),
        .rx_credit_rtn_cnt(s_rx_credit_rtn_cnt),
        .rx_credit_rtn_vcn(s_rx_credit_rtn_vcn),
        .credit_rtn_piggy_en(s_credit_rtn_piggy_en),
        //indicator
        .pending_tx_available(s_pending_tx_available),
        .credit_rtn_done(s_credit_rtn_done),

        //credit init req from FDI interface
        .credit_init_req(s_credit_init_req),
        .credit_init_done(s_credit_init_done)
        );


   axfdi_depacketizer
     #(
       .fdi_flit_width(fdi_data_w),
       .axi_data_w(axi_data_w),
       .axi_burst_len_w (axi_len_w),
       .axi_burst_type_w (axi_burst_w),
       .axi_burst_size_w (axi_size_w),
       .axi_resp_w(axi_resp_w),
       .axi_addr_w(axi_addr_w),
       .axi_wstrb_w(axi_wstrb_w),
       .axi_id_w(axi_id_w),
       .credit_size(credit_size),
       .rtn_vcn_w(rtn_vcn_w),
       .vcn_w(vcn_w)
       ) u_axfdi_depacketizer
       (
        //clock and reset
        .fdi_clk(fdi_clk_i),
        .fdi_rst_n(fdi_rst_n_i),
        .por_n(por_n_i), //global reset

        .flit_rx_data(s_flit_rx_data),
        .flit_rx_data_valid(s_flit_rx_data_valid),
        .fdi_depktr_rx_startofpkt(s_fdi_depktr_rx_startofpkt),
        .fdi_depktr_rx_endofpkt(s_fdi_depktr_rx_endofpkt),
        .fdi_depktr_rx_trdy(s_fdi_depktr_rx_trdy),

        //signals to the credit manager
        .depktr_crdtmgr_credit_vcn(s_depktr_crdtmgr_credit_vcn),//credit_rtn_vcn
        .depktr_crdtmgr_credit_cnt(s_depktr_crdtmgr_credit_cnt),
        .depktr_crdtmgr_rtn_valid(s_depktr_crdtmgr_rtn_valid),
        .depktr_crdtmgr_credit_rx_incr(s_depktr_crdtmgr_credit_rx_incr),
        .depktr_crdtmgr_rx_vcn(s_depktr_crdtmgr_rx_vcn), //vcn from header

        //signals to the port router
        .depktr_portrtr_axi_data(s_depktr_portrtr_axi_data),
        .depktr_portrtr_axi_burst_len(s_depktr_portrtr_axi_burst_len),
        .depktr_portrtr_axi_burst_type(s_depktr_portrtr_axi_burst_type),
        .depktr_portrtr_axi_burst_size(s_depktr_portrtr_axi_burst_size),
        .depktr_portrtr_axi_resp(s_depktr_portrtr_axi_resp),
        .depktr_portrtr_axi_addr(s_depktr_portrtr_axi_addr),
        .depktr_portrtr_axi_wstrb(s_depktr_portrtr_axi_wstrb),
        .portrtr_depktr_bakpres(s_portrtr_depktr_bakpres),
        .depktr_portrtr_flit_startofpkt(s_depktr_portrtr_flit_startofpkt),
        .depktr_portrtr_flit_endofpkt(s_depktr_portrtr_flit_endofpkt),
        .portrtr_depktr_read_done(s_portrtr_depktr_read_done), //indicating port router has performed read
        .depktr_portrtr_write_req_valid(s_depktr_portrtr_write_req_valid),
        .depktr_portrtr_read_req_valid(s_depktr_portrtr_read_req_valid),
        .depktr_portrtr_write_resp_valid(s_depktr_portrtr_write_resp_valid),
        .depktr_portrtr_read_resp_valid(s_depktr_portrtr_read_resp_valid),
        .depktr_portrtr_port_id(s_depktr_portrtr_port_id),
        .depktr_portrtr_txn_id(s_depktr_portrtr_txn_id),

        //signals completion tracker
        .depktr_cmpltkr_resp_valid(s_depktr_cmpltkr_resp_valid),
        .depktr_cmpltkr_vcn(s_depktr_cmpltkr_vcn),
        .depktr_cmpltkr_txn_id(s_depktr_cmpltkr_txn_id),
        .cmpltkr_depktr_port_id(s_cmpltkr_depktr_port_id),
        .cmpltkr_depktr_port_id_valid(s_cmpltkr_depktr_port_id_valid)

        );
   //PORT0 MGR
   axfdi_axi_mgr
     #(
       .AXI_DATA_W(axi_data_w),
       .AXI_ADDR_W(axi_addr_w),
       .AXI_ID_W(axi_id_w),
       .AW_DEPTH(AW_DEPTH),
       .W_DEPTH(W_DEPTH),
       .AR_DEPTH(AR_DEPTH),
       .AW_W(AW_W),
       .W_W(W_W),
       .AR_W(AR_W),
       .B_W(B_W),
       .R_W(R_W)
       )u_axfdi_axi_mgr0
       (
        // clock and reset
        .axi_clk(axi_clk_i),
        .axi_rst_n(axi_rst_n_i),
        // Write Address Channel
        .awaddr(PORT0_MGR_awaddr),
        .awid(PORT0_MGR_awid),
        .awlen(PORT0_MGR_awlen),
        .awsize(PORT0_MGR_awsize),
        .awburst(PORT0_MGR_awburst),
        .awvalid(PORT0_MGR_awvalid),
        .awready(PORT0_MGR_awready),

        // Write Data Channel
        .wdata(PORT0_MGR_wdata),
        .wstrb(PORT0_MGR_wstrb),
        .wlast(PORT0_MGR_wlast),
        .wvalid(PORT0_MGR_wvalid),
        .wready(PORT0_MGR_wready),

        // Write Response Channel
        .bid(PORT0_MGR_bid),
        .bresp(PORT0_MGR_bresp),
        .bvalid(PORT0_MGR_bvalid),
        .bready(PORT0_MGR_bready),

        // Read Address Channel
        .araddr(PORT0_MGR_araddr),
        .arid(PORT0_MGR_arid),
        .arlen(PORT0_MGR_arlen),
        .arsize(PORT0_MGR_arsize),
        .arburst(PORT0_MGR_arburst),
        .arvalid(PORT0_MGR_arvalid),
        .arready(PORT0_MGR_arready),

        // Read Data Channel
        .rdata(PORT0_MGR_rdata),
        .rid(PORT0_MGR_rid),
        .rresp(PORT0_MGR_rresp),
        .rlast(PORT0_MGR_rlast),
        .rvalid(PORT0_MGR_rvalid),
        .rready(PORT0_MGR_rready),

        // CDC to mng
        .AW_cdc_data(s_port0_mgr_cdc_aw_d_out),
        .AW_cdc_empty(s_port0_mgr_cdc_aw_d_empty),
        .AW_cdc_rd_en(s_port0_mgr_cdc_aw_d_rd_en),

        .W_cdc_data(s_port0_mgr_cdc_w_d_out),
        .W_cdc_empty(s_port0_mgr_cdc_w_d_empty),
        .W_cdc_rd_en(s_port0_mgr_cdc_w_d_rd_en),

        .AR_cdc_data(s_port0_mgr_cdc_ar_d_out),
        .AR_cdc_empty(s_port0_mgr_cdc_ar_d_empty),
        .AR_cdc_rd_en(s_port0_mgr_cdc_ar_d_rd_en),

        .R_cdc_data(s_port0_mgr_cdc_r_d),
        .R_cdc_full(s_port0_mgr_cdc_r_d_full),
        .R_cdc_wr_en(s_port0_mgr_cdc_r_d_wr_en),

        .B_cdc_data(s_port0_mgr_cdc_b_d),
        .B_cdc_full(s_port0_mgr_cdc_b_d_full),
        .B_cdc_wr_en(s_port0_mgr_cdc_b_d_wr_en)
        );


   axfdi_axi_mgr
     #(
       .AXI_DATA_W(axi_data_w),
       .AXI_ADDR_W(axi_addr_w),
       .AXI_ID_W(axi_id_w),
       .AW_DEPTH(AW_DEPTH),
       .W_DEPTH(W_DEPTH),
       .AR_DEPTH(AR_DEPTH),
       .AW_W(AW_W),
       .W_W(W_W),
       .AR_W(AR_W),
       .B_W(B_W),
       .R_W(R_W)
       ) u_axfdi_axi_mgr1
       (
        // clock and reset
        .axi_clk(axi_clk_i),
        .axi_rst_n(axi_rst_n_i),

        // Write Address Channel
        .awaddr(PORT1_MGR_awaddr),
        .awid(PORT1_MGR_awid),
        .awlen(PORT1_MGR_awlen),
        .awsize(PORT1_MGR_awsize),
        .awburst(PORT1_MGR_awburst),
        .awvalid(PORT1_MGR_awvalid),
        .awready(PORT1_MGR_awready),

        // Write Data Channel
        .wdata(PORT1_MGR_wdata),
        .wstrb(PORT1_MGR_wstrb),
        .wlast(PORT1_MGR_wlast),
        .wvalid(PORT1_MGR_wvalid),
        .wready(PORT1_MGR_wready),

        // Write Response Channel
        .bid(PORT1_MGR_bid),
        .bresp(PORT1_MGR_bresp),
        .bvalid(PORT1_MGR_bvalid),
        .bready(PORT1_MGR_bready),

        // Read Address Channel
        .araddr(PORT1_MGR_araddr),
        .arid(PORT1_MGR_arid),
        .arlen(PORT1_MGR_arlen),
        .arsize(PORT1_MGR_arsize),
        .arburst(PORT1_MGR_arburst),
        .arvalid(PORT1_MGR_arvalid),
        .arready(PORT1_MGR_arready),

        // Read Data Channel
        .rdata(PORT1_MGR_rdata),
        .rid(PORT1_MGR_rid),
        .rresp(PORT1_MGR_rresp),
        .rlast(PORT1_MGR_rlast),
        .rvalid(PORT1_MGR_rvalid),
        .rready(PORT1_MGR_rready),


        // CDC to mng
        .AW_cdc_data(s_port1_mgr_cdc_aw_d_out),
        .AW_cdc_empty(s_port1_mgr_cdc_aw_d_empty),
        .AW_cdc_rd_en(s_port1_mgr_cdc_aw_d_rd_en),

        .W_cdc_data(s_port1_mgr_cdc_w_d_out),
        .W_cdc_empty(s_port1_mgr_cdc_w_d_empty),
        .W_cdc_rd_en(s_port1_mgr_cdc_w_d_rd_en),

        .AR_cdc_data(s_port1_mgr_cdc_ar_d_out),
        .AR_cdc_empty(s_port1_mgr_cdc_ar_d_empty),
        .AR_cdc_rd_en(s_port1_mgr_cdc_ar_d_rd_en),

        .R_cdc_data(s_port1_mgr_cdc_r_d),
        .R_cdc_full(s_port1_mgr_cdc_r_d_full),
        .R_cdc_wr_en(s_port1_mgr_cdc_r_d_wr_en),

        .B_cdc_data(s_port1_mgr_cdc_b_d),
        .B_cdc_full(s_port1_mgr_cdc_b_d_full),
        .B_cdc_wr_en(s_port1_mgr_cdc_b_d_wr_en)
        );


   axfdi_axi_sub
     #(
       .AXI_DATA_W(axi_data_w),
       .AXI_ADDR_W(axi_addr_w),
       .AXI_ID_W(axi_id_w),
       .AW_DEPTH(AW_DEPTH),
       .W_DEPTH(W_DEPTH),
       .AR_DEPTH(AR_DEPTH),
       .AW_W(AW_W),
       .W_W(W_W),
       .AR_W(AR_W),
       .B_W(B_W),
       .R_W(R_W)
       ) u_axfdi_axi_sub0
       (
        // clock and reset
        .axi_clk(axi_clk_i),
        .axi_rst_n(axi_rst_n_i),
        // Write Address Channel
        .awaddr(PORT0_SUB_awaddr),
        .awid(PORT0_SUB_awid),
        .awlen(PORT0_SUB_awlen),
        .awsize(PORT0_SUB_awsize),
        .awburst(PORT0_SUB_awburst),
        .awvalid(PORT0_SUB_awvalid),
        .awready(PORT0_SUB_awready),

        // Write Data Channel
        .wdata(PORT0_SUB_wdata),
        .wstrb(PORT0_SUB_wstrb),
        .wlast(PORT0_SUB_wlast),
        .wvalid(PORT0_SUB_wvalid),
        .wready(PORT0_SUB_wready),

        // Write Response Channel
        .bid(PORT0_SUB_bid),
        .bresp(PORT0_SUB_bresp),
        .bvalid(PORT0_SUB_bvalid),
        .bready(PORT0_SUB_bready),

        // Read Address Channel
        .araddr(PORT0_SUB_araddr),
        .arid(PORT0_SUB_arid),
        .arlen(PORT0_SUB_arlen),
        .arsize(PORT0_SUB_arsize),
        .arburst(PORT0_SUB_arburst),
        .arvalid(PORT0_SUB_arvalid),
        .arready(PORT0_SUB_arready),

        // Read Data Channel
        .rdata(PORT0_SUB_rdata),
        .rid(PORT0_SUB_rid),
        .rresp(PORT0_SUB_rresp),
        .rlast(PORT0_SUB_rlast),
        .rvalid(PORT0_SUB_rvalid),
        .rready(PORT0_SUB_rready),



        // CDC FIFO ports — TX side
        .AW_cdc_full(s_port0_sub_cdc_aw_d_full),
        .AW_cdc_data(s_port0_sub_cdc_aw_d),    // {awid,awlen,awburst,awsize,awaddr}
        .AW_cdc_wr_en(s_port0_sub_cdc_aw_d_wr_en),
        .W_cdc_full(s_port0_sub_cdc_w_d_full),
        .W_cdc_data(s_port0_sub_cdc_w_d),     // {wdata,wstrb,wlast}
        .W_cdc_wr_en(s_port0_sub_cdc_w_d_wr_en),

        .AR_cdc_full(s_port0_sub_cdc_ar_d_full),
        .AR_cdc_data(s_port0_sub_cdc_ar_d),    // {arid,arlen,arburst,arsize,araddr}
        .AR_cdc_wr_en(s_port0_sub_cdc_ar_d_wr_en),

        // CDC FIFO ports — RX side
        .B_cdc_empty(s_port0_sub_cdc_b_d_empty),
        .B_cdc_data(s_port0_sub_cdc_b_d_out),     // {bid,bresp}
        .B_cdc_rd_en(s_port0_sub_cdc_b_d_rd_en),

        .R_cdc_empty(s_port0_sub_cdc_r_d_empty),
        .R_cdc_data(s_port0_sub_cdc_r_d_out),     // {rdata,rid,rresp,rlast}
        .R_cdc_rd_en(s_port0_sub_cdc_r_d_rd_en)
        );


   axfdi_axi_sub
     #(
       .AXI_DATA_W(axi_data_w),
       .AXI_ADDR_W(axi_addr_w),
       .AXI_ID_W(axi_id_w),
       .AW_DEPTH(AW_DEPTH),
       .W_DEPTH(W_DEPTH),
       .AR_DEPTH(AR_DEPTH),
       .AW_W(AW_W),
       .W_W(W_W),
       .AR_W(AR_W),
       .B_W(B_W)
       ) u_axfdi_axi_sub1
       (
        // clock and reset
        .axi_clk(axi_clk_i),
        .axi_rst_n(axi_rst_n_i),

        // Write Address Channel
        .awaddr(PORT1_SUB_awaddr),
        .awid(PORT1_SUB_awid),
        .awlen(PORT1_SUB_awlen),
        .awsize(PORT1_SUB_awsize),
        .awburst(PORT1_SUB_awburst),
        .awvalid(PORT1_SUB_awvalid),
        .awready(PORT1_SUB_awready),

        // Write Data Channel
        .wdata(PORT1_SUB_wdata),
        .wstrb(PORT1_SUB_wstrb),
        .wlast(PORT1_SUB_wlast),
        .wvalid(PORT1_SUB_wvalid),
        .wready(PORT1_SUB_wready),

        // Write Response Channel
        .bid(PORT1_SUB_bid),
        .bresp(PORT1_SUB_bresp),
        .bvalid(PORT1_SUB_bvalid),
        .bready(PORT1_SUB_bready),

        // Read Address Channel
        .araddr(PORT1_SUB_araddr),
        .arid(PORT1_SUB_arid),
        .arlen(PORT1_SUB_arlen),
        .arsize(PORT1_SUB_arsize),
        .arburst(PORT1_SUB_arburst),
        .arvalid(PORT1_SUB_arvalid),
        .arready(PORT1_SUB_arready),

        // Read Data Channel
        .rdata(PORT1_SUB_rdata),
        .rid(PORT1_SUB_rid),
        .rresp(PORT1_SUB_rresp),
        .rlast(PORT1_SUB_rlast),
        .rvalid(PORT1_SUB_rvalid),
        .rready(PORT1_SUB_rready),

        // CDC FIFO ports — TX side
        .AW_cdc_full(s_port1_sub_cdc_aw_d_full),
        .AW_cdc_data(s_port1_sub_cdc_aw_d),    // {awid,awlen,awburst,awsize,awaddr}
        .AW_cdc_wr_en(s_port1_sub_cdc_aw_d_wr_en),
        .W_cdc_full(s_port1_sub_cdc_w_d_full),
        .W_cdc_data(s_port1_sub_cdc_w_d),     // {wdata,wstrb,wlast}
        .W_cdc_wr_en(s_port1_sub_cdc_w_d_wr_en),

        .AR_cdc_full(s_port1_sub_cdc_ar_d_full),
        .AR_cdc_data(s_port1_sub_cdc_ar_d),    // {arid,arlen,arburst,arsize,araddr}
        .AR_cdc_wr_en(s_port1_sub_cdc_ar_d_wr_en),

        // CDC FIFO ports — RX side
        .B_cdc_empty(s_port1_sub_cdc_b_d_empty),
        .B_cdc_data(s_port1_sub_cdc_b_d_out),     // {bid,bresp}
        .B_cdc_rd_en(s_port1_sub_cdc_b_d_rd_en),

        .R_cdc_empty(s_port1_sub_cdc_r_d_empty),
        .R_cdc_data(s_port1_sub_cdc_r_d_out),     // {rdata,rid,rresp,rlast}
        .R_cdc_rd_en(s_port1_sub_cdc_r_d_rd_en)
        );
   //CDC FIFO sub0)tx_aw
   cdc_fifo
     #(
       .data_w(cdc_aw_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub0_tx_aw
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_sub_cdc_aw_d_wr_en),
        .rd_en(s_port0_sub_cdc_aw_d_rd_en),
        .data_in(s_port0_sub_cdc_aw_d),
        .data_out(s_port0_sub_cdc_aw_d_out),
        .full(s_port0_sub_cdc_aw_d_full),
        .empty(s_port0_sub_cdc_aw_d_empty)
        );
 // cdc fifo ssub0 t w
   cdc_fifo
     #(
       .data_w(cdc_w_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub0_tx_w
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_sub_cdc_w_d_wr_en),
        .rd_en(s_port0_sub_cdc_w_d_rd_en),
        .data_in(s_port0_sub_cdc_w_d),
        .data_out(s_port0_sub_cdc_w_d_out),
        .full(s_port0_sub_cdc_w_d_full),
        .empty(s_port0_sub_cdc_w_d_empty)
        );

   //cdc fifo sub0 tx ar
   cdc_fifo
     #(
       .data_w(cdc_ar_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub0_tx_ar
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_sub_cdc_ar_d_wr_en),
        .rd_en(s_port0_sub_cdc_ar_d_rd_en),
        .data_in(s_port0_sub_cdc_ar_d),
        .data_out(s_port0_sub_cdc_ar_d_out),
        .full(s_port0_sub_cdc_ar_d_full),
        .empty(s_port0_sub_cdc_ar_d_empty)
        );

   //cdc fifo SUB0_RX_R
   cdc_fifo
     #(
       .data_w(cdc_r_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub0_rx_r
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_sub_cdc_r_d_wr_en),
        .rd_en(s_port0_sub_cdc_r_d_rd_en),
        .data_in(s_port0_sub_cdc_r_d),
        .data_out(s_port0_sub_cdc_r_d_out),
        .full(s_port0_sub_cdc_r_d_full),
        .empty(s_port0_sub_cdc_r_d_empty)
        );
   //CDC FIFO SUB0_RX_B

   cdc_fifo
     #(
       .data_w(cdc_b_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub0_rx_b
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_sub_cdc_b_d_wr_en),
        .rd_en(s_port0_sub_cdc_b_d_rd_en),
        .data_in(s_port0_sub_cdc_b_d),
        .data_out(s_port0_sub_cdc_b_d_out),
        .full(s_port0_sub_cdc_b_d_full),
        .empty(s_port0_sub_cdc_b_d_empty)
        );

   //CDC FIFO sub1)tx_aw
   cdc_fifo
     #(
       .data_w(cdc_aw_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub1_tx_aw
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_sub_cdc_aw_d_wr_en),
        .rd_en(s_port1_sub_cdc_aw_d_rd_en),
        .data_in(s_port1_sub_cdc_aw_d),
        .data_out(s_port1_sub_cdc_aw_d_out),
        .full(s_port1_sub_cdc_aw_d_full),
        .empty(s_port1_sub_cdc_aw_d_empty)
        );
 // cdc fifo ssub1 t w
   cdc_fifo
     #(
       .data_w(cdc_w_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub1_tx_w
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_sub_cdc_w_d_wr_en),
        .rd_en(s_port1_sub_cdc_w_d_rd_en),
        .data_in(s_port1_sub_cdc_w_d),
        .data_out(s_port1_sub_cdc_w_d_out),
        .full(s_port1_sub_cdc_w_d_full),
        .empty(s_port1_sub_cdc_w_d_empty)
        );

   //cdc fifo sub1 tx ar
   cdc_fifo
     #(
       .data_w(cdc_ar_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub1_tx_ar
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_sub_cdc_ar_d_wr_en),
        .rd_en(s_port1_sub_cdc_ar_d_rd_en),
        .data_in(s_port1_sub_cdc_ar_d),
        .data_out(s_port1_sub_cdc_ar_d_out),
        .full(s_port1_sub_cdc_ar_d_full),
        .empty(s_port1_sub_cdc_ar_d_empty)
        );

   //cdc fifo SUB1_RX_R
   cdc_fifo
     #(
       .data_w(cdc_r_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub1_rx_r
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_sub_cdc_r_d_wr_en),
        .rd_en(s_port1_sub_cdc_r_d_rd_en),
        .data_in(s_port1_sub_cdc_r_d),
        .data_out(s_port1_sub_cdc_r_d_out),
        .full(s_port1_sub_cdc_r_d_full),
        .empty(s_port1_sub_cdc_r_d_empty)
        );
   //CDC FIFO SUB1_RX_B

   cdc_fifo
     #(
       .data_w(cdc_b_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_sub1_rx_b
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_sub_cdc_b_d_wr_en),
        .rd_en(s_port1_sub_cdc_b_d_rd_en),
        .data_in(s_port1_sub_cdc_b_d),
        .data_out(s_port1_sub_cdc_b_d_out),
        .full(s_port1_sub_cdc_b_d_full),
        .empty(s_port1_sub_cdc_b_d_empty)
        );


   ///////////////////////////////////////////////
   //                                           //
   //               MGR                         //
   ///////////////////////////////////////////////


   //CDC FIFO mgr0)tx_aw
   cdc_fifo
     #(
       .data_w(cdc_aw_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr0_tx_aw
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_mgr_cdc_aw_d_wr_en),
        .rd_en(s_port0_mgr_cdc_aw_d_rd_en),
        .data_in(s_port0_mgr_cdc_aw_d),
        .data_out(s_port0_mgr_cdc_aw_d_out),
        .full(s_port0_mgr_cdc_aw_d_full),
        .empty(s_port0_mgr_cdc_aw_d_empty)
        );
 // cdc fifo smgr0 t w
   cdc_fifo
     #(
       .data_w(cdc_w_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr0_tx_w
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_mgr_cdc_w_d_wr_en),
        .rd_en(s_port0_mgr_cdc_w_d_rd_en),
        .data_in(s_port0_mgr_cdc_w_d),
        .data_out(s_port0_mgr_cdc_w_d_out),
        .full(s_port0_mgr_cdc_w_d_full),
        .empty(s_port0_mgr_cdc_w_d_empty)
        );

   //cdc fifo mgr0 tx ar
   cdc_fifo
     #(
       .data_w(cdc_ar_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr0_tx_ar
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_mgr_cdc_ar_d_wr_en),
        .rd_en(s_port0_mgr_cdc_ar_d_rd_en),
        .data_in(s_port0_mgr_cdc_ar_d),
        .data_out(s_port0_mgr_cdc_ar_d_out),
        .full(s_port0_mgr_cdc_ar_d_full),
        .empty(s_port0_mgr_cdc_ar_d_empty)
        );

   //cdc fifo MGR0_RX_R
   cdc_fifo
     #(
       .data_w(cdc_r_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr0_rx_r
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_mgr_cdc_r_d_wr_en),
        .rd_en(s_port0_mgr_cdc_r_d_rd_en),
        .data_in(s_port0_mgr_cdc_r_d),
        .data_out(s_port0_mgr_cdc_r_d_out),
        .full(s_port0_mgr_cdc_r_d_full),
        .empty(s_port0_mgr_cdc_r_d_empty)
        );
   //CDC FIFO MGR0_RX_B

   cdc_fifo
     #(
       .data_w(cdc_b_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr0_rx_b
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port0_mgr_cdc_b_d_wr_en),
        .rd_en(s_port0_mgr_cdc_b_d_rd_en),
        .data_in(s_port0_mgr_cdc_b_d),
        .data_out(s_port0_mgr_cdc_b_d_out),
        .full(s_port0_mgr_cdc_b_d_full),
        .empty(s_port0_mgr_cdc_b_d_empty)
        );

   //CDC FIFO mgr1)tx_aw
   cdc_fifo
     #(
       .data_w(cdc_aw_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr1_tx_aw
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_mgr_cdc_aw_d_wr_en),
        .rd_en(s_port1_mgr_cdc_aw_d_rd_en),
        .data_in(s_port1_mgr_cdc_aw_d),
        .data_out(s_port1_mgr_cdc_aw_d_out),
        .full(s_port1_mgr_cdc_aw_d_full),
        .empty(s_port1_mgr_cdc_aw_d_empty)
        );
 // cdc fifo smgr1 t w
   cdc_fifo
     #(
       .data_w(cdc_w_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr1_tx_w
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_mgr_cdc_w_d_wr_en),
        .rd_en(s_port1_mgr_cdc_w_d_rd_en),
        .data_in(s_port1_mgr_cdc_w_d),
        .data_out(s_port1_mgr_cdc_w_d_out),
        .full(s_port1_mgr_cdc_w_d_full),
        .empty(s_port1_mgr_cdc_w_d_empty)
        );

   //cdc fifo mgr1 tx ar
   cdc_fifo
     #(
       .data_w(cdc_ar_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr1_tx_ar
       (
        .clk_wr(axi_clk_i),
        .clk_rd(fdi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_mgr_cdc_ar_d_wr_en),
        .rd_en(s_port1_mgr_cdc_ar_d_rd_en),
        .data_in(s_port1_mgr_cdc_ar_d),
        .data_out(s_port1_mgr_cdc_ar_d_out),
        .full(s_port1_mgr_cdc_ar_d_full),
        .empty(s_port1_mgr_cdc_ar_d_empty)
        );

   //cdc fifo MGR1_RX_R
   cdc_fifo
     #(
       .data_w(cdc_r_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr1_rx_r
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_mgr_cdc_r_d_wr_en),
        .rd_en(s_port1_mgr_cdc_r_d_rd_en),
        .data_in(s_port1_mgr_cdc_r_d),
        .data_out(s_port1_mgr_cdc_r_d_out),
        .full(s_port1_mgr_cdc_r_d_full),
        .empty(s_port1_mgr_cdc_r_d_empty)
        );
   //CDC FIFO MGR1_RX_B

   cdc_fifo
     #(
       .data_w(cdc_b_d_w),
       .depth(cdc_depth),
       .addr_w(cdc_addr_w)
       ) u_cdc_fifo_mgr1_rx_b
       (
        .clk_wr(fdi_clk_i),
        .clk_rd(axi_clk_i),
        .rst(por_n_i),
        .wr_en(s_port1_mgr_cdc_b_d_wr_en),
        .rd_en(s_port1_mgr_cdc_b_d_rd_en),
        .data_in(s_port1_mgr_cdc_b_d),
        .data_out(s_port1_mgr_cdc_b_d_out),
        .full(s_port1_mgr_cdc_b_d_full),
        .empty(s_port1_mgr_cdc_b_d_empty)
        );


   axfdi_port_merge u_axfdi_port_merge
     (
      .fdi_clk(fdi_clk_i),
      .fdi_rst_n(fdi_rst_n_i),

      .AW_cdc_fifo_empty_0(s_port0_sub_cdc_aw_d_empty),// sub side port 0
      .W_cdc_fifo_empty_0(s_port0_sub_cdc_w_d_empty),// sub side port 0
      .AR_cdc_fifo_empty_0(s_port0_sub_cdc_ar_d_empty),// sub side port 0
      .R_cdc_fifo_empty_0(s_port0_mgr_cdc_r_d_empty),// mng side  port 0
      .B_cdc_fifo_empty_0(s_port0_mgr_cdc_b_d_empty),// mng side  port 0

      .AW_cdc_fifo_empty_1(s_port1_sub_cdc_aw_d_empty),// sub side port 0
      .W_cdc_fifo_empty_1(s_port1_sub_cdc_w_d_empty),// sub side port 0
      .AR_cdc_fifo_empty_1(s_port1_sub_cdc_ar_d_empty),// sub side port 0
      .R_cdc_fifo_empty_1(s_port1_mgr_cdc_r_d_empty),// mng side  port 0
      .B_cdc_fifo_empty_1(s_port1_mgr_cdc_b_d_empty),// mng side  port 0

      .eop(s_fdi_pktr_eop), // end of packet form the packetizer
      .crd_rtn(s_credit_rtn_opcode_en), // credit return

      .port_id(s_portmrg_arb_port_id),
      .write_req_vaild(s_portmrg_arb_write_req_vaild),
      .read_req_vaild(s_portmrg_arb_read_req_vaild),
      .write_resp_vaild(s_portmrg_arb_write_resp_vaild),
      .read_resp_vaild(s_portmrg_arb_read_resp_vaild),
      // output logic  [1:0] vcn_sel  // 00 - NP , 01 - CPL , 10 -  VC_NP_HI  , 11 -VC_CPL_HI
      .pending_tx_available(s_pending_tx_available)
      );

 
   axfdi_tx_arb u_axfdi_tx_arb
     (
      .fdi_clk(fdi_clk_i),
      .fdi_rst_n(fdi_rst_n_i),
      //signals from the port merge
      .port_id_i(s_portmrg_arb_port_id),
      .write_req_vaild(s_portmrg_arb_write_req_vaild),
      .read_req_vaild(s_portmrg_arb_read_req_vaild),
      .write_resp_vaild(s_portmrg_arb_write_resp_vaild),
      .read_resp_vaild(s_portmrg_arb_read_resp_vaild),
      // from the packetizer
      .eop(s_fdi_pktr_eop),
      // from the csr
      .vcn_np_weig(4'h2),
      .vcn_cpl_weig(4'h1),
      // from the credit manager
      .tx_vc_cpl_credit_ind(s_tx_vc_cpl_credit_ind),
      .tx_vc_np_credit_ind(s_tx_vc_np_credit_ind),
      //input logic    vcn_hi_np_weig,
      //input logic    vcn_hi_cpl_weig,
      .crd_rtn(s_credit_rtn_opcode_en),
      //ouptut to the packetizer
      .txn_type(s_arb_txn_type),
      .vcn_sel(s_arb_vcn_sel),
      .port_id_o(s_arb_port_id)
      );

   axfdi_packetizer
     #(
       .FDI_FLIT_WIDTH(fdi_data_w),
       .credit_size(credit_size),
       .rtn_vcn_w(rtn_vcn_w),
       .vcn_w(vcn_w),
       .AW_AR_DATA_W(cdc_ar_d_w),
       .W_DATA_W(cdc_w_d_w),
       .R_DATA_W(cdc_r_d_w),
       .B_DATA_W(cdc_b_d_w)
       ) u_axfdi_packetizer
       (
        .fdi_clk(fdi_clk_i),
        .fdi_rst_n(fdi_rst_n_i),
    // Arbiter
        .txn_type(s_arb_txn_type),
        .vcn_sel(s_arb_vcn_sel),
        .port_id_i(s_arb_port_id),

    // -------- CREDIT MANAGER --------
        .credit_rtn_opcode_en(s_credit_rtn_opcode_en),
        .rx_credit_rtn_cnt(s_rx_credit_rtn_cnt),
        .rx_credit_rtn_vcn(s_rx_credit_rtn_vcn),
        .credit_rtn_piggy_en(s_credit_rtn_piggy_en),

        .tx_credit_vcn(s_tx_credit_vcn),
        .tx_credit_decr_flag(s_tx_credit_decr_flag),

        .credit_rtn_done(s_credit_rtn_done),
    // -------- PORT 0 --------
        .aw_fifo0_data(s_port0_sub_cdc_aw_d_out),
        .aw_fifo0_rd_en(s_port0_sub_cdc_aw_d_rd_en),

        .w_fifo0_data(s_port0_sub_cdc_w_d_out),
        .w_fifo0_rd_en(s_port0_sub_cdc_w_d_rd_en),

        .ar_fifo0_data(s_port0_sub_cdc_ar_d_out),
        .ar_fifo0_rd_en(s_port0_sub_cdc_ar_d_rd_en),

        .r_fifo0_data(s_port0_mgr_cdc_r_d_out),
        .r_fifo0_rd_en(s_port0_mgr_cdc_r_d_rd_en),

        .b_fifo0_data(s_port0_mgr_cdc_b_d_out),
        .b_fifo0_rd_en(s_port0_mgr_cdc_b_d_rd_en),

    // -------- PORT 1 --------
        .aw_fifo1_data(s_port1_sub_cdc_aw_d_out),
        .aw_fifo1_rd_en(s_port1_sub_cdc_aw_d_rd_en),

        .w_fifo1_data(s_port1_sub_cdc_w_d_out),
        .w_fifo1_rd_en(s_port1_sub_cdc_w_d_rd_en),

        .ar_fifo1_data(s_port1_sub_cdc_ar_d_out),
        .ar_fifo1_rd_en(s_port1_sub_cdc_ar_d_rd_en),

        .r_fifo1_data(s_port1_mgr_cdc_r_d_out),
        .r_fifo1_rd_en(s_port1_mgr_cdc_r_d_rd_en),

        .b_fifo1_data(s_port1_mgr_cdc_b_d_out),
        .b_fifo1_rd_en(s_port1_mgr_cdc_b_d_rd_en),
        //signals to completion tracker
        .tx_vcn(s_pktr_cmpltkr_tx_vcn),
        .tx_txn_id(s_pktr_cmpltkr_tx_txn_id),
        .tx_port_id(s_pktr_cmpltkr_tx_port_id),
        .tx_write_done(s_pktr_cmpltkr_tx_write_done),
        .tx_txn_valid(s_pktr_cmpltkr_tx_txn_valid),

    // -------- FDI --------
        .flit_tx_data(s_flit_tx_data),
        .flit_tx_valid(s_flit_tx_data_valid),
        .fdi_tx_sop(s_fdi_pktr_tx_sop),
        .fdi_tx_eop(s_fdi_pktr_tx_eop),
        .fdi_tx_ready(s_flit_tx_ready),
     //eop
        .fdi_pktr_eop(s_fdi_pktr_eop)
);
endmodule
