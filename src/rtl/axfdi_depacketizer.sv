//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-17 00:40
// File Name: axfdi_depacketizer.sv
// Project Name: AXFDI Bridge
// Description: Port router
//
// Last Updated: 2026-04-17 00:40
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module axfdi_depacketizer #(
   parameter fdi_flit_width = 2048,
   parameter axi_data_w = 1024,
   parameter axi_burst_len_w = 8,
   parameter axi_burst_type_w = 2,
   parameter axi_burst_size_w = 3,
   parameter axi_resp_w = 2,
   parameter axi_addr_w = 40,
   parameter axi_wstrb_w = 128,
   parameter axi_id_w = 8,
   parameter credit_size = 6,
   parameter rtn_vcn_w = 2,
   parameter vcn_w = 3,
   parameter cdc_aw_d_w = 61,
   parameter cdc_w_d_w = 1153,
   parameter cdc_ar_d_w = 61,
   parameter cdc_b_d_w = 10,
   parameter cdc_r_d_w = 1035
)(
// clock and reset
   input logic                      fdi_clk,
   input logic                      fdi_rst_n,
   input logic                      por_n, //global reset
   //to the FDI interface
   input logic [fdi_flit_width-1:0] flit_rx_data,
   input logic                      flit_rx_data_valid,
   input logic                      fdi_depktr_rx_startofpkt,
   input logic                      fdi_depktr_rx_endofpkt,
   output logic                     fdi_depktr_rx_trdy,


   //signals to the credit manager
   output logic [rtn_vcn_w-1:0]     depktr_crdtmgr_credit_vcn,//credit_rtn_vcn
   output logic [credit_size-1:0]   depktr_crdtmgr_credit_cnt,
   output logic                     depktr_crdtmgr_rtn_valid,
   output logic                     depktr_crdtmgr_credit_rx_incr,
   output logic [vcn_w-1:0]         depktr_crdtmgr_rx_vcn, //vcn from header

   //signals to the port router
   output logic [cdc_aw_d_w-1:0]    aw_d,
   output logic                     aw_d_valid,
   input logic                      aw_d_ready,
   output logic [cdc_w_d_w-1:0]     w_d,
   output logic                     w_d_valid,
   input logic                      w_d_ready,
   output logic [cdc_ar_d_w-1:0]    ar_d,
   output logic                     ar_d_valid,
   input logic                      ar_d_ready,
   output logic [cdc_b_d_w-1:0]     b_d,
   output logic                     b_d_valid,
   input logic                      b_d_ready,
   output logic [cdc_r_d_w-1:0]     r_d,
   output logic                     r_d_valid,
   input logic                      r_d_ready,
   //input logic                      portrtr_depktr_bakpres, //backpressure from the port router
   output logic                     depktr_portrtr_port_id,
   //signals completion tracker
   output logic                     depktr_cmpltkr_resp_valid,
   output logic                     depktr_cmpltkr_vcn,
   output logic [axi_id_w-1:0]      depktr_cmpltkr_txn_id,
   input logic                      cmpltkr_depktr_port_id
   ) ;

   enum                               logic [2:0] {
                                                   wait_header = 3'h0,
                                                   header_decode = 3'h1,
                                                   stream_data = 3'h2
                                             }CS,NS;

   localparam                         SR_W         = 3712;   // shift register width bits
   localparam                         HEADER_MAX   = 1728;   // 216B inline from header
   localparam                         FILL_FLIT    = 1984;   // 248B from data flit
   localparam                         DRAIN_BITS   = axi_data_w;   // 128B per AXI beat
   //opcode values
   localparam                         OPC_WRITE_REQ  = 4'h0;
   localparam                         OPC_READ_REQ   = 4'h1;
   localparam                         OPC_WRITE_RESP = 4'h2;
   localparam                         OPC_READ_RESP  = 4'h3;
   localparam                         OPC_CREDIT_RTN = 4'h4;
   localparam                         OPC_NOP        = 4'h5;

   //signals or the register values ffrom the flit (flitdata)
   logic [vcn_w-1:0]                  s_flit_vcn;
   logic                              s_flit_sop;
   logic                              s_flit_eop;
   logic [3:0]                        s_flit_opcode;
   logic [axi_id_w-1:0]               s_flit_txn_id;
   logic                              s_flit_port_id;
   logic [axi_burst_len_w-1:0]        s_flit_burst_len;
   logic [axi_burst_type_w-1:0]       s_flit_burst_type;
   logic [axi_burst_size_w-1:0]       s_flit_burst_size;
   logic [axi_resp_w-1:0]             s_flit_resp;
   logic [rtn_vcn_w-1:0]              s_flit_credit_rtn_vcn;
   logic [credit_size-1:0]            s_flit_credit_rtn_cnt;
   logic                              s_flit_wstrb_present;
   logic [axi_addr_w-1:0]             s_flit_addr;
   logic [axi_wstrb_w-1:0]            s_flit_wstrb_b0;
 //  logic [1727:0]                     s_flit_data_line;

   logic [vcn_w-1:0]                  r_flit_vcn;
   logic                              r_flit_sop;
   logic                              r_flit_eop;
   logic [3:0]                        r_flit_opcode;
   logic [axi_id_w-1:0]               r_flit_txn_id;
   logic                              r_flit_port_id;
   logic [axi_burst_len_w-1:0]        r_flit_burst_len;
   logic [axi_burst_type_w-1:0]       r_flit_burst_type;
   logic [axi_burst_size_w-1:0]       r_flit_burst_size;
   logic [axi_resp_w-1:0]             r_flit_resp;
   logic [rtn_vcn_w-1:0]              r_flit_credit_rtn_vcn;
   logic [credit_size-1:0]            r_flit_credit_rtn_cnt;
   logic                              r_flit_wstrb_present;
   logic [axi_addr_w-1:0]             r_flit_addr;
   logic [axi_wstrb_w-1:0]            r_flit_wstrb_b0;
 //  logic [1727:0]                     r_flit_data_line;
   //FDI side signals
   logic                              s_flit_rx_trdy;
   logic                              r_flit_rx_trdy;

   //AXI signals
   logic [cdc_aw_d_w-1:0]             r_aw_d;
   logic                              r_aw_d_valid;
   logic [cdc_w_d_w-1:0]              r_w_d;
   logic                              r_w_d_valid;
   logic [cdc_ar_d_w-1:0]             r_ar_d;
   logic                              r_ar_d_valid;
   logic [cdc_r_d_w-1:0]              r_r_d;
   logic                              r_r_d_valid;
   logic [cdc_b_d_w-1:0]              r_b_d;
   logic                              r_b_d_valid;
   //signal values combinational logic
   logic [cdc_aw_d_w-1:0]             s_aw_d;
   logic                              s_aw_d_valid;
   logic [cdc_w_d_w-1:0]              s_w_d;
   logic                              s_w_d_valid;
   logic [cdc_ar_d_w-1:0]             s_ar_d;
   logic                              s_ar_d_valid;
   logic [cdc_r_d_w-1:0]              s_r_d;
   logic                              s_r_d_valid;
   logic [cdc_b_d_w-1:0]              s_b_d;
   logic                              s_b_d_valid;
   logic                              is_w_rx_en;
   logic                              is_r_rx_en;
   logic                              is_w_rx_en_next;
   logic                              is_r_rx_en_next;
   //axi w channel and r channel signals data
   logic [axi_wstrb_w-1:0]            r_wstrb;
   logic                              r_wlast;
   logic [axi_wstrb_w-1:0]            s_wstrb;
   logic                              s_wlast;
   logic [axi_id_w-1:0]               r_rid;
   logic [axi_resp_w-1:0]             r_rresp;
   logic                              r_rlast;
   logic [axi_id_w-1:0]               s_rid;
   logic [axi_resp_w-1:0]             s_rresp;
   logic                              s_rlast;


   //internal signals
   //credit signals to the depacketizer
   logic                              s_depktr_crdtmgr_rtn_valid;
   logic [rtn_vcn_w-1:0]              s_depktr_crdtmgr_credit_vcn;
   logic [credit_size-1:0]            s_depktr_crdtmgr_credit_cnt;
   logic [vcn_w-1:0]                  s_depktr_crdtmgr_rx_vcn;
   //logic                              r_credit_rtn_en;


   //signals to the completion tracker
   logic                              s_depktr_cmpltkr_resp_valid;
   logic                              s_depktr_cmpltkr_vcn;
   logic [axi_id_w-1:0]               s_depktr_cmpltkr_txn_id;

   //signals to the port router
   logic                              r_port_id;
   logic                              s_port_id;

   //axipacktdone indicator
   logic                              s_axi_packet_done;


   //FOR multi beat support the counter values n
   //signal *_next will the comb logic and others are the reg values
   logic [18:0]                       total_bits;
   logic [18:0]                       total_bits_next;
   logic [18:0]                       header_valid_bits;

