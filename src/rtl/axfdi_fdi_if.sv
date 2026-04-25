//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-17 00:38
// File Name: axfdi_fdi_if.sv
// Project Name: AXFDI Bridge
// Description: Flit Die-to-Die Interface
//
// Last Updated: 2026-04-17 00:38
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module axfdi_fdi_if #(
  parameter fdi_flit_width = 2048
)(
  //clock and reset wires
  input logic                       fdi_clk,
  input logic                       por_n,
  input logic                       fdi_rst_n,

  //TX side
  output logic [fdi_flit_width-1:0] fdi_lp_data,
  output logic                      fdi_lp_valid,
  output logic                      fdi_lp_irdy,
  output logic                      fdi_lp_startofpkt,
  output logic                      fdi_lp_endofpkt,
  input logic                       fdi_pl_trdy,
  output logic [2:0]                fdi_lp_state_req,
  output logic                      fdi_lp_linkerror,


  //RX side
  input logic [fdi_flit_width-1:0]  fdi_pl_data,
  input logic                       fdi_pl_valid,
  input logic                       fdi_pl_irdy,
  input logic                       fdi_pl_startofpkt,
  input logic                       fdi_pl_endofpkt,
  output logic                      fdi_lp_trdy,
  input logic [2:0]                 fdi_pl_state_sts,
  input logic                       fdi_pl_inband_pres,

  //to the DUT
  input logic [fdi_flit_width-1:0]  flit_tx_data,
  input logic                       flit_tx_data_valid,
  input logic                       fdi_pktr_tx_sop,
  input logic                       fdi_pktr_tx_eop,
  output logic                      fdi_tx_ready,

  output logic [fdi_flit_width-1:0] flit_rx_data,
  output logic                      flit_rx_data_valid,
  input logic                       fdi_depktr_rx_trdy,
  output logic                      fdi_depktr_rx_startofpkt,
  output logic                      fdi_depktr_rx_endofpkt,
  
  //credit signals
  output logic                      credit_init_req,
  input logic                       credit_init_done
  );

   //statemachine states
   enum                             logic [2:0] {
                                            ST_wait_remote,
                                            ST_req_active,
                                            ST_credit_init,
                                            ST_TX_RX
                                           }CS,NS;
   typedef enum                     logic [2:0] {
                                                 RESET = 3'h0,
                                                 INIT = 3'h1,
                                                 ACTIVE = 3'h2,
                                                 IDLE = 3'h3,
                                                 RECOVERY = 3'h4
                                                 }link_state;


   //wires
   link_state                       s_fdi_lp_state_req;
   //logic                            s_fdi_lp_linkerror;


   logic [fdi_flit_width-1:0]        r_fdi_lp_data;
   logic                             r_fdi_lp_irdy;
   logic                             r_fdi_lp_valid;
   logic                             r_fdi_lp_startofpkt;
   logic                             r_fdi_lp_endofpkt;
   link_state                        r_fdi_lp_state_req;


   //RX side regs
   logic [fdi_flit_width-1:0]        r_fdi_pl_data;
   logic                             r_fdi_lp_trdy;
   logic                             r_fdi_pl_startofpkt;
   logic                             r_fdi_pl_endofpkt;
   logic                             r_flit_rx_data_valid;

   //credit managing local signals
   logic                             s_credit_rtn_req_en; //init creditrtn
   logic                             r_credit_rtn_req_en;

   //FDI interface control flag
   logic                             s_fdi_trans_en;
   logic                             r_fdi_trans_en;


   //TXside data sending
   always_ff@(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        r_fdi_lp_irdy <= 1'b0;
        r_fdi_lp_valid <= 1'b0;
        r_fdi_lp_data <= 'h0;
        r_fdi_lp_startofpkt <= 1'b0;
        r_fdi_lp_endofpkt <= 1'b0;
     end
       else begin
          if (!fdi_rst_n) begin
             r_fdi_lp_irdy <= 1'b0;
             r_fdi_lp_valid <= 1'b0;
             r_fdi_lp_data <= 'h0;
             r_fdi_lp_startofpkt <= 1'b0;
             r_fdi_lp_endofpkt <= 1'b0;
          end
          else begin
             r_fdi_lp_data <= flit_tx_data;
             r_fdi_lp_valid <= flit_tx_data_valid;
             r_fdi_lp_startofpkt <= fdi_pktr_tx_sop;
             r_fdi_lp_endofpkt <= fdi_pktr_tx_eop;
             if (r_fdi_trans_en) r_fdi_lp_irdy <= 1'b1;  //??
             else r_fdi_lp_irdy <= 1'b0;
          end
       end // else: !if(!fdi_rstn)

   //module assign on the local protocol to adapter
   assign fdi_lp_data = r_fdi_lp_data;
   assign fdi_lp_irdy = r_fdi_lp_irdy;
   assign fdi_lp_valid = r_fdi_lp_valid;
   assign fdi_lp_startofpkt = r_fdi_lp_startofpkt;
   assign fdi_lp_endofpkt = r_fdi_lp_endofpkt;
   assign fdi_lp_trdy = r_fdi_lp_trdy;
   assign fdi_lp_state_req = r_fdi_lp_state_req;

   //drive link erro
   assign fdi_lp_linkerror = 1'b0;

   //module assign on the to the bridge on the RX side
   assign flit_rx_data_valid = r_flit_rx_data_valid;
   assign flit_rx_data = r_fdi_pl_data;
   assign fdi_depktr_rx_endofpkt = r_fdi_pl_endofpkt;
   assign fdi_depktr_rx_startofpkt = r_fdi_pl_startofpkt;

   //packetizer signal
   assign fdi_tx_ready = fdi_pl_trdy;
   //initial credit iniitalization
   assign credit_init_req =  r_credit_rtn_req_en;

   // RX side data recieving
   always_ff@(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
           r_fdi_pl_data <= '0;
           r_fdi_pl_startofpkt <= 1'b0;
           r_fdi_pl_endofpkt <= 1'b0;
        r_flit_rx_data_valid <= 1'b0;
     end
     else begin
        if (!fdi_rst_n) begin
           r_fdi_pl_data <= '0;
           r_fdi_pl_startofpkt <= 1'b0;
           r_fdi_pl_endofpkt <= 1'b0;
        r_flit_rx_data_valid <= 1'b0;
        end
        else if (fdi_pl_irdy && r_fdi_lp_trdy && fdi_pl_valid && r_fdi_trans_en) begin
           r_fdi_pl_data <= fdi_pl_data;
           r_fdi_pl_startofpkt <= fdi_pl_startofpkt;
           r_fdi_pl_endofpkt <= fdi_pl_endofpkt;
           r_flit_rx_data_valid <= 1'b1;
        end
        else begin
           r_fdi_pl_data <= 0;
           r_fdi_pl_startofpkt <= 1'b0;
           r_fdi_pl_endofpkt <= 1'b0;
           r_flit_rx_data_valid <= 1'b0;
        end
     end // else: !if(!fdi_rstn)

   always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n)begin
        CS <= ST_wait_remote;
        r_fdi_trans_en <= 1'b0;
        r_credit_rtn_req_en <= 1'b0;
        r_fdi_lp_state_req <= RESET;
        r_fdi_lp_trdy <= 1'b0;
     end
     else begin
        if (!fdi_rst_n) begin
           CS <= ST_wait_remote;
           r_fdi_trans_en <= 1'b0;
           r_credit_rtn_req_en <= 1'b0;
           r_fdi_lp_state_req <= RESET;
           r_fdi_lp_trdy <= 1'b0;
        end
        else begin
           CS <= NS;
           r_fdi_trans_en <= s_fdi_trans_en;
           r_credit_rtn_req_en <= s_credit_rtn_req_en;
           r_fdi_lp_state_req <= s_fdi_lp_state_req;
           r_fdi_lp_trdy <= fdi_depktr_rx_trdy;
        end
     end

   always_comb begin
      s_fdi_lp_state_req = IDLE;
      s_credit_rtn_req_en = 1'b0;
      s_fdi_trans_en = 1'b0;
      case(CS)
        ST_wait_remote: begin
           s_fdi_lp_state_req = INIT;
           s_fdi_trans_en =  1'b0;
           if (fdi_pl_inband_pres) NS = ST_req_active;
           else NS = ST_wait_remote;
        end
        ST_req_active: begin
           s_fdi_lp_state_req = ACTIVE;
           s_fdi_trans_en =  1'b0;
           if (fdi_pl_state_sts == 3'h2) // unitlll the link is active
             NS = ST_credit_init;
           else
             NS = ST_req_active;
        end
        ST_credit_init: begin
           s_fdi_lp_state_req = ACTIVE;
           s_credit_rtn_req_en = 1'b1;
           s_fdi_trans_en =  1'b1;
           if (credit_init_done) NS = ST_TX_RX;
           else NS = ST_credit_init;
        end
        ST_TX_RX: begin
           s_fdi_lp_state_req = ACTIVE;
           s_fdi_trans_en =  1'b1;
           if (fdi_pl_state_sts != 3'h2) NS = ST_wait_remote;
           else NS = ST_TX_RX;
        end
        default: NS=ST_wait_remote;
      endcase 
   end // always _comb

endmodule
