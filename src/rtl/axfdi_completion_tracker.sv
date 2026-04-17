//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-17 00:37
// File Name: axfdi_completion_tracker.sv
// Project Name: AXFDI Bridge
// Description: Completion Tracker module
//
// Last Updated: 2026-04-17 00:37
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////



module axfdi_completion_tracker #(
 parameter tracker_depth = 256,
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

    struct packed {
      logic       port_id;
      logic       vcn;
      logic [txn_id_w-1:0] txn_id;
      logic       data_valid;
      }completion_tracker[0:tracker_depth-1];

   logic          tx_d_found;
   logic [entry_idx_w-1:0] tx_d_index;
   localparam int unsigned entry_idx_w = (tracker_depth > 1) ? $clog2(tracker_depth) : 1;

   logic                   rx_d_hit;
   logic [entry_idx_w-1:0] rx_d_index;
   logic                   r_rx_resp_port_id, s_rx_resp_port_id;

   logic                   r_rx_resp_port_id_valid;
   logic                   r_tx_write_done;

   assign rx_resp_port_id = r_rx_resp_port_id;
   assign rx_resp_port_id_valid = r_rx_resp_port_id_valid;
   assign tx_write_done = r_tx_write_done;

   //loop to check for the free slot to assign value to the tracker
   always_comb begin
      tx_d_found = 0;
      tx_d_index = '0;
      for (int i=0;i<tracker_depth;i++) begin
         if (!completion_tracker[i].data_valid && !tx_d_found) begin
            tx_d_found = 1;
            tx_d_index = i[entry_idx_w-1:0];
         end
      end
   end

   //loop to find data in the completion_tracker
   always_comb begin
      rx_d_hit = 0;
      rx_d_index = '0;
      s_rx_resp_port_id = '0;
      for (int i=0; i<tracker_depth; i++) begin
         if (rx_resp_valid &&
             completion_tracker[i].data_valid &&
             completion_tracker[i].vcn == rx_vcn &&
             completion_tracker[i].txn_id == rx_txn_id &&
             !rx_d_hit) begin
            rx_d_hit = 1'b1;
            s_rx_resp_port_id = completion_tracker[i].port_id;
            rx_d_index = i[entry_idx_w-1:0];
         end
      end
   end


   always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        r_rx_resp_port_id_valid <= 1'b0;
        r_rx_resp_port_id <= '0;
        r_tx_write_done <= 1'b0;
        for (int idx=0; idx < tracker_depth; idx++) begin
           completion_tracker[idx].port_id <= 1'b0;
           completion_tracker[idx].vcn <= 1'b0;
           completion_tracker[idx].data_valid <= 1'b0;
           completion_tracker[idx].txn_id <= '0;
        end
     end else begin
        if (!fdi_rst_n) begin
           r_rx_resp_port_id_valid <= 1'b0;
           r_rx_resp_port_id <= '0;
           r_tx_write_done <= 1'b0;
           for (int idx=0; idx < tracker_depth; idx++) begin
              completion_tracker[idx].port_id <= 1'b0;
              completion_tracker[idx].vcn <= 1'b0;
              completion_tracker[idx].data_valid <= 1'b0;
              completion_tracker[idx].txn_id <= '0;
           end
        end else begin
           if (tx_d_found && tx_txn_valid) begin
              completion_tracker[tx_d_index].port_id <= tx_port_id;
              completion_tracker[tx_d_index].vcn <= tx_vcn;
              completion_tracker[tx_d_index].data_valid <= 1'b1;
              completion_tracker[tx_d_index].txn_id <= tx_txn_id;
           end
           if (rx_d_hit) begin
              r_rx_resp_port_id <= s_rx_resp_port_id;
              r_rx_resp_port_id_valid <= 1'b1;
              completion_tracker[rx_d_index].port_id <= '0;
              completion_tracker[rx_d_index].vcn <= '0;
              completion_tracker[rx_d_index].data_valid <= '0;
              completion_tracker[rx_d_index].txn_id <= '0;
           end else begin
              r_rx_resp_port_id <= '0;
              r_rx_resp_port_id_valid <= '0;
           end
        end
     end
endmodule // axfdi_completion_tracker
