module axfdi_port_router #(
  parameter axi_data_w = 1024,
  parameter axi_burst_len_w = 8,
  parameter axi_burst_type_w  = 2,
  parameter axi_burst_size_w = 3,
  parameter axi_resp_w = 2,
  parameter axi_addr_w = 40,
  parameter axi_wstrb_w = 128,
  parameter axi_id_w = 8,
  parameter cdc_aw_d_w = 61,
  parameter cdc_w_d_w = 1153,
  parameter cdc_ar_d_w = 61,
  parameter cdc_b_d_w = 10,
  parameter cdc_r_d_w = 1035
)(
  //clock and reset signals
  input logic                        fdi_clk,
  input logic                        fdi_rst_n,
  input logic                        por_n,

  //signals from depacketizer
  input logic [axi_data_w-1:0]       depktr_portrtr_axi_data,
  input logic [axi_burst_len_w-1:0]  depktr_portrtr_axi_burst_len,
  input logic [axi_burst_type_w-1:0] depktr_portrtr_axi_burst_type,
  input logic [axi_burst_size_w-1:0] depktr_portrtr_axi_burst_size,
  input logic [axi_resp_w-1:0]       depktr_portrtr_axi_resp,
  input logic [axi_addr_w-1:0]       depktr_portrtr_axi_addr,
  input logic [axi_wstrb_w-1:0]      depktr_portrtr_axi_wstrb,
  input logic                        depktr_portrtr_flit_eop,
  input logic                        depktr_portrtr_flit_sop,
  output logic                       portrtr_depktr_read_done, //indicating port router has performed read
  input logic                        depktr_portrtr_write_req_valid,
  input logic                        depktr_portrtr_read_req_valid,
  input logic                        depktr_portrtr_write_resp_valid,
  input logic                        depktr_portrtr_read_resp_valid,
  input logic                        depktr_portrtr_port_id,
  input logic [axi_id_w-1:0]         depktr_portrtr_txn_id,

  //port0 CDC signals
  output logic [cdc_aw_d_w-1:0]      port0_cdc_aw_d,
  output logic                       port0_cdc_aw_d_wr_en,
  input logic                        port0_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]       port0_cdc_w_d,
  output logic                       port0_cdc_w_d_wr_en,
  input logic                        port0_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0]      port0_cdc_ar_d,
  output logic                       port0_cdc_ar_d_wr_en,
  input logic                        port0_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]       port0_cdc_b_d,
  output logic                       port0_cdc_b_d_wr_en,
  input logic                        port0_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]       port0_cdc_r_d,
  output logic                       port0_cdc_r_d_wr_en,
  input logic                        port0_cdc_r_d_full,
  //port1 CDC signals
  output logic [cdc_aw_d_w-1:0]      port1_cdc_aw_d,
  output logic                       port1_cdc_aw_d_wr_en,
  input logic                        port1_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]       port1_cdc_w_d,
  output logic                       port1_cdc_w_d_wr_en,
  input logic                        port1_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0]      port1_cdc_ar_d,
  output logic                       port1_cdc_ar_d_wr_en,
  input logic                        port1_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]       port1_cdc_b_d,
  output logic                       port1_cdc_b_d_wr_en,
  input logic                        port1_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]       port1_cdc_r_d,
  output logic                       port1_cdc_r_d_wr_en,
  input logic                        port1_cdc_r_d_full,
 );


   logic [cdc_aw_d_w-1:0]            r_port0_cdc_aw_d;
   logic                             r_port0_cdc_aw_d_valid;
   logic [cdc_w_d_w-1:0]             r_port0_cdc_w_d;
   logic                             r_port0_cdc_w_d_valid;
   logic [cdc_ar_d_w-1:0]            r_port0_cdc_ar_d;
   logic                             r_port0_cdc_ar_d_valid;
   logic [cdc_b_d_w-1:0]             r_port0_cdc_b_d;
   logic                             r_port0_cdc_b_d_valid;
   logic [cdc_r_d_w-1:0]             r_port0_cdc_r_d;
   logic                             r_port0_cdc_r_d_valid;
   //port 1 sigals
   logic [cdc_aw_d_w-1:0]            r_port1_cdc_aw_d;
   logic                             r_port1_cdc_aw_d_valid;
   logic [cdc_w_d_w-1:0]             r_port1_cdc_w_d;
   logic                             r_port1_cdc_w_d_valid;
   logic [cdc_ar_d_w-1:0]            r_port1_cdc_ar_d;
   logic                             r_port1_cdc_ar_d_valid;
   logic [cdc_b_d_w-1:0]             r_port1_cdc_b_d;
   logic                             r_port1_cdc_b_d_valid;
   logic [cdc_r_d_w-1:0]             r_port1_cdc_r_d;
   logic                             r_port1_cdc_r_d_valid;



   assign port1_cdc_aw_d = r_port1_cdc_aw_d;
   assign port1_cdc_aw_d_wr_en = r_port1_cdc_aw_d_valid & !port1_cdc_aw_d_full;
   assign port1_cdc_w_d = r_port1_cdc_w_d;
   assign port1_cdc_w_d_wr_en = r_port1_cdc_w_d_valid & !port1_cdc_w_d_full;
   assign port1_cdc_ar_d =  r_port1_cdc_ar_d;
   assign port1_cdc_ar_d_wr_en = r_port1_cdc_ar_d_valid & !port1_cdc_ar_d_full;
   assign port1_cdc_b_d =  r_port1_cdc_b_d;
   assign port1_cdc_b_d_wr_en = r_port1_cdc_b_d_valid & !port1_cdc_b_d_full;
   assign port1_cdc_r_d = r_port1_cdc_r_d;
   assign port1_cdc_r_d_wr_en = r_port1_cdc_r_d_valid & !port1_cdc_r_d_full;

   assign port0_cdc_aw_d = r_port0_cdc_aw_d;
   assign port0_cdc_aw_d_wr_en = r_port0_cdc_aw_d_valid & !port0_cdc_aw_d_full;
   assign port0_cdc_w_d = r_port0_cdc_w_d;
   assign port0_cdc_w_d_wr_en = r_port0_cdc_w_d_valid & !port0_cdc_w_d_full;
   assign port0_cdc_ar_d =  r_port0_cdc_ar_d;
   assign port0_cdc_ar_d_wr_en = r_port0_cdc_ar_d_valid & !port0_cdc_ar_d_full;
   assign port0_cdc_b_d =  r_port0_cdc_b_d;
   assign port0_cdc_b_d_wr_en = r_port0_cdc_b_d_valid & !port0_cdc_b_d_full;
   assign port0_cdc_r_d = r_port0_cdc_r_d;
   assign port0_cdc_r_d_wr_en = r_port0_cdc_r_d_valid & !port0_cdc_r_d_full;

 
    always_ff@(posedge fdi_clk or negedge fdi_rst_n)
      if(!por_n) begin
      end else begin
         if (!fdi_rst_n) begin
         end else begin //write request
            if (depktr_portrtr_write_req_valid) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_aw_d_valid <= 1'b1;
                  r_port0_cdc_aw_d <= {depktr_portrtr_txn_id,
                                     depktr_portrtr_axi_burst_len,
                                     depktr_portrtr_axi_burst_type,
                                     depktr_portrtr_axi_burst_size,
                                     depktr_portrtr_axi_addr};
                  r_port0_cdc_w_d_valid <= 1'b1;
                  r_port0_cdc_w_d <= {depktr_portrtr_axi_data,
                                     depktr_portrtr_axi_wstrb,
                                    depktr_portrtr_flit_eop};
               end else if (depktr_portrtr_port_id == 1'b1) begin
                  r_port1_cdc_aw_d_valid <= 1'b1;
                  r_port1_cdc_aw_d <= {depktr_portrtr_txn_id,
                                     depktr_portrtr_axi_burst_len,
                                     depktr_portrtr_axi_burst_type,
                                     depktr_portrtr_axi_burst_size,
                                     depktr_portrtr_axi_addr};
                  r_port1_cdc_w_d_valid <= 1'b1;
                  r_port1_cdc_w_d <= {depktr_portrtr_axi_data,
                                     depktr_portrtr_axi_wstrb,
                                    depktr_portrtr_flit_eop};
               end
            end else begin // if (depktr_portrtr_write_req_valid)
               r_port0_cdc_aw_d_valid <= 1'b0;
               r_port0_cdc_aw_d <= '0;
               r_port1_cdc_aw_d_valid <= 1'b0;
               r_port1_cdc_aw_d <= '0;
               r_port0_cdc_w_d_valid <= 1'b0;
               r_port0_cdc_w_d <= '0;
               r_port1_cdc_w_d_valid <= 1'b0;
               r_port1_cdc_w_d <= '0;
            end
            if (depktr_portrtr_read_req_valid) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_ar_d_valid <= 1'b1;
                  r_port0_cdc_ar_d <= {depktr_portrtr_txn_id,
                                     depktr_portrtr_axi_burst_len,
                                     depktr_portrtr_axi_burst_type,
                                     depktr_portrtr_axi_burst_size,
                                     depktr_portrtr_axi_addr};
               end else if (depktr_portrtr_port_id == 1'b1) begin
                  r_port1_cdc_ar_d_valid <= 1'b1;
                  r_port1_cdc_ar_d <= {depktr_portrtr_txn_id,
                                     depktr_portrtr_axi_burst_len,
                                     depktr_portrtr_axi_burst_type,
                                     depktr_portrtr_axi_burst_size,
                                     depktr_portrtr_axi_addr};
               end
            end else begin // if (depktr_portrtr_write_req_valid)
               r_port0_cdc_ar_d_valid <= 1'b0;
               r_port0_cdc_ar_d <= '0;
               r_port1_cdc_ar_d_valid <= 1'b0;
               r_port1_cdc_ar_d <= '0;
            end //write resp
            if (depktr_portrtr_write_resp_valid) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_b_d_valid <= 1'b1;
                  r_port0_cdc_b_d <= {depktr_portrtr_txn_id,
                                      depktr_portrtr_axi_resp};
               end else if (depktr_portrtr_port_id == 1'b1) begin
                  r_port1_cdc_b_d_valid <= 1'b1;
                  r_port1_cdc_b_d <= {depktr_portrtr_txn_id,
                                      depktr_portrtr_axi_resp};
               end
            end else begin // if (depktr_portrtr_write_req_valid)
               r_port0_cdc_b_d_valid <= 1'b0;
               r_port0_cdc_b_d <= '0;
               r_port1_cdc_b_d_valid <= 1'b0;
               r_port1_cdc_b_d <= '0;
            end //read_resp
            if (depktr_portrtr_read_resp_valid) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_r_d_valid <= 1'b1;
                 r_port0_cdc_r_d <= {depktr_portrtr_axi_data,
                                     depktr_portrtr_txn_id,
                                     depktr_portrtr_axi_resp,
                                     depktr_portrtr_flit_eop};
               end else if (depktr_portrtr_port_id == 1'b1) begin
                  r_port1_cdc_r_d_valid <= 1'b1;
                  r_port1_cdc_r_d <= {depktr_portrtr_axi_data,
                                      depktr_portrtr_txn_id,
                                      depktr_portrtr_axi_resp,
                                      depktr_portrtr_flit_eop};
               end
            end else begin // if (depktr_portrtr_write_req_valid)
               r_port0_cdc_r_d_valid <= 1'b0;
               r_port0_cdc_r_d <= '0;
               r_port1_cdc_r_d_valid <= 1'b0;
               r_port1_cdc_r_d <= '0;
            end
         end
      end
endmodule
