/* Module Name: axfdi_packetizer
   Clock Domain : FDI 625Mhz
   Engineer  : Vishwa Patwrai
   Company : Sevya Multimedia Technologies Pvt. Ltd.
*/

module axfdi_packetizer  #(
    parameter FDI_FLIT_WIDTH = 2048,
    parameter credit_size = 6,
    parameter rtn_vcn_w = 2,
    parameter vcn_w = 3,
    parameter AW_AR_DATA_W = 61,
    parameter W_DATA_W = 1153,
    parameter R_DATA_W = 1035,
    parameter B_DATA_W = 10,
    parameter txn_id_w = 8
)(
    input logic                       fdi_clk,
    input logic                       fdi_rst_n,
    input logic                       por_n,


    // Arbiter
    input logic [2:0]                 txn_type,
    input logic [vcn_w-1:0]           vcn_sel,
    input logic                       port_id_i,


    // -------- CREDIT MANAGER --------
    input logic                       credit_rtn_opcode_en,
    input logic [credit_size-1:0]     rx_credit_rtn_cnt,
    input logic [rtn_vcn_w-1:0]       rx_credit_rtn_vcn,
    input logic                       credit_rtn_piggy_en,


    output logic [vcn_w-1:0]          tx_credit_vcn,
    output logic                      tx_credit_decr_flag,


    //output logic                      pending_tx_available,
    output logic                      credit_rtn_done,


    // -------- PORT 0 --------
    input logic [AW_AR_DATA_W-1:0]    aw_fifo0_data,
    output logic                      aw_fifo0_rd_en,


    input logic [W_DATA_W-1:0]        w_fifo0_data,
    output logic                      w_fifo0_rd_en,


    input logic [AW_AR_DATA_W-1:0]    ar_fifo0_data,
    output logic                      ar_fifo0_rd_en,


    input logic [R_DATA_W-1:0]        r_fifo0_data,
    output logic                      r_fifo0_rd_en,


    input logic [B_DATA_W-1:0]        b_fifo0_data,
    output logic                      b_fifo0_rd_en,


    // -------- PORT 1 --------
    input logic [AW_AR_DATA_W-1:0]    aw_fifo1_data,
    output logic                      aw_fifo1_rd_en,


    input logic [W_DATA_W-1:0]        w_fifo1_data,
    output logic                      w_fifo1_rd_en,


    input logic [AW_AR_DATA_W-1:0]    ar_fifo1_data,
    output logic                      ar_fifo1_rd_en,


    input logic [R_DATA_W-1:0]        r_fifo1_data,
    output logic                      r_fifo1_rd_en,


    input logic [B_DATA_W-1:0]        b_fifo1_data,
    output logic                      b_fifo1_rd_en,
    //---------Completion tracker---------------


    output logic                      tx_vcn,
    output logic [txn_id_w-1:0]       tx_txn_id,
    output logic                      tx_port_id,
    input logic                       tx_write_done,
    output logic                      tx_txn_valid,
    // -------- FDI --------
    output logic [FDI_FLIT_WIDTH-1:0] flit_tx_data,
    output logic                      flit_tx_valid,
    output logic                      fdi_tx_sop,
    output logic                      fdi_tx_eop,
    input logic                       fdi_tx_ready,
    
    
    //----------- eop ----------------
    output logic                      fdi_pktr_eop
);


    typedef enum logic [2:0] {
        WRITE_REQ  = 3'd0,
        READ_REQ   = 3'd1,
        WRITE_RESP = 3'd2,
        READ_RESP  = 3'd3,
        CREDIT_RTN = 3'd4,
        NOP        = 3'd5
    } txn_t;


    /*always_comb begin
        if (port_id_i == 0) begin
            aw_data = aw_fifo0_data;
            w_data  = w_fifo0_data;
            ar_data = ar_fifo0_data;
            r_data  = r_fifo0_data;
            b_data  = b_fifo0_data;


        end else begin
            aw_data = aw_fifo1_data;
            w_data  = w_fifo1_data;
            ar_data = ar_fifo1_data;
            r_data  = r_fifo1_data;
            b_data  = b_fifo1_data;
        end
    end */


   
    // TX AVAILABLE
   
   /* always_comb begin
        pending_tx_available =
            WRITE_REQ ||
            READ_REQ ||
            WRITE_RESP ||
            READ_RESP;
    end */


   
 


   
   // FSM
  typedef enum logic [1:0] {
    S_IDLE   = 2'd0,
    S_READ   = 2'd1,
    S_LATCH  = 2'd2,
    S_HEADER = 2'd3
  } state_t;


  state_t state;


  // latched inputs
  logic [2:0]           lat_type;
  logic [vcn_w-1:0]     lat_vcn;
  logic                 lat_port;
  logic                 lat_cr_opcode;
  logic                 lat_cr_piggy;
  logic [credit_size-1:0]  lat_cr_cnt;
  logic [rtn_vcn_w-1:0]   lat_cr_vcn;


  // latched FIFO data
  logic [AW_AR_DATA_W-1:0] lat_aw, lat_ar;
  logic [W_DATA_W-1:0]     lat_w;
  logic [R_DATA_W-1:0]     lat_r;
  logic [B_DATA_W-1:0]     lat_b;


  // start condition
  wire start_txn = credit_rtn_opcode_en ||
                   (txn_type != NOP);


  // FIFO mux latched port
  logic [AW_AR_DATA_W-1:0] sel_aw, sel_ar;
  logic [W_DATA_W-1:0]     sel_w;
  logic [R_DATA_W-1:0]     sel_r;
  logic [B_DATA_W-1:0]     sel_b;


  always_comb begin
    if (lat_port == 1'b0) begin
      sel_aw = aw_fifo0_data; sel_ar = ar_fifo0_data;
      sel_w  = w_fifo0_data;  sel_r  = r_fifo0_data;
      sel_b  = b_fifo0_data;
    end else begin
      sel_aw = aw_fifo1_data; sel_ar = ar_fifo1_data;
      sel_w  = w_fifo1_data;  sel_r  = r_fifo1_data;
      sel_b  = b_fifo1_data;
    end
  end


  // FSM/
  always_ff @(posedge fdi_clk or negedge por_n) begin
    if (!por_n) begin
      state        <= S_IDLE;
      lat_type     <= NOP;
      lat_vcn      <= '0;
      lat_port     <= '0;
      lat_cr_opcode<= '0;
      lat_cr_piggy <= '0;
      lat_cr_cnt   <= '0;
      lat_cr_vcn   <= '0;
      lat_aw <= '0; lat_ar <= '0;
      lat_w  <= '0; lat_r  <= '0; lat_b <= '0;
    end else begin
       if (!fdi_rst_n) begin
          state        <= S_IDLE;
          lat_type     <= NOP;
          lat_vcn      <= '0;
          lat_port     <= '0;
          lat_cr_opcode<= '0;
          lat_cr_piggy <= '0;
          lat_cr_cnt   <= '0;
          lat_cr_vcn   <= '0;
          lat_aw <= '0; lat_ar <= '0;
          lat_w  <= '0; lat_r  <= '0; lat_b <= '0;
       end
       else begin
          case (state)


            S_IDLE: begin
               if (start_txn) begin
                  // latch all arbiter + credit inputs now
                  lat_type      <= txn_type;
            lat_vcn       <= vcn_sel;
                  lat_port      <= port_id_i;
                  lat_cr_opcode <= credit_rtn_opcode_en;
                  lat_cr_piggy  <= credit_rtn_piggy_en;
                  lat_cr_cnt    <= rx_credit_rtn_cnt;
                  lat_cr_vcn    <= rx_credit_rtn_vcn;
                  // credit return standalone
                  if (credit_rtn_opcode_en)
              state <= S_HEADER;
                  else
                    state <= S_READ;
               end
            end


            // fifo read
            S_READ: begin
               state <= S_LATCH;
            end


            // capture FIFO outputs
            S_LATCH: begin
               lat_aw <= sel_aw;
               lat_ar <= sel_ar;
               lat_w  <= sel_w;
               lat_r  <= sel_r;
               lat_b  <= sel_b;
               state  <= S_HEADER;
            end


            // hold until FDI accepts the flit
            S_HEADER: begin
               if (fdi_tx_ready)
                 state <= S_IDLE;
            end


            default: state <= S_IDLE;
          endcase
       end
    end // else: !if(!fdi_rst_n)
  end
   


     always_comb begin
        aw_fifo0_rd_en = '0; w_fifo0_rd_en = '0;
        ar_fifo0_rd_en = '0; r_fifo0_rd_en = '0; b_fifo0_rd_en = '0;
        aw_fifo1_rd_en = '0; w_fifo1_rd_en = '0;
        ar_fifo1_rd_en = '0; r_fifo1_rd_en = '0; b_fifo1_rd_en = '0;


    if (state == S_READ) begin
      case (lat_type)
        WRITE_REQ: begin
          if (!lat_port) begin aw_fifo0_rd_en = 1; w_fifo0_rd_en = 1; end
          else           begin aw_fifo1_rd_en = 1; w_fifo1_rd_en = 1; end
        end
        READ_REQ: begin
          if (!lat_port) ar_fifo0_rd_en = 1;
          else           ar_fifo1_rd_en = 1;
        end
        WRITE_RESP: begin
          if (!lat_port) b_fifo0_rd_en = 1;
          else           b_fifo1_rd_en = 1;
        end
        READ_RESP: begin
          if (!lat_port) r_fifo0_rd_en = 1;
          else           r_fifo1_rd_en = 1;
        end
        default: begin end
      endcase
    end
  end
   
    // CREDIT DECREMENT
   
   assign tx_credit_decr_flag = (state == S_HEADER) && fdi_tx_ready && !lat_cr_opcode;
  assign tx_credit_vcn       = lat_vcn;
 
  // credit return done
  assign credit_rtn_done = (state == S_HEADER) && fdi_tx_ready && lat_cr_opcode;




    // OUTPUT LOGIC
   
    always_comb begin
        flit_tx_data  = '0;
        flit_tx_valid = 0;
        fdi_tx_sop    = 0;
        fdi_tx_eop    = 0;


        if (state == S_HEADER) begin
            flit_tx_valid = 1;
            fdi_tx_sop    = 1;
            fdi_tx_eop    = 1 ;


            // COMMON HEADER
            flit_tx_data[2:0]  = 3'b110;
            flit_tx_data[5:3]  = lat_vcn;
            flit_tx_data[6]    = 1;
            flit_tx_data[7]    = 1 ;
           //concated to match the size
            flit_tx_data[11:8] = (lat_cr_opcode) ? {1'b0,CREDIT_RTN} : {1'b0,lat_type};
            flit_tx_data[12]   = lat_port;


            // CREDIT FIELDS
            if (lat_cr_opcode || lat_cr_piggy) begin
                flit_tx_data[37:36] = lat_cr_vcn;
                flit_tx_data[43:38] = lat_cr_cnt;
            end


            // NO WSTRB
            flit_tx_data[44] = 0;
            flit_tx_data[255:128] = '0;
           


            if (!lat_cr_opcode) begin
                case (lat_type)


                    WRITE_REQ: begin
                        flit_tx_data[20:13] = lat_aw[60:53];
                        flit_tx_data[28:21] = lat_aw[52:45];
                        flit_tx_data[30:29] = lat_aw[44:43];
                        flit_tx_data[33:31] = lat_aw[42:40];
                        flit_tx_data[84:45] = lat_aw[39:0];
                       
                       //width mismatch: 
                        flit_tx_data[1983:256] = {lat_w[1152:129], 704'b0}; 
                    end


                    READ_REQ: begin
                        flit_tx_data[20:13] = lat_ar[60:53];
                        flit_tx_data[28:21] = lat_ar[52:45];
                        flit_tx_data[30:29] = lat_ar[44:43];
                        flit_tx_data[33:31] = lat_ar[42:40];
                        flit_tx_data[84:45] = lat_ar[39:0];
                    end


                    WRITE_RESP: begin
                        flit_tx_data[20:13] = lat_b[9:2];
                        flit_tx_data[35:34] = lat_b[1:0];
                    end


                    READ_RESP: begin
                        flit_tx_data[20:13] = lat_r[10:3];
                        flit_tx_data[35:34] = lat_r[2:1];
                       //width mismatch: 
                        flit_tx_data[1983:256] = {lat_r[1034:11], 704'b0};
                    end
                  //added default statement 
                  default: begin
                     flit_tx_data[20:13] = '0;
                        flit_tx_data[35:34] = '0;
                        flit_tx_data[1983:256] = '0;
                  end
                endcase
            end
        end
    end


  assign tx_txn_id    = lat_ar[7:0];
  assign tx_port_id   = lat_port;
  assign tx_vcn       = (lat_vcn == 3'b00) ? 0 : 1  ;
  assign tx_txn_valid = (state == S_HEADER) && fdi_tx_ready && (lat_type == READ_REQ) && !lat_cr_opcode;
  assign fdi_pktr_eop = flit_tx_valid && fdi_tx_ready && fdi_tx_eop;
initial $monitor("state =%0d///////////////////////////////////////////////////////////", state);
endmodule
