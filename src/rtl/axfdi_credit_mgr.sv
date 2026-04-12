module axfdi_credit_mgr #(
                          parameter credit_size = 5
)(
  input logic        fdi_clk,
  input logic        fdi_rst_n,
  input logic        por_n,
  //signls to the depacketizer for the returned crdit
  input logic [1:0]  tx_credit_rtn_vcn,
  input logic [5:0]  tx_credit_rtn_cnt,
  input logic        tx_credit_rtn_valid,
  //upon receiving flit increment the rx_consumed credit count
  input logic        rx_credit_cnsmd_incr_flag,
  input logic [2:0]  rx_credit_cnsmd_incr_vcn,

  //signals from the packetizer indicating tx done
  input logic        tx_credit_vcn,
  input logic        tx_credit_decr_flag,
  //signals indicating tx credits
  output logic       tx_vc_cpl_credit_ind,
  output logic       tx_vc_np_credit_ind,
  //piggyback the rtn credit or standalone tx
  output logic       credit_rtn_opcode_en,
  output logic [5:0] rx_credit_rtn_cnt,
  output logic [1:0] rx_credit_rtn_vcn,
  output logic       credit_rtn_piggy_en,


  //indicator
  input logic        pending_tx_available,
  input logic        credit_rtn_done,

  //credit init req from FDI interface
  input logic        credit_init_req,
  output logic       credit_init_done
);

   //thresh hold for the credits consumed by the rx
   localparam                    rx_credit_cnsmd_thrshld = 16;

   //TX credits
   logic [credit_size-1:0]         tx_vc_cpl_credit_cnt;
   logic [credit_size-1:0]         tx_vc_np_credit_cnt;

   logic [credit_size-1:0]         rx_cpl_credit_cnsmd;
   logic [credit_size-1:0]         rx_np_credit_cnsmd;
   //flag indicating consumed credit reached threshhold
   logic                           s_rx_cpl_credit_cnsmd_rtn_flag;
   logic                           s_rx_np_credit_cnsmd_rtn_flag;
   logic                           r_rx_cpl_credit_cnsmd_rtn_flag;
   logic                           r_rx_np_credit_cnsmd_rtn_flag;

   //harcode values for the intial rx credit initilization
   localparam int   rx_cpl_credit_init = 32;
   localparam int   rx_np_credit_init = 32;
   logic [5:0]         r_rx_cpl_credit_init;
   logic [5:0]         r_rx_np_credit_init;
   logic               r_rx_cpl_credit_init_en;
   logic               r_rx_np_credit_init_en;
   logic               r_rx_cpl_credit_init_done;
   logic               r_rx_np_credit_init_done;


   logic [5:0]         r_rx_credit_rtn_cnt;
   logic [1:0]                     r_rx_credit_rtn_vcn;
   logic                           r_rx_cpl_credit_cnsmd_rtn_done;
   logic                           r_rx_np_credit_cnsmd_rtn_done;



   assign credit_init_done = r_rx_cpl_credit_init_done & r_rx_np_credit_init_done;
   assign tx_vc_cpl_credit_ind = (tx_vc_cpl_credit_cnt == 0) ? 1'b1 : 1'b0;
   assign tx_vc_np_credit_ind = (tx_vc_np_credit_cnt == 0) ? 1'b1 : 1'b0;


   assign s_rx_cpl_credit_cnsmd_rtn_flag = (rx_cpl_credit_cnsmd >= rx_credit_cnsmd_thrshld) ? 1'b1 : 1'b0;
   assign s_rx_np_credit_cnsmd_rtn_flag = (rx_np_credit_cnsmd >= rx_credit_cnsmd_thrshld) ? 1'b1 : 1'b0;

   assign credit_rtn_opcode_en = (credit_init_req) ? 1'b1 : (r_rx_cpl_credit_cnsmd_rtn_flag | r_rx_np_credit_cnsmd_rtn_flag) & !pending_tx_available;
   assign rx_credit_rtn_cnt = r_rx_credit_rtn_cnt;
   assign rx_credit_rtn_vcn = r_rx_credit_rtn_vcn;
   assign credit_rtn_piggy_en = (r_rx_cpl_credit_cnsmd_rtn_flag | r_rx_np_credit_cnsmd_rtn_flag) & pending_tx_available;


   always_ff @(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
     end
     else begin
        if (!fdi_rst_n) begin
        end
        else begin
           if(credit_init_req) begin
              r_rx_cpl_credit_init <= rx_cpl_credit_init[5:0];
              r_rx_np_credit_init <= rx_np_credit_init[5:0];
              r_rx_cpl_credit_init_en <= 1'b1;
              r_rx_np_credit_init_en <= 1'b1;
           end
           if (r_rx_cpl_credit_init_done) r_rx_cpl_credit_init <= '0;
           if (r_rx_np_credit_init_done) r_rx_np_credit_init <= '0;
        end
     end

   //credit return management
   always_ff@(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        r_rx_credit_rtn_cnt <= '0;
        r_rx_credit_rtn_vcn <= '0;
        r_rx_cpl_credit_cnsmd_rtn_done <= 1'b0;
        r_rx_np_credit_cnsmd_rtn_done <= 1'b0;
     end
     else begin
        if (!fdi_rst_n) begin
           r_rx_credit_rtn_cnt <= '0;
           r_rx_credit_rtn_vcn <= '0;
           r_rx_cpl_credit_cnsmd_rtn_done <= 1'b0;
           r_rx_np_credit_cnsmd_rtn_done <= 1'b0;
        end
        else begin
           //if (credit_init_req) begin
          //swapfile end
           if (r_rx_cpl_credit_init_en) begin
              r_rx_credit_rtn_cnt <= r_rx_cpl_credit_init;
              r_rx_credit_rtn_vcn <= 1'b1;
              if (credit_rtn_done) begin
                 r_rx_credit_rtn_cnt <= '0;
                 r_rx_credit_rtn_vcn <= 1'b0;
                 r_rx_cpl_credit_init_done <= 1'b1;
              end
           end
           else if (r_rx_np_credit_init_en) begin
              r_rx_credit_rtn_cnt <= r_rx_np_credit_init;
              r_rx_credit_rtn_vcn <= 1'b1;
              if (credit_rtn_done) begin
                 r_rx_credit_rtn_cnt <= '0;
                 r_rx_credit_rtn_vcn <= 1'b0;
                 r_rx_np_credit_init_done <= 1'b1;
              end
           end
           else begin
              r_rx_np_credit_init_done <= 1'b0;
              r_rx_cpl_credit_init_done <= 1'b0;
           end
           if (s_rx_cpl_credit_cnsmd_rtn_flag) begin
              r_rx_credit_rtn_vcn <= 2'h1;
              r_rx_credit_rtn_cnt <= rx_cpl_credit_cnsmd;
              r_rx_cpl_credit_cnsmd_rtn_done <= 1'b1;
              r_rx_cpl_credit_cnsmd_rtn_flag = s_rx_cpl_credit_cnsmd_rtn_flag;
           end
           else if (s_rx_np_credit_cnsmd_rtn_flag) begin
              r_rx_credit_rtn_vcn <= 2'h0;
              r_rx_credit_rtn_cnt <= rx_np_credit_cnsmd;
              r_rx_np_credit_cnsmd_rtn_done <= 1'b1;
              r_rx_np_credit_cnsmd_rtn_flag = s_rx_np_credit_cnsmd_rtn_flag;
           end
           else begin
              r_rx_cpl_credit_cnsmd_rtn_flag <= 1'b1;
              r_rx_np_credit_cnsmd_rtn_flag <= 1'b1;
              r_rx_cpl_credit_cnsmd_rtn_done <= 1'b0;
              r_rx_np_credit_cnsmd_rtn_done <= 1'b0;
           end
        end
     end

   //tracking the TX credits
   always_ff@(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
        tx_vc_np_credit_cnt = 0;
        tx_vc_cpl_credit_cnt = 0;
     end
     else begin
        if (!fdi_rst_n) begin
           tx_vc_np_credit_cnt = 0;
           tx_vc_cpl_credit_cnt = 0;
        end
        else begin
           if (tx_credit_rtn_valid) begin
              if (tx_credit_rtn_vcn == 3'h0) tx_vc_np_credit_cnt += tx_credit_rtn_cnt;
              else if (tx_credit_rtn_vcn == 3'h1) tx_vc_cpl_credit_cnt += tx_credit_rtn_cnt;
           end
           if (tx_credit_decr_flag) begin
              if (tx_credit_vcn == 3'h0) tx_vc_np_credit_cnt += 1;
              else if (tx_credit_vcn == 3'h1) tx_vc_cpl_credit_cnt +=1;
           end
        end
     end // else: !if(!por_n)

   //tracking rx credits consumed
   always_ff@(posedge fdi_clk or negedge por_n)
     if (!por_n) begin
     end
     else begin
        if (!fdi_rst_n) begin
        end
        else begin
           if (rx_credit_cnsmd_incr_flag) begin
              if (rx_credit_cnsmd_incr_vcn == 3'h0) rx_np_credit_cnsmd +=1;
              else if (rx_credit_cnsmd_incr_vcn == 3'h1) rx_cpl_credit_cnsmd +=1;
           end
           if (r_rx_cpl_credit_cnsmd_rtn_done && credit_rtn_done) rx_cpl_credit_cnsmd = '0;
           if (r_rx_np_credit_cnsmd_rtn_done && credit_rtn_done) rx_np_credit_cnsmd = '0;

        end
     end
endmodule
