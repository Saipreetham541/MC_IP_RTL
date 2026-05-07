//////////////////////////////////////////////////////////////////////////////////
// Company: Sevya Multimedia
// Engineer: Aravind P S <aravind.prasannanpillai@sevyamm.com>
//
// Create Date: 2026-04-17 00:39
// File Name: axfdi_port_router.sv
// Project Name: AXFDI Bridge
// Description: port router module
//
// Last Updated: 2026-04-17 00:39
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module axfdi_port_router #(
  parameter cdc_aw_d_w = 61,
  parameter cdc_w_d_w = 1153,
  parameter cdc_ar_d_w = 61,
  parameter cdc_b_d_w = 10,
  parameter cdc_r_d_w = 1035
)(
  //clock and reset signals
  input logic                   fdi_clk,
  input logic                   fdi_rst_n,
  input logic                   por_n,

  //signals from depacketizer
  input logic [cdc_aw_d_w-1:0]  aw_d,
  input logic                   aw_d_valid,
  output logic                  aw_d_ready,
  input logic [cdc_w_d_w-1:0]   w_d,
  input logic                   w_d_valid,
  output logic                  w_d_ready,
  input logic [cdc_ar_d_w-1:0]  ar_d,
  input logic                   ar_d_valid,
  output logic                  ar_d_ready,
  input logic [cdc_b_d_w-1:0]   b_d,
  input logic                   b_d_valid,
  output logic                  b_d_ready,
  input logic [cdc_r_d_w-1:0]   r_d,
  input logic                   r_d_valid,
  output logic                  r_d_ready,
  input logic                   depktr_portrtr_port_id,

  //port0 CDC signals
  output logic [cdc_aw_d_w-1:0] port0_cdc_aw_d,
  output logic                  port0_cdc_aw_d_wr_en,
  input logic                   port0_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]  port0_cdc_w_d,
  output logic                  port0_cdc_w_d_wr_en,
  input logic                   port0_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0] port0_cdc_ar_d,
  output logic                  port0_cdc_ar_d_wr_en,
  input logic                   port0_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]  port0_cdc_b_d,
  output logic                  port0_cdc_b_d_wr_en,
  input logic                   port0_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]  port0_cdc_r_d,
  output logic                  port0_cdc_r_d_wr_en,
  input logic                   port0_cdc_r_d_full,
  //port1 CDC signals
  output logic [cdc_aw_d_w-1:0] port1_cdc_aw_d,
  output logic                  port1_cdc_aw_d_wr_en,
  input logic                   port1_cdc_aw_d_full,
  output logic [cdc_w_d_w-1:0]  port1_cdc_w_d,
  output logic                  port1_cdc_w_d_wr_en,
  input logic                   port1_cdc_w_d_full,
  output logic [cdc_ar_d_w-1:0] port1_cdc_ar_d,
  output logic                  port1_cdc_ar_d_wr_en,
  input logic                   port1_cdc_ar_d_full,
  output logic [cdc_b_d_w-1:0]  port1_cdc_b_d,
  output logic                  port1_cdc_b_d_wr_en,
  input logic                   port1_cdc_b_d_full,
  output logic [cdc_r_d_w-1:0]  port1_cdc_r_d,
  output logic                  port1_cdc_r_d_wr_en,
  input logic                   port1_cdc_r_d_full
 );

   logic                        s_aw_d_ready;
   logic                        s_w_d_ready;
   logic                        s_ar_d_ready;
   logic                        s_r_d_ready;
   logic                        s_b_d_ready;

   logic [cdc_aw_d_w-1:0]       r_port0_cdc_aw_d;
   logic                        r_port0_cdc_aw_d_valid;
   logic [cdc_w_d_w-1:0]        r_port0_cdc_w_d;
   logic                        r_port0_cdc_w_d_valid;
   logic [cdc_ar_d_w-1:0]       r_port0_cdc_ar_d;
   logic                        r_port0_cdc_ar_d_valid;
   logic [cdc_b_d_w-1:0]        r_port0_cdc_b_d;
   logic                        r_port0_cdc_b_d_valid;
   logic [cdc_r_d_w-1:0]        r_port0_cdc_r_d;
   logic                        r_port0_cdc_r_d_valid;
   //port 1 sigals
   logic [cdc_aw_d_w-1:0]       r_port1_cdc_aw_d;
   logic                        r_port1_cdc_aw_d_valid;
   logic [cdc_w_d_w-1:0]        r_port1_cdc_w_d;
   logic                        r_port1_cdc_w_d_valid;
   logic [cdc_ar_d_w-1:0]       r_port1_cdc_ar_d;
   logic                        r_port1_cdc_ar_d_valid;
   logic [cdc_b_d_w-1:0]        r_port1_cdc_b_d;
   logic                        r_port1_cdc_b_d_valid;
   logic [cdc_r_d_w-1:0]        r_port1_cdc_r_d;
   logic                        r_port1_cdc_r_d_valid;


   assign s_aw_d_ready = !port0_cdc_aw_d_full & !port1_cdc_aw_d_full;
   assign s_w_d_ready  = !port0_cdc_w_d_full  & !port1_cdc_w_d_full;
   assign s_ar_d_ready = !port0_cdc_ar_d_full & !port1_cdc_ar_d_full;
   assign s_r_d_ready  = !port0_cdc_b_d_full  & !port1_cdc_b_d_full;
   assign s_b_d_ready  = !port0_cdc_r_d_full  & !port1_cdc_r_d_full;

   assign aw_d_ready = s_aw_d_ready;
   assign w_d_ready  = s_w_d_ready;
   assign ar_d_ready = s_ar_d_ready;
   assign r_d_ready  = s_r_d_ready;
   assign b_d_ready  = s_b_d_ready;

   assign port1_cdc_aw_d       = r_port1_cdc_aw_d;
   assign port1_cdc_aw_d_wr_en = r_port1_cdc_aw_d_valid;
   assign port1_cdc_w_d        = r_port1_cdc_w_d;
   assign port1_cdc_w_d_wr_en  = r_port1_cdc_w_d_valid;
   assign port1_cdc_ar_d       = r_port1_cdc_ar_d;
   assign port1_cdc_ar_d_wr_en = r_port1_cdc_ar_d_valid;
   assign port1_cdc_b_d        = r_port1_cdc_b_d;
   assign port1_cdc_b_d_wr_en  = r_port1_cdc_b_d_valid;
   assign port1_cdc_r_d        = r_port1_cdc_r_d;
   assign port1_cdc_r_d_wr_en  = r_port1_cdc_r_d_valid;

   assign port0_cdc_aw_d       = r_port0_cdc_aw_d;
   assign port0_cdc_aw_d_wr_en = r_port0_cdc_aw_d_valid;
   assign port0_cdc_w_d        = r_port0_cdc_w_d;
   assign port0_cdc_w_d_wr_en  = r_port0_cdc_w_d_valid;
   assign port0_cdc_ar_d       = r_port0_cdc_ar_d;
   assign port0_cdc_ar_d_wr_en = r_port0_cdc_ar_d_valid;
   assign port0_cdc_b_d        = r_port0_cdc_b_d;
   assign port0_cdc_b_d_wr_en  = r_port0_cdc_b_d_valid;
   assign port0_cdc_r_d        = r_port0_cdc_r_d;
   assign port0_cdc_r_d_wr_en  = r_port0_cdc_r_d_valid;

   always_ff@(posedge fdi_clk or negedge por_n)
      if(!por_n) begin
         r_port0_cdc_aw_d_valid <= 1'b0;
         r_port0_cdc_aw_d <= '0;
         r_port1_cdc_aw_d_valid <= 1'b0;
         r_port1_cdc_aw_d <= '0;
         r_port0_cdc_w_d_valid <= 1'b0;
         r_port0_cdc_w_d <= '0;
         r_port1_cdc_w_d_valid <= 1'b0;
         r_port1_cdc_w_d <= '0;
         r_port0_cdc_ar_d_valid <= 1'b0;
         r_port0_cdc_ar_d <= '0;
         r_port1_cdc_ar_d_valid <= 1'b0;
         r_port1_cdc_ar_d <= '0;
         r_port0_cdc_b_d_valid <= 1'b0;
         r_port0_cdc_b_d <= '0;
         r_port1_cdc_b_d_valid <= 1'b0;
         r_port1_cdc_b_d <= '0;
         r_port0_cdc_r_d_valid <= 1'b0;
         r_port0_cdc_r_d <= '0;
         r_port1_cdc_r_d_valid <= 1'b0;
         r_port1_cdc_r_d <= '0;
      end else begin
         if (!fdi_rst_n) begin
            r_port0_cdc_aw_d_valid <= 1'b0;
            r_port0_cdc_aw_d <= '0;
            r_port1_cdc_aw_d_valid <= 1'b0;
            r_port1_cdc_aw_d <= '0;
            r_port0_cdc_w_d_valid <= 1'b0;
            r_port0_cdc_w_d <= '0;
            r_port1_cdc_w_d_valid <= 1'b0;
            r_port1_cdc_w_d <= '0;
            r_port0_cdc_ar_d_valid <= 1'b0;
            r_port0_cdc_ar_d <= '0;
            r_port1_cdc_ar_d_valid <= 1'b0;
            r_port1_cdc_ar_d <= '0;
            r_port0_cdc_b_d_valid <= 1'b0;
            r_port0_cdc_b_d <= '0;
            r_port1_cdc_b_d_valid <= 1'b0;
            r_port1_cdc_b_d <= '0;
            r_port0_cdc_r_d_valid <= 1'b0;
            r_port0_cdc_r_d <= '0;
            r_port1_cdc_r_d_valid <= 1'b0;
            r_port1_cdc_r_d <= '0;
         end else begin //write request
            if (aw_d_valid && s_aw_d_ready) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_aw_d_valid <= aw_d_valid;
                  r_port0_cdc_aw_d       <= aw_d;
               end
               else begin
                  r_port1_cdc_aw_d_valid <= aw_d_valid;
                  r_port1_cdc_aw_d       <= aw_d;
               end
            end
            else begin
               r_port0_cdc_aw_d_valid <= 1'b0;
               r_port0_cdc_aw_d       <= '0;
               r_port1_cdc_aw_d_valid <= 1'b0;
               r_port1_cdc_aw_d       <= '0;
            end
            if (w_d_valid && s_w_d_ready) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_w_d_valid <= w_d_valid;
                  r_port0_cdc_w_d       <= w_d;
               end
               else begin
                  r_port1_cdc_w_d_valid <= w_d_valid;
                  r_port1_cdc_w_d       <= w_d;
               end
            end
            else begin
               r_port0_cdc_w_d_valid <= 1'b0;
               r_port0_cdc_w_d       <= '0;
               r_port1_cdc_w_d_valid <= 1'b0;
               r_port1_cdc_w_d       <= '0;
            end // else: !if(w_d_valid && s_w_d_ready)
            //read_req
            if (ar_d_valid && s_ar_d_ready) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_ar_d_valid <= ar_d_valid;
                  r_port0_cdc_ar_d       <= ar_d;
               end
               else begin
                  r_port1_cdc_ar_d_valid <= ar_d_valid;
                  r_port1_cdc_ar_d       <= ar_d;
               end
            end
            else begin
               r_port0_cdc_ar_d_valid <= 1'b0;
               r_port0_cdc_ar_d       <= '0;
               r_port1_cdc_ar_d_valid <= 1'b0;
               r_port1_cdc_ar_d       <= '0;
            end
            if (b_d_valid && s_b_d_ready) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_b_d_valid <= b_d_valid;
                  r_port0_cdc_b_d       <= b_d;
               end
               else begin
                  r_port1_cdc_b_d_valid <= b_d_valid;
                  r_port1_cdc_b_d       <= b_d;
               end
            end
            else begin
               r_port0_cdc_b_d_valid <= 1'b0;
               r_port0_cdc_b_d       <= '0;
               r_port1_cdc_b_d_valid <= 1'b0;
               r_port1_cdc_b_d       <= '0;
            end
            if (r_d_valid && s_r_d_ready) begin
               if (depktr_portrtr_port_id == 1'b0) begin
                  r_port0_cdc_r_d_valid <= r_d_valid;
                  r_port0_cdc_r_d       <= r_d;
               end
               else begin
                  r_port1_cdc_r_d_valid <= r_d_valid;
                  r_port1_cdc_r_d       <= r_d;
               end
            end
            else begin
               r_port0_cdc_r_d_valid <= 1'b0;
               r_port0_cdc_r_d       <= '0;
               r_port1_cdc_r_d_valid <= 1'b0;
               r_port1_cdc_r_d       <= '0;
            end
         end // else: !if(!fdi_rst_n)
      end //por_n
endmodule
