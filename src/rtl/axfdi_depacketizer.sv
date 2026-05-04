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
   parameter vcn_w = 3
)(
//clock and reset
  input logic                         fdi_clk,
  input logic                         fdi_rst_n,
  input logic                         por_n, //global reset
  //to the FDI interface
  input logic [fdi_flit_width-1:0]    flit_rx_data,
  input logic                         flit_rx_data_valid,
  input logic                         fdi_depktr_rx_startofpkt,
  input logic                         fdi_depktr_rx_endofpkt,
  output logic                        fdi_depktr_rx_trdy,


  //signals to the credit manager
  output logic [rtn_vcn_w-1:0]        depktr_crdtmgr_credit_vcn,//credit_rtn_vcn
  output logic [credit_size-1:0]      depktr_crdtmgr_credit_cnt,
  output logic                        depktr_crdtmgr_rtn_valid,
  output logic                        depktr_crdtmgr_credit_rx_incr,
  output logic [vcn_w-1:0]            depktr_crdtmgr_rx_vcn, //vcn from header

  //signals to the port router
  output logic [axi_data_w-1:0]       depktr_portrtr_axi_data,
  output logic [axi_burst_len_w-1:0]  depktr_portrtr_axi_burst_len,
  output logic [axi_burst_type_w-1:0] depktr_portrtr_axi_burst_type,
  output logic [axi_burst_size_w-1:0] depktr_portrtr_axi_burst_size,
  output logic [axi_resp_w-1:0]       depktr_portrtr_axi_resp,
  output logic [axi_addr_w-1:0]       depktr_portrtr_axi_addr,
  output logic [axi_wstrb_w-1:0]      depktr_portrtr_axi_wstrb,
  input logic                         portrtr_depktr_bakpres, //backpressure from the port router
  output logic                        depktr_portrtr_flit_endofpkt,
  output logic                        depktr_portrtr_flit_startofpkt,
  input logic                         portrtr_depktr_read_done, //indicating port router has performed read
  output logic                        depktr_portrtr_write_req_valid,
  output logic                        depktr_portrtr_read_req_valid,
  output logic                        depktr_portrtr_write_resp_valid,
  output logic                        depktr_portrtr_read_resp_valid,
  output logic                        depktr_portrtr_port_id,
  output logic [axi_id_w-1:0]         depktr_portrtr_txn_id,
  //signals completion tracker
  output logic                        depktr_cmpltkr_resp_valid,
  output logic                        depktr_cmpltkr_vcn,
  output logic [axi_id_w-1:0]         depktr_cmpltkr_txn_id,
  input logic                         cmpltkr_depktr_port_id,
  input logic                         cmpltkr_depktr_port_id_valid
);

   logic [2:0]                        s_flit_vcn;
   logic                              s_flit_sop;
   logic                              s_flit_eop;
   logic [3:0]                        s_flit_opcode;
   logic [7:0]                        s_flit_txn_id;
   logic                              s_flit_port_id;
   logic [7:0]                        s_flit_burst_len;
   logic [1:0]                        s_flit_burst_type;
   logic [2:0]                        s_flit_burst_size;
   logic [1:0]                        s_flit_resp;
   logic [1:0]                        s_flit_credit_rtn_vcn;
   logic [5:0]                        s_flit_credit_rtn_cnt;
   logic                              s_flit_wstrb_present;
   logic [39:0]                       s_flit_addr;
   logic [127:0]                      s_flit_wstrb_b0;
   logic [1727:0]                     s_flit_data_line;
   logic                              s_flit_endofpkt;
   logic                              s_flit_startofpkt;

   logic [2:0]                        r_flit_vcn;
   logic                              r_flit_sop;
   logic                              r_flit_eop;
   //logic [3:0]                        r_flit_opcode;
   logic [7:0]                        r_flit_txn_id;
   logic                              r_flit_port_id;
   logic [7:0]                        r_flit_burst_len;
   logic [1:0]                        r_flit_burst_type;
   logic [2:0]                        r_flit_burst_size;
   logic [1:0]                        r_flit_resp;
   logic [1:0]                        r_flit_credit_rtn_vcn;
   logic [5:0]                        r_flit_credit_rtn_cnt;
   //logic                              r_flit_wstrb_present;
   logic [39:0]                       r_flit_addr;
   logic [127:0]                      r_flit_wstrb_b0;
   logic [1727:0]                     r_flit_data_line;
   logic                              r_flit_endofpkt;
   logic                              r_flit_startofpkt;


   //opcode enable signal
   logic                              s_write_req_en;
   logic                              s_read_req_en;
   logic                              s_write_resp_en;
   logic                              s_read_resp_en;
   logic                              s_credit_rtn_en;
   logic                              s_nop_en;
   logic                              r_write_req_en;
   logic                              r_read_req_en;
   logic                              r_write_resp_en;
   logic                              r_read_resp_en;
 //  logic                              r_credit_rtn_en;

   //module port  assignment CREDIT_MGR
   assign depktr_crdtmgr_rtn_valid = s_credit_rtn_en | r_write_resp_en | r_write_req_en | r_read_req_en | r_read_resp_en;
   assign depktr_crdtmgr_credit_vcn = r_flit_credit_rtn_vcn;
   assign depktr_crdtmgr_credit_cnt = r_flit_credit_rtn_cnt;
   assign depktr_crdtmgr_credit_rx_incr = (portrtr_depktr_read_done) ? 1'b1 : 1'b0; //?
   assign depktr_crdtmgr_rx_vcn = r_flit_vcn;

   //module port assignment port router
   assign depktr_portrtr_axi_data = r_flit_data_line[1727:704];
   assign depktr_portrtr_axi_burst_len = r_flit_burst_len;
   assign depktr_portrtr_axi_burst_type = r_flit_burst_type;
   assign depktr_portrtr_axi_burst_size = r_flit_burst_size;
   assign depktr_portrtr_axi_resp = r_flit_resp;
   assign depktr_portrtr_axi_addr = r_flit_addr;
   assign depktr_portrtr_axi_wstrb = r_flit_wstrb_b0;
   assign depktr_portrtr_write_req_valid = r_write_req_en;
   assign depktr_portrtr_read_req_valid = r_read_req_en;
   assign depktr_portrtr_write_resp_valid = (cmpltkr_depktr_port_id_valid) ? r_write_resp_en : 1'b0;
   assign depktr_portrtr_read_resp_valid = ( cmpltkr_depktr_port_id_valid) ? r_read_resp_en : 1'b0;
   assign depktr_portrtr_port_id = (r_write_req_en && r_read_req_en) ? r_flit_port_id:
                                   (r_write_resp_en && r_read_resp_en) ? cmpltkr_depktr_port_id:
                                   1'b0;
   assign depktr_portrtr_txn_id = r_flit_txn_id;

   //assign startofkt and endofpkt
   assign depktr_portrtr_flit_endofpkt = r_flit_endofpkt;
   assign depktr_portrtr_flit_startofpkt = r_flit_startofpkt;
   assign fdi_depktr_rx_trdy  = !portrtr_depktr_bakpres;
   //module port assignment Completion tracker

   assign depktr_cmpltkr_resp_valid = s_read_resp_en | s_write_resp_en;
   assign depktr_cmpltkr_vcn = s_flit_vcn[0];
   assign depktr_cmpltkr_txn_id = s_flit_txn_id;

   //internal signal assignment
   assign s_flit_vcn            = (flit_rx_data_valid) ? flit_rx_data[5:3] : '0;
   assign s_flit_sop            = (flit_rx_data_valid) ? flit_rx_data[6] : '0;
   assign s_flit_eop            = (flit_rx_data_valid) ? flit_rx_data[7] : '0;
   assign s_flit_opcode         = (flit_rx_data_valid) ? flit_rx_data[11:8] : '0;
   assign s_flit_port_id        = (flit_rx_data_valid) ? flit_rx_data[12] : '0;
   assign s_flit_txn_id         = (flit_rx_data_valid) ? flit_rx_data[20:13] : '0;
   assign s_flit_burst_len      = (flit_rx_data_valid) ? flit_rx_data[28:21] : '0;
   assign s_flit_burst_type     = (flit_rx_data_valid) ? flit_rx_data[30:29] : '0;
   assign s_flit_burst_size     = (flit_rx_data_valid) ? flit_rx_data[33:31] : '0;
   assign s_flit_resp           = (flit_rx_data_valid) ? flit_rx_data[35:34] : '0;
   assign s_flit_credit_rtn_vcn = (flit_rx_data_valid) ? flit_rx_data[37:36] : '0;
   assign s_flit_credit_rtn_cnt = (flit_rx_data_valid) ? flit_rx_data[43:38] : '0;
   assign s_flit_addr           = (flit_rx_data_valid) ? flit_rx_data[84:45] : '0;
   assign s_flit_wstrb_present  = (flit_rx_data_valid) ? flit_rx_data[44] : '0;
   assign s_flit_wstrb_b0       = (flit_rx_data_valid) ? flit_rx_data[255:128] : '0;
   assign s_flit_data_line      = (flit_rx_data_valid) ? flit_rx_data[1983:256] : '0;
   assign s_flit_startofpkt     = (flit_rx_data_valid) ? fdi_depktr_rx_startofpkt : 1'b0;
   assign s_flit_endofpkt       = (flit_rx_data_valid) ? fdi_depktr_rx_endofpkt : 1'b0;

 always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        r_flit_vcn <= '0;
        r_flit_eop <= 1'b0;
        r_flit_sop <= 1'b0;
        r_flit_txn_id <= '0;
        r_flit_port_id <= '0;
        r_flit_burst_len <= '0;
        r_flit_burst_type <= '0;
        r_flit_burst_size <= '0;
        r_flit_resp <= '0;
        r_flit_credit_rtn_vcn <= '0;
        r_flit_credit_rtn_cnt <= '0;
        r_flit_addr <= '0;
        r_flit_wstrb_b0 <= '0;
        r_flit_data_line <= '0;
        r_write_req_en <= '0;
        r_read_req_en <= '0;
        r_write_resp_en <= '0;
        r_read_resp_en <='0;
        //r_credit_rtn_en <= '0;
        r_flit_endofpkt <= 1'b0;
        r_flit_startofpkt <= 1'b0;
     end
     else begin
        if (!fdi_rst_n) begin
           r_flit_vcn <= '0;
           r_flit_txn_id <= '0;
           r_flit_eop <= 1'b0;
           r_flit_sop <= 1'b0;
           r_flit_port_id <= '0;
           r_flit_burst_len <= '0;
           r_flit_burst_type <= '0;
           r_flit_burst_size <= '0;
           r_flit_resp <= '0;
           r_flit_credit_rtn_vcn <= '0;
           r_flit_credit_rtn_cnt <= '0;
           r_flit_addr <= '0;
           r_flit_wstrb_b0 <= '0;
           r_flit_data_line <= '0;
           r_write_req_en <= '0;
           r_read_req_en <= '0;
           r_write_resp_en <= '0;
           r_read_resp_en <='0;
           r_credit_rtn_en <= '0;
           r_flit_endofpkt <= 1'b0;
           r_flit_startofpkt <= 1'b0;
        end
        else begin
           r_credit_rtn_en <= s_credit_rtn_en;
           r_flit_vcn <= s_flit_vcn;
           r_flit_eop <= s_flit_eop;
           r_flit_sop <= s_flit_sop;
           r_flit_txn_id <= s_flit_txn_id;
           r_flit_port_id  <= s_flit_port_id;
           r_flit_burst_len <= s_flit_burst_len;
           r_flit_burst_type <= s_flit_burst_type;
           r_flit_burst_size <= s_flit_burst_size;
           r_flit_resp <= s_flit_resp;
           r_flit_credit_rtn_vcn <= s_flit_credit_rtn_vcn;
           r_flit_credit_rtn_cnt <= s_flit_credit_rtn_cnt;
           r_flit_addr <= s_flit_addr;
           if (s_flit_wstrb_present) r_flit_wstrb_b0 <= s_flit_wstrb_b0;
           else r_flit_wstrb_b0 <= '1;
           r_flit_data_line <= s_flit_data_line;
           r_write_req_en <= s_write_req_en;
           r_read_req_en <= s_read_req_en;
           r_write_resp_en <= s_write_resp_en;
           r_read_resp_en <= s_read_resp_en;
           r_flit_endofpkt <= s_flit_endofpkt;
           r_flit_startofpkt <= s_flit_startofpkt;
        /* -----\/----- EXCLUDED -----\/-----
           if (portrtr_depktr_read_done) begin
              r_flit_vcn <= '0;
              r_flit_txn_id <= '0;
              r_flit_eop <= 1'b0;
              r_flit_sop <= 1'b0;
              r_flit_port_id <= '0;
              r_flit_burst_len <= '0;
              r_flit_burst_type <= '0;
              r_flit_burst_size <= '0;
              r_flit_resp <= '0;
              r_flit_credit_rtn_vcn <= '0;
              r_flit_credit_rtn_cnt <= '0;
              r_flit_addr <= '0;
              r_flit_wstrb_b0 <= '0;
              r_flit_data_line <= '0;
              r_write_req_en <= '0;
              r_read_req_en <= '0;
              r_write_resp_en <= '0;
              r_read_resp_en <='0;
           end
 -----/\----- EXCLUDED -----/\----- */
        end
     end // else: !if(!por_n)

   always_comb begin
      s_write_req_en = 1'b0;
      s_read_req_en =  1'b0;
      s_write_resp_en = 1'b0;
      s_read_resp_en = 1'b0;
      s_credit_rtn_en = 1'b0;
      s_nop_en = 1'b0;
      if (flit_rx_data_valid) begin
        case(s_flit_opcode)
          4'b0000:s_write_req_en = 1'b1;
          4'b0001:s_read_req_en = 1'b1;
          4'b0010:s_write_resp_en = 1'b1;
          4'b0011:s_read_resp_en = 1'b1;
          4'b0100:s_credit_rtn_en = 1'b1;
          4'b0101: s_nop_en = 1'b1;
        default: s_nop_en = 1'b1;
        endcase // case (s_flit_opcode)
      end // if (flit_rx_data_valid)
      else begin
         s_write_req_en = 1'b0;
         s_read_req_en =  1'b0;
         s_write_resp_en = 1'b0;
         s_read_resp_en = 1'b0;
         s_credit_rtn_en = 1'b0;
      end
   end
endmodule
