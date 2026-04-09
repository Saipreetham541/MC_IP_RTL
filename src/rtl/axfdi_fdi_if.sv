//

module axfdi_fdi_if #(
  parameter fdi_flit_width = 2048

)(
  //clock and reset wires
  input logic                       fdi_clk,
  input logic                       fdi_rstn,

  //TX side
  output logic [fdi_flit_width-1:0] fdi_tx_lp_data,
  output logic                      fdi_tx_lp_valid,
  output logic                      fdi_tx_lp_irdy,
  output logic                      fdi_tx_lp_startofpkt,
  output logic                      fdi_tx_lp_endofpkt,
  input logic                       fdi_tx_pl_trdy,
  output logic [2:0]                fdi_tx_lp_state_req,
  output logic                      fdi_tx_lp_linkerror,


  //RX side
  input logic [fdi_flit_width-1:0]  fdi_rx_pl_data,
  input logic                       fdi_rx_pl_valid,
  input logic                       fdi_rx_pl_irdy,
  input logic                       fdi_rx_pl_startofpkt,
  input logic                       fdi_rx_pl_endofpkt,
  output logic                      fdi_rx_lp_trdy,
  input logic [2:0]                 fdi_rx_pl_state_sts,
  input logic                       fdi_pl_inband_pres,

  //to the DUT
  input logic [fdi_flit_width-1:0]  flit_tx_data,
  input logic                       flit_tx_data_valid,
  input logic                       fdi_depktr_tx_sop,
  input logic                       fdi_depktr_tx_eop,

  output logic [fdi_flit_width-1:0] flit_rx_data,
  output logic                      flit_rx_data_valid,
  input logic                       fdi_crdtmgr_rx_trdy,
  output logic                      fdi_depktr_rx_sop,
  output logic                      fdi_depktr_rx_eop,
);

   logic [fdi_flit_width-1:0]        r_fdi_tx_lp_data;
   logic                             r_fdi_tx_lp_irdy;
   logic                             r_fdi_tx_lp_valid;
   logic                             r_fdi_tx_lp_startofpkt;
   logic                             r_fdi_tx_lp_endofpkt;


   //RX side regs
   logic [fdi_flit_width-1:0]        r_fdi_rx_pl_data;
   logic                             r_fdi_rx_lp_trdy;
   logic                             r_fdi_rx_pl_startofpkt;
   logic                             r_fdi_rx_pl_endofpkt;
   logic                             r_flit_rx_data_valid;

   
        
   always_ff@(posedge fdi_clk or negedge fdi_rstn)
     if (!fdi_rstn) begin
        r_fdi_tx_lp_irdy <= 1'b0;
        r_fdi_tx_lp_valid = 1'b0;
        r_fdi_tx_lp_data <= 'h0;
     end
       else begin
          if (flit_tx_data_valid && fdi_tx_pl_trdy) begin
             r_fdi_tx_lp_data <= flit_tx_data;
             r_fdi_tx_lp_irdy <= 1'b1;  //??
             r_fdi_tx_lp_startofpkt <= fdi_depktr_tx_sop;
             r_fdi_tx_lp_endofpkt <= fdi_depktr_tx_eop;
          end
       end
   //module assign on the TX side
   assign fdi_tx_lp_data = r_fdi_tx_lp_data;
   assign fdi_tx_lp_irdy = r_fdi_tx_lp_irdy;
   assign fdi_tx_lp_valid = flit_tx_data_valid;
   assign fdi_tx_lp_startofpkt = r_fdi_tx_lp_startofpkt;
   assign fdi_tx_lp_endofpkt = r_fdi_tx_lp_endof_pkt


   //module assign on the RX side
   assign fdi_rx_lp_trdy = fdi_crdtmgr_rx_trdy;
   assign flit_rx_data_valid = r_flit_rx_data_valid;
   assign flit_rx_data = r_fdi_rx_pl_data;
   assign fdi_depktr_rx_eop = r_fdi_rx_pl_endofpkt;
   assign fdi_depktr_rx_sop = r_fdi_rx_pl_startofpkt;


   always_ff@(posedge fdi_clk or negedge fdi_rstn)
     if (!fdi_rstn) begin
           r_fdi_rx_pl_data <= '0;
           r_fdi_rx_pl_startofpkt <= 1'b0;
           r_fdi_rx_pl_endofpkt <= 1'b0;
        r_flit_rx_data_valid <= 1'b1;
     end
     else begin
        if (fdi_rx_pl_irdy && fdi_crdtmgr_rx_trdy && fdi_rx_pl_valid) begin
           r_fdi_rx_pl_data <= fdi_rx_pl_data;
           r_fdi_rx_pl_startofpkt <= fdi_rx_pl_startofpkt;
           r_fdi_rx_pl_endofpkt <= fdi_rx_pl_endofpkt;
           r_flit_rx_data_valid <= 1'b1;
        end
     end
endmodule