//lost+found/   logic [18:0]                       header_valid_bits_next;
   logic [18:0]                       bits_pending;
   logic [18:0]                       bits_drained;
   logic [18:0]                       bits_drained_next;
   logic [18:0]                       fill_bits;
   logic                              drain_en;
   logic                              fill_en;
   logic                              sr_d_valid;
   logic [18:0]                        sr_wr_ptr;
   logic [18:0]                        sr_wr_ptr_next;
   logic [18:0]                       fill_pos;
   //data liesn or the valid signals
   logic [1727:0]                     s_header_flit_data_line;
   logic [1727:0]                     r_header_flit_data_line;
   logic [SR_W-1:0]                   sr;
   logic [SR_W-1:0]                   sr_next;
   logic [SR_W-1:0]                   sr_after_fill;
   logic [SR_W-1:0]                   sr_after_drain;


   //module port  assignment CREDIT_MGR
   assign depktr_crdtmgr_rtn_valid      = s_depktr_crdtmgr_rtn_valid;
   assign depktr_crdtmgr_credit_vcn     = s_depktr_crdtmgr_credit_vcn;
   assign depktr_crdtmgr_credit_cnt     = s_depktr_crdtmgr_credit_cnt;
   assign depktr_crdtmgr_credit_rx_incr = (s_axi_packet_done) ? 1'b1 : 1'b0; //?
   assign depktr_crdtmgr_rx_vcn         = s_depktr_crdtmgr_rx_vcn;

   //module port assignment port router
   assign depktr_portrtr_port_id         = r_port_id;

   //assign startofkt and endofpkt
   assign fdi_depktr_rx_trdy             = s_flit_rx_trdy;
   //module port assignment Completion tracker

   assign depktr_cmpltkr_resp_valid = s_depktr_cmpltkr_resp_valid;
   assign depktr_cmpltkr_vcn        = s_depktr_cmpltkr_vcn;
   assign depktr_cmpltkr_txn_id     = s_depktr_cmpltkr_txn_id;

   assign aw_d = r_aw_d;
   assign aw_d_valid = r_aw_d_valid;
   assign w_d = r_w_d;
   assign w_d_valid = r_w_d_valid;
   assign ar_d = r_ar_d;
   assign ar_d_valid = r_ar_d_valid;
   assign r_d = r_r_d;
   assign r_d_valid = r_r_d_valid;
   assign b_d = r_b_d;
   assign b_d_valid = r_b_d_valid;
   // Statemachine
   always_comb begin
      //data from flits
      s_flit_vcn                  = r_flit_vcn;
      s_flit_sop                  = r_flit_sop;
      s_flit_eop                  = r_flit_eop;
      s_flit_opcode               = r_flit_opcode;
      s_flit_port_id              = r_flit_port_id;
      s_flit_txn_id               = r_flit_txn_id;
      s_flit_burst_len            = r_flit_burst_len;
      s_flit_burst_type           = r_flit_burst_type;
      s_flit_burst_size           = r_flit_burst_size;
      s_flit_resp                 = r_flit_resp;
      s_flit_credit_rtn_vcn       = r_flit_credit_rtn_vcn;
      s_flit_credit_rtn_cnt       = r_flit_credit_rtn_cnt;
      s_flit_addr                 = r_flit_addr;
      s_flit_wstrb_present        = r_flit_wstrb_present;
      s_flit_wstrb_b0             = r_flit_wstrb_b0;
      s_flit_rx_trdy              = r_flit_rx_trdy;
      //bits calculations
      bits_drained_next           = bits_drained;
      total_bits_next             = total_bits;
      bits_pending                = total_bits - bits_drained - sr_wr_ptr;
      fill_bits                   = (bits_pending >= 1984) ? 1984 : bits_pending;
      sr_d_valid                  = (sr_wr_ptr >= 1024 && bits_drained <= total_bits);
      //s_credit_rtn_en           = r_credit_rtn_en;
      //indicating the packt-done
      s_axi_packet_done           = 1'b0;
      //completiontracker
      s_depktr_cmpltkr_resp_valid = 1'b0;
      s_depktr_cmpltkr_vcn        = 1'b0;
      s_depktr_cmpltkr_txn_id     = '0;
      s_port_id                   = r_port_id;
      fill_pos                    =  SR_W - 1 - sr_wr_ptr;
      fill_bits                   = (bits_pending <= FILL_FLIT) ? bits_pending : FILL_FLIT;
      sr_wr_ptr_next              = sr_wr_ptr;
      sr_next                     = sr;
      //asignment for the axi signals
      s_w_d                       = {sr[SR_W-1 -: DRAIN_BITS],r_wstrb,r_wlast};
      s_w_d_valid                 = is_w_rx_en && sr_d_valid;
      s_r_d                       = {sr[SR_W-1 -: DRAIN_BITS],r_rid,r_rresp,r_rlast};
      s_r_d_valid                 = is_r_rx_en && sr_d_valid;
      s_aw_d                      = r_aw_d;
      s_aw_d_valid                = r_aw_d_valid;
      s_ar_d                      = r_ar_d;
      s_ar_d_valid                = r_ar_d_valid;
      s_b_d                       = r_b_d;
      s_b_d_valid                 = r_b_d_valid;
      s_wlast                     = r_wlast;
      s_rlast                     = r_rlast;
      s_wstrb                     = r_wstrb;
      s_rresp                     = r_rresp;
      s_rid                       = r_rid;
      drain_en                    = (s_w_d_valid && w_d_ready) || (s_r_d_valid && r_d_ready);
      fill_en                     = flit_rx_data_valid & (bits_pending>0);
      is_w_rx_en_next             = is_w_rx_en;
      is_r_rx_en_next             = is_r_rx_en;
      //depacktizer signal assignment
      s_depktr_crdtmgr_rtn_valid  = 1'b0;
      s_depktr_crdtmgr_credit_cnt = '0;
      s_depktr_crdtmgr_credit_vcn = '0;
      s_header_flit_data_line     = r_header_flit_data_line;
      s_depktr_crdtmgr_rx_vcn     = r_flit_vcn;
      s_depktr_crdtmgr_rtn_valid  = 1'b0;
      header_valid_bits = '0;
      sr_after_fill = sr;
      sr_after_drain = sr;
      case (CS)
        wait_header: begin
           if (flit_rx_data_valid && fdi_depktr_rx_startofpkt)
             NS                          = header_decode;
           else
             NS                           = wait_header;
           s_flit_vcn                  = flit_rx_data[5:3];
           s_flit_sop                  = flit_rx_data[6];
           s_flit_eop                  = flit_rx_data[7];
           s_flit_opcode               = flit_rx_data[11:8];
           s_flit_port_id              = flit_rx_data[12];
           s_flit_txn_id               = flit_rx_data[20:13];
           s_flit_burst_len            = flit_rx_data[28:21];
           s_flit_burst_type           = flit_rx_data[30:29];
           s_flit_burst_size           = flit_rx_data[33:31];
           s_flit_resp                 = flit_rx_data[35:34];
           s_flit_credit_rtn_vcn       = flit_rx_data[37:36];
           s_flit_credit_rtn_cnt       = flit_rx_data[43:38];
           s_flit_addr                 = flit_rx_data[84:45];
           s_flit_wstrb_present        = flit_rx_data[44];
           if (s_flit_wstrb_present    == 1'b1)
             s_flit_wstrb_b0             = flit_rx_data[255:128];
           else
             s_flit_wstrb_b0             = '1;
           s_header_flit_data_line     = flit_rx_data[1983:256];
           s_flit_rx_trdy              = 1'b1;
           bits_drained_next           = 0;
           sr_next                     = '0;
           s_aw_d                      = '0;
           s_ar_d                      = '0;
           s_b_d                       = '0;
           s_w_d                       = '0;
           s_aw_d_valid                = 1'b0;
           s_ar_d_valid                = 1'b0;
           s_b_d_valid                 = 1'b0;
           s_depktr_cmpltkr_resp_valid = 1'b1;
           s_depktr_cmpltkr_vcn        = s_flit_vcn[0];
           s_depktr_cmpltkr_txn_id     = s_flit_txn_id;
           s_wlast = s_flit_eop;
           s_wlast                     = 1'b0;
           s_rlast                     = 1'b0;
           s_wstrb                     = '0;
           s_rresp                     = '0;
           s_rid                       = '0;
           s_port_id                   = 1'b0;
        end
        header_decode: begin
           bits_drained_next             = 0;
           total_bits_next               = ({11'd0, s_flit_burst_len} << 10) + 19'd1024; // (len +1 *1024)
           sr_next[SR_W-1 -: HEADER_MAX] = s_header_flit_data_line;
           header_valid_bits             = (total_bits_next >= HEADER_MAX && !s_flit_eop) ? HEADER_MAX : total_bits_next;
           sr_wr_ptr_next                = header_valid_bits;
           s_aw_d                        = {s_flit_txn_id,s_flit_burst_len,s_flit_burst_type, s_flit_burst_size,s_flit_addr};
           s_ar_d                        = {s_flit_txn_id,s_flit_burst_len,s_flit_burst_type,s_flit_burst_size,s_flit_addr};
           s_b_d                         = {s_flit_txn_id, s_flit_resp};
           s_aw_d_valid                  = (s_flit_opcode == OPC_WRITE_REQ) ? 1'b1 : 1'b0;
           s_ar_d_valid                  = (s_flit_opcode == OPC_READ_REQ) ? 1'b1 : 1'b0;
           s_b_d_valid                   = (s_flit_opcode == OPC_WRITE_RESP) ? 1'b1 : 1'b0;
           s_depktr_crdtmgr_rtn_valid    = (s_flit_opcode == OPC_CREDIT_RTN) ? 1'b1 :
                                           (s_flit_credit_rtn_cnt !=0) ? 1'b1 :
                                           1'b0;

           s_depktr_crdtmgr_credit_cnt = s_flit_credit_rtn_cnt;
           s_depktr_crdtmgr_credit_vcn = s_flit_credit_rtn_vcn;
           s_depktr_crdtmgr_rx_vcn     = s_flit_vcn;
           is_w_rx_en_next             = (s_flit_opcode == OPC_WRITE_REQ) ? 1'b1 : 1'b0;
           is_r_rx_en_next             = (s_flit_opcode == OPC_READ_REQ) ? 1'b1 : 1'b0;
           s_wlast                     = s_flit_eop;
           s_rlast                     = s_flit_eop;
           s_wstrb                     = s_flit_wstrb_b0;
           s_rresp                     = s_flit_resp;
           s_rid                       = s_flit_txn_id;
           s_port_id                   = (s_flit_opcode == OPC_WRITE_REQ || s_flit_opcode == OPC_READ_REQ) ? s_flit_port_id :
                                         (s_flit_opcode == OPC_WRITE_RESP || s_flit_opcode == OPC_READ_RESP) ? cmpltkr_depktr_port_id :
                                         1'b0;
           if (s_flit_opcode == OPC_CREDIT_RTN)
             NS = wait_header;
           else
             NS = stream_data;
           end
        stream_data: begin
           s_header_flit_data_line = '0;
           //deassert the signals based the wr_en from the cdc fifo
           if (r_aw_d_valid && aw_d_ready)
             s_aw_d_valid = 1'b0;
           if (r_ar_d_valid && ar_d_ready)
             s_ar_d_valid = 1'b0;
           if (r_b_d_valid && b_d_ready) s_b_d_valid = 1'b0;
           //FILLing the shift register
           sr_after_fill = sr;
           s_flit_rx_trdy = (sr_wr_ptr < 1983) ? 1'b1 : 1'b0;
           if (fill_en) sr_after_fill[fill_pos -: FILL_FLIT] = flit_rx_data [FILL_FLIT-1:0];
           //drain logic
           sr_after_drain = (drain_en) ? (sr_after_fill << 1024) : sr_after_fill;
           sr_next = sr_after_drain;
           sr_wr_ptr_next  = sr_wr_ptr
                             +(fill_en ? fill_bits : 0)
                               -(drain_en ? DRAIN_BITS : 0);
           bits_drained_next = bits_drained + (drain_en ? DRAIN_BITS : 0);
           if (bits_drained >= total_bits) begin
              NS = wait_header;
              is_w_rx_en_next = 1'b0;
              is_r_rx_en_next = 1'b0;
              s_axi_packet_done = 1'b1;
           end
        end // case: stream_data
        default:
          NS = wait_header;
      endcase
   end

    always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        CS                      <= wait_header;
        r_port_id               <=  1'b0;
        r_flit_vcn              <= '0;
        r_flit_txn_id           <= '0;
        r_flit_eop              <= 1'b0;
        r_flit_sop              <= 1'b0;
        r_flit_opcode           <= '0;
        r_flit_port_id          <= '0;
        r_flit_burst_len        <= '0;
        r_flit_burst_type       <= '0;
        r_flit_burst_size       <= '0;
        r_flit_resp             <= '0;
        r_flit_credit_rtn_vcn   <= '0;
        r_flit_credit_rtn_cnt   <= '0;
        r_flit_addr             <= '0;
        r_flit_wstrb_b0         <= '0;
        r_flit_wstrb_present    <= '0;
        r_flit_rx_trdy          <= 1'b0;
        r_aw_d_valid            <= 1'b0;
        r_aw_d                  <= '0;
        r_w_d_valid             <= 1'b0;
        r_w_d                   <= '0;
        r_ar_d_valid            <= 1'b0;
        r_ar_d                  <= '0;
        r_b_d_valid             <= 1'b0;
        r_b_d                   <= '0;
        r_r_d_valid             <= 1'b0;
        r_r_d                   <= '0;
        is_w_rx_en              <= 1'b0;
        is_r_rx_en              <= 1'b0;
        sr_wr_ptr               <= '0;
        sr                      <= '0;
        r_wlast                 <= 1'b0;
        r_rlast                 <= 1'b0;
        r_wstrb                 <= '0;
        r_rresp                 <= '0;
        r_rid                   <= '0;
        total_bits              <= '0;
        bits_drained            <= '0;
        r_header_flit_data_line <= '0;
     end
     else begin
        if (!fdi_rst_n) begin
           CS                      <= wait_header;
           r_port_id               <=  1'b0;
           r_flit_vcn              <= '0;
           r_flit_txn_id           <= '0;
           r_flit_eop              <= 1'b0;
           r_flit_sop              <= 1'b0;
           r_flit_opcode           <= '0;
           r_flit_port_id          <= '0;
           r_flit_burst_len        <= '0;
           r_flit_burst_type       <= '0;
           r_flit_burst_size       <= '0;
           r_flit_resp             <= '0;
           r_flit_credit_rtn_vcn   <= '0;
           r_flit_credit_rtn_cnt   <= '0;
           r_flit_addr             <= '0;
           r_flit_wstrb_b0         <= '0;
           r_flit_wstrb_present    <= '0;
           r_flit_rx_trdy          <= 1'b0;
           r_aw_d_valid            <= 1'b0;
           r_aw_d                  <= '0;
           r_w_d_valid             <= 1'b0;
           r_w_d                   <= '0;
           r_ar_d_valid            <= 1'b0;
           r_ar_d                  <= '0;
           r_b_d_valid             <= 1'b0;
           r_b_d                   <= '0;
           r_r_d_valid             <= 1'b0;
           r_r_d                   <= '0;
           is_w_rx_en              <= 1'b0;
           is_r_rx_en              <= 1'b0;
           sr_wr_ptr               <= '0;
           sr                      <= '0;
           r_wlast                 <= 1'b0;
           r_rlast                 <= 1'b0;
           r_wstrb                 <= '0;
           r_rresp                 <= '0;
           r_rid                   <= '0;
           total_bits              <= '0;
           bits_drained            <= '0;
           r_header_flit_data_line <= '0;
        end
        else begin
           CS                      <= NS;
           r_port_id               <= s_port_id;
           r_flit_vcn              <= s_flit_vcn;
           r_flit_eop              <= s_flit_eop;
           r_flit_sop              <= s_flit_sop;
           r_flit_opcode           <= s_flit_opcode;
           r_flit_txn_id           <= s_flit_txn_id;
           r_flit_port_id          <= s_flit_port_id;
           r_flit_burst_len        <= s_flit_burst_len;
           r_flit_burst_type       <= s_flit_burst_type;
           r_flit_burst_size       <= s_flit_burst_size;
           r_flit_resp             <= s_flit_resp;
           r_flit_credit_rtn_vcn   <= s_flit_credit_rtn_vcn;
           r_flit_credit_rtn_cnt   <= s_flit_credit_rtn_cnt;
           r_flit_addr             <= s_flit_addr;
           r_flit_wstrb_b0         <= s_flit_wstrb_b0;
           r_flit_wstrb_present    <= s_flit_wstrb_present;
           r_flit_rx_trdy          <= s_flit_rx_trdy;
           r_aw_d_valid            <= s_aw_d_valid;
           r_aw_d                  <= s_aw_d;
           r_w_d_valid             <= s_w_d_valid;
           r_w_d                   <= s_w_d;
           r_ar_d_valid            <= s_ar_d_valid;
           r_ar_d                  <= s_ar_d;
           r_b_d_valid             <= s_b_d_valid;
           r_b_d                   <= s_b_d;
           r_r_d_valid             <= s_r_d_valid;
           r_r_d                   <= s_r_d;
           is_w_rx_en              <= is_w_rx_en_next;
           is_r_rx_en              <= is_r_rx_en_next;
           sr_wr_ptr               <= sr_wr_ptr_next;
           sr                      <= sr_next;
           r_wlast                 <= s_wlast;
           r_rlast                 <= s_rlast;
           r_wstrb                 <= s_wstrb;
           r_rresp                 <= s_rresp;
           r_rid                   <= s_rid;
           total_bits              <= total_bits_next;
           bits_drained            <= bits_drained_next;
           r_header_flit_data_line <= s_header_flit_data_line;

        end // else: !if(!fdi_rst_n)
     end
endmodule
