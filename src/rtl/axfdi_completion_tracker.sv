module axfdi_completion_tracker #(
 parameter trakcer_depth = 256,
 parameter txn_id_w = 8
)
(
 //clock and reset logics
 input logic                fdi_clk,
 input logic                fdi_rst_n,
 input logic                por_n,

 //signals from the depacketizer
 input logic                rx_resp_valid,
 input logic                rx_vcn,
 input logic [txn_id_w-1:0] rx_txn_id,
 output logic               rx_resp_port_id,
 output logic               rx_resp_port_id_valid,

 //signals from packetizer
 input logic                tx_vcn,
 input logic [txn_id_w-1:0] tx_txn_id,
 input logic                tx_port_id,
 output logic               tx_write_done,
 input logic                tx_txn_valid
);

   typedef struct packed {
      logic       port_id;
      logic       vcn;
      logic [txn_id_w-1:0] txn_id;
      logic       data_valid;
      }completion_tracker[0:trakcer_depth-1];


   always_comb begin
      for
   end


   always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        for (idx=0;)
     end
     else begin
        if (!fdi_rst_n) begin
        end
        else begin
        end
     end

endmodule // axfdi_completion_tracker
