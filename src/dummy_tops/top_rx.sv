//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-18 17:59
// File Name: top_rx.sv
// Project Name: Project name
// Description: Short description
//
// Last Updated: 2026-04-18 17:59
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module top_rx
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
  parameter completion_tracker_w = 256
  )(
  input logic                     fdi_clk_i,
  //input logic axi_clk_i,
  input logic                     por_n_i,
  //input logic axi_rst_n_i,
  input logic                     fdi_rst_n_i,

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
  input logic                     fdi_pl_inband_pres,
  //port0 CDC signals
  output logic [cdc_aw_d_w-1:0]   port0_cdc_aw_d,
  output logic                    port0_cdc_aw_d_wr_en,
  input logic                     port0_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]    port0_cdc_w_d,
  output logic                    port0_cdc_w_d_wr_en,
  input logic                     port0_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0]   port0_cdc_ar_d,
  output logic                    port0_cdc_ar_d_wr_en,
  input logic                     port0_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]    port0_cdc_b_d,
  output logic                    port0_cdc_b_d_wr_en,
  input logic                     port0_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]    port0_cdc_r_d,
  output logic                    port0_cdc_r_d_wr_en,
  input logic                     port0_cdc_r_d_full,
  //port1 CDC signals
  output logic [cdc_aw_d_w-1:0]   port1_cdc_aw_d,
  output logic                    port1_cdc_aw_d_wr_en,
  input logic                     port1_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]    port1_cdc_w_d,
  output logic                    port1_cdc_w_d_wr_en,
  input logic                     port1_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0]   port1_cdc_ar_d,
  output logic                    port1_cdc_ar_d_wr_en,
  input logic                     port1_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]    port1_cdc_b_d,
  output logic                    port1_cdc_b_d_wr_en,
  input logic                     port1_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]    port1_cdc_r_d,
  output logic                    port1_cdc_r_d_wr_en,
  input logic                     port1_cdc_r_d_full,
  output logic                    tx_vc_cpl_credit_ind,
  output logic                    tx_vc_np_credit_ind
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
   //From depacker to port router
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

        .port0_cdc_aw_d(port0_cdc_aw_d),
        .port0_cdc_aw_d_wr_en(port0_cdc_aw_d_wr_en),
        .port0_cdc_aw_d_full(port0_cdc_aw_d_full),
        .port0_cdc_w_d(port0_cdc_w_d),
        .port0_cdc_w_d_wr_en(port0_cdc_w_d_wr_en),
        .port0_cdc_w_d_full(port0_cdc_w_d_full),
        .port0_cdc_ar_d(port0_cdc_ar_d),
        .port0_cdc_ar_d_wr_en(port0_cdc_ar_d_wr_en),
        .port0_cdc_ar_d_full(port0_cdc_ar_d_full),
        .port0_cdc_b_d(port0_cdc_b_d),
        .port0_cdc_b_d_wr_en(port0_cdc_b_d_wr_en),
        .port0_cdc_b_d_full(port0_cdc_b_d_full),
        .port0_cdc_r_d(port0_cdc_r_d),
        .port0_cdc_r_d_wr_en(port0_cdc_r_d_wr_en),
        .port0_cdc_r_d_full(port0_cdc_r_d_full),
        .port1_cdc_aw_d(port1_cdc_aw_d),
        .port1_cdc_aw_d_wr_en(port1_cdc_aw_d_wr_en),
        .port1_cdc_aw_d_full(port1_cdc_aw_d_full),
        .port1_cdc_w_d(port1_cdc_w_d),
        .port1_cdc_w_d_wr_en(port1_cdc_w_d_wr_en),
        .port1_cdc_w_d_full(port1_cdc_w_d_full),
        .port1_cdc_ar_d(port1_cdc_ar_d),
        .port1_cdc_ar_d_wr_en(port1_cdc_ar_d_wr_en),
        .port1_cdc_ar_d_full(port1_cdc_ar_d_full),
        .port1_cdc_b_d(port1_cdc_b_d),
        .port1_cdc_b_d_wr_en(port1_cdc_b_d_wr_en),
        .port1_cdc_b_d_full(port1_cdc_b_d_full),
        .port1_cdc_r_d(port1_cdc_r_d),
        .port1_cdc_r_d_wr_en(port1_cdc_r_d_wr_en),
        .port1_cdc_r_d_full(port1_cdc_r_d_full)
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
        .tx_vc_cpl_credit_ind(tx_vc_cpl_credit_ind),
        .tx_vc_np_credit_ind(tx_vc_np_credit_ind),
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

endmodule
