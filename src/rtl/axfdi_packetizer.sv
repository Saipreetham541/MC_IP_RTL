/*
Module Name  : axfdi_packetizer
 Designer : Vishwa Patwari
Clock domain : FDI 625MHZ
Description  : this module supports the multi beat axi transactions for write
 contributor: Priya
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
    input logic                       fdi_clk, // fdi clock
    input logic                       fdi_rst_n, // fdi reset
    input logic                       por_n, // global reset


    //---------- Arbiter ---------------
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


    // -------- PORT 0 -----------------
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



    // -------- PORT 1 -----------------
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
  //input logic                       tx_write_done,
    output logic                      tx_txn_valid,


    // -------- FDI --------
    output logic [FDI_FLIT_WIDTH-1:0] flit_tx_data,
    output logic                      flit_tx_valid,
    output logic                      fdi_tx_sop,
    output logic                      fdi_tx_eop,
    input logic                       fdi_tx_ready,
   
   
    //----------- End of Packet ----------------
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


   // FSM
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_READ   = 3'd1,
    S_HEADER = 3'd2,
    S_DATA   = 3'd3
  } state_t;


  state_t state, next_state;


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
  //logic [W_DATA_W-1:0]     lat_w;
  logic [R_DATA_W-1:0]     lat_r;
  logic [B_DATA_W-1:0]     lat_b;








  // start condition
  wire start_txn = credit_rtn_opcode_en ||  (txn_type != NOP);






  // FIFO mux latched port
  logic [AW_AR_DATA_W-1:0] sel_aw, sel_ar;
  logic [W_DATA_W-1:0]     sel_w;
  logic [R_DATA_W-1:0]     sel_r;
  logic [B_DATA_W-1:0]     sel_b;




  // internal signals
  logic st_88_B;// to store the 88 bytes



  // internal regs
  logic [FDI_FLIT_WIDTH-1:0] flit_tx_data_hd;
  logic [1023:0]             left_b0;
  logic [1023:0]             wr_hdr_beat0_payload;




  // data flit signals
  logic [FDI_FLIT_WIDTH-1:0] flit_tx_data_d;
  logic [7:0]    left_over_beat_ind;
  logic [1023:0] left_over_beat;
  logic [7:0] fill_ptr;
  logic [7:0] space_left;




  logic rd_valid_d;
  logic w_rd_en,w_rd_en_d;
  logic w_buf_valid;
  logic consume_w_buf;
  logic can_pack_from_lat_w;
  logic fdi_tx_eop_h;
  logic fdi_tx_eop_d;
  logic last_leftover_pending;
  logic last_split_beat_in_progress;
  logic [8:0] w_beats_remaining;
  logic       wr_single_beat;
  logic       wr_multi_beat;
 
  assign last_split_beat_in_progress =
      (state == S_DATA) &&
      (lat_type == WRITE_REQ) &&
      w_buf_valid &&
      (space_left < 8'd128) &&
      sel_w[0];

  assign wr_single_beat = (lat_type == WRITE_REQ) && (lat_aw[52:45] == 8'd0);
  assign wr_multi_beat  = (lat_type == WRITE_REQ) && (lat_aw[52:45] != 8'd0);

  // valid for the header and data filt
   logic h_flit_tx_valid, d_flit_tx_valid;
  


   // selection of from which port ot read
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
 
  // latch the data from fifo
  always_ff @(posedge fdi_clk or negedge por_n) begin
  if (!por_n)
    rd_valid_d <= 0;
  else
    rd_valid_d <= (state == S_READ) ;
end




  always_ff @(posedge fdi_clk or negedge por_n) begin
  if (!por_n) begin
    lat_aw <= 0;
    lat_ar <= 0;
    lat_r  <= 0;
    lat_b  <= 0;
    wr_hdr_beat0_payload <= '0;
  end
  else if (!fdi_rst_n) begin
    lat_aw <= 0;
    lat_ar <= 0;
    lat_r  <= 0;
    lat_b  <= 0;
    wr_hdr_beat0_payload <= '0;
  end
  else begin
    if (rd_valid_d) begin
      lat_aw <= sel_aw;
      lat_ar <= sel_ar;
      lat_r  <= sel_r;
      lat_b  <= sel_b;
    end

    if ((state == S_HEADER) && (lat_type == WRITE_REQ) && !st_88_B && w_buf_valid)
      wr_hdr_beat0_payload <= sel_w[1152:129];
  end
end


// FSM
always_ff @(posedge fdi_clk or negedge por_n) begin
    if (!por_n) begin
     state <= S_IDLE;
     lat_type      <= NOP;
     lat_vcn       <= '0;
     lat_port      <= '0;
     lat_cr_opcode <= '0;
     lat_cr_piggy  <= '0;
     lat_cr_cnt    <= '0;
     lat_cr_vcn    <= '0;
    end else begin
       if (!fdi_rst_n) begin
          state <= S_IDLE;
          lat_type      <= NOP;
          lat_vcn       <= '0;
          lat_port      <= '0;
          lat_cr_opcode <= '0;
          lat_cr_piggy  <= '0;
          lat_cr_cnt    <= '0;
          lat_cr_vcn    <= '0;
       end
       else begin
           if ((state == S_IDLE) && start_txn) begin
             lat_type      <= txn_type;
             lat_vcn       <= vcn_sel;
             lat_port      <= port_id_i;
             lat_cr_opcode <= credit_rtn_opcode_en;
             lat_cr_piggy  <= credit_rtn_piggy_en;
             lat_cr_cnt    <= rx_credit_rtn_cnt;
             lat_cr_vcn    <= rx_credit_rtn_vcn;
           end
           state <= next_state;
       end
       end
       end




  // next state logic
  always_comb begin
   next_state = state;
          case (state)



            S_IDLE: begin
                  if (credit_rtn_opcode_en)
                    next_state = S_HEADER;
                 else if(txn_type != NOP && txn_type != CREDIT_RTN)
                    next_state = S_READ;
                 else
                   next_state = S_IDLE;
               end
       

            // fifo read
            S_READ: begin
               if (rd_valid_d)
                 next_state = S_HEADER;
               else
                 next_state = S_READ;
            end
           
           
            S_HEADER: begin
            if (h_flit_tx_valid) begin
              if ((lat_type != NOP) && (lat_type != WRITE_REQ))
                next_state = S_IDLE;
              else if (wr_single_beat)
                next_state = S_IDLE;
              else if (wr_multi_beat)
                next_state = S_DATA;
            end
            end


            S_DATA: begin
              if (d_flit_tx_valid  && fdi_tx_eop)
                 next_state = S_IDLE;
               else
                 next_state = S_DATA;
            end

            default: next_state = S_IDLE;
          endcase
       end
 
   
   
  always_comb begin
    aw_fifo0_rd_en = '0; w_fifo0_rd_en = '0;
    ar_fifo0_rd_en = '0; r_fifo0_rd_en = '0; b_fifo0_rd_en = '0;
    aw_fifo1_rd_en = '0; w_fifo1_rd_en = '0;
    ar_fifo1_rd_en = '0; r_fifo1_rd_en = '0; b_fifo1_rd_en = '0;
    w_rd_en        = 1'b0;




    if ((state == S_READ) && !rd_valid_d) begin
      case (lat_type)
        WRITE_REQ: begin
          if (!lat_port) aw_fifo0_rd_en = 1'b1;
          else           aw_fifo1_rd_en = 1'b1;
        end
        READ_REQ: begin
          if (!lat_port) ar_fifo0_rd_en = 1'b1;
          else           ar_fifo1_rd_en = 1'b1;
        end
        WRITE_RESP: begin
          if (!lat_port) b_fifo0_rd_en = 1'b1;
          else           b_fifo1_rd_en = 1'b1;
        end
        READ_RESP: begin
          if (!lat_port) r_fifo0_rd_en = 1'b1;
          else           r_fifo1_rd_en = 1'b1;
        end
        default: begin end
      endcase
    end




    if ((state == S_READ) && !rd_valid_d && (lat_type == WRITE_REQ) && !w_buf_valid)
      w_rd_en = 1'b1;
    else if ((state == S_HEADER) && (lat_type == WRITE_REQ) && st_88_B && !w_buf_valid )
      w_rd_en = 1'b1;
    else if ((state == S_DATA) && (lat_type == WRITE_REQ) &&
             (left_over_beat_ind == 0) && !w_buf_valid  && !last_leftover_pending &&
             !d_flit_tx_valid && !last_split_beat_in_progress &&
             (w_beats_remaining != 0))
      w_rd_en = 1'b1;
      
     else w_rd_en =1'b0;




    if (w_rd_en) begin
      if (!lat_port) w_fifo0_rd_en = 1'b1;
      else           w_fifo1_rd_en = 1'b1;
    end
  end




  always_ff @(posedge fdi_clk or negedge por_n) begin
    if (!por_n) begin
      //lat_w       <= '0;
      w_buf_valid <= 1'b0;
      w_beats_remaining <= '0;
    end
    else if (!fdi_rst_n) begin
      //lat_w       <= '0;
      w_buf_valid <= 1'b0;
      w_beats_remaining <= '0;
    end
    else begin
      if ((state == S_IDLE) && start_txn) begin
        w_beats_remaining <= '0;
      end
      if (state == S_HEADER) begin
        //lat_w <= sel_w;
      end
      if (rd_valid_d && (lat_type == WRITE_REQ)) begin
        // The first W beat is already fetched in S_READ, so only AWLEN
        // additional beats remain to be requested in HEADER/DATA.
        w_beats_remaining <= {1'b0, sel_aw[52:45]};
      end
      else if (w_rd_en && (w_beats_remaining != 0)) begin
        w_beats_remaining <= w_beats_remaining - 9'd1;
      end




      case ({w_rd_en, consume_w_buf})
        2'b10: w_buf_valid <= 1'b1;
        2'b01: w_buf_valid <= 1'b0;
        2'b11: w_buf_valid <= 1'b1;
        default: w_buf_valid <= w_buf_valid;
      endcase
    end
  end




  assign can_pack_from_lat_w =
      w_buf_valid &&
      (
        ((state == S_HEADER) && (lat_type == WRITE_REQ)) ||
        ((state == S_DATA) && (lat_type == WRITE_REQ) &&
         (left_over_beat_ind == 0) && !d_flit_tx_valid)
      );




  always_comb begin
    consume_w_buf = 1'b0;




    if ((state == S_HEADER) && (lat_type == WRITE_REQ)) begin
      if (!st_88_B && w_buf_valid)
        consume_w_buf = 1'b1;
      else if (st_88_B && w_buf_valid)
        consume_w_buf = 1'b1;
    end
    else if ((state == S_DATA) && can_pack_from_lat_w) begin
      consume_w_buf = 1'b1;
    end
  end





   
    // CREDIT DECREMENT
   
   assign tx_credit_decr_flag = (state == S_HEADER) && fdi_tx_ready && flit_tx_valid &&
                                !lat_cr_opcode && ((lat_vcn == 3'b000) || (lat_vcn == 3'b001));
  assign tx_credit_vcn       = lat_vcn;
 
  // credit return done
assign credit_rtn_done = (state == S_HEADER) && fdi_tx_ready && flit_tx_valid && lat_cr_opcode;
assign flit_tx_valid = h_flit_tx_valid | d_flit_tx_valid;

always_comb begin
  flit_tx_data_hd = '0;
  h_flit_tx_valid = 1'b0;
  fdi_tx_sop      = 1'b0;
  fdi_tx_eop_h    = 1'b0;

  if (state == S_HEADER) begin
    fdi_tx_sop             = 1'b1;
    flit_tx_data_hd[2:0]   = 3'b110;
    flit_tx_data_hd[5:3]   = lat_vcn;
    flit_tx_data_hd[6]     = 1'b1;
    flit_tx_data_hd[7]     = (lat_type != WRITE_REQ);
    flit_tx_data_hd[11:8]  = (lat_cr_opcode) ? {1'b0, CREDIT_RTN} : {1'b0, lat_type};
    flit_tx_data_hd[12]    = lat_port;
    flit_tx_data_hd[44]    = 1'b0;
    flit_tx_data_hd[255:128] = '0;

    if (lat_cr_opcode || lat_cr_piggy) begin
      flit_tx_data_hd[37:36] = lat_cr_vcn;
      flit_tx_data_hd[43:38] = lat_cr_cnt;
    end

    if (!lat_cr_opcode) begin
      case (lat_type)
        WRITE_REQ: begin
          flit_tx_data_hd[20:13] = lat_aw[60:53];
          flit_tx_data_hd[28:21] = lat_aw[52:45];
          flit_tx_data_hd[30:29] = lat_aw[44:43];
          flit_tx_data_hd[33:31] = lat_aw[42:40];
          flit_tx_data_hd[84:45] = lat_aw[39:0];
          flit_tx_data_hd[7]     = 1'b0;

          if (!st_88_B && w_buf_valid) begin
            flit_tx_data_hd[1983:960] = sel_w[1152:129];
            
          end
          else if (st_88_B && w_buf_valid) begin
            flit_tx_data_hd[1983:960] = wr_hdr_beat0_payload;
            flit_tx_data_hd[959:256] = sel_w[1152:449];
            //h_flit_tx_valid = 1'b1;
           
          end
          if (wr_single_beat && !st_88_B && w_buf_valid) begin
            h_flit_tx_valid = 1'b1;
           end
          else if (wr_multi_beat && st_88_B && w_buf_valid) begin
            h_flit_tx_valid = 1'b1;
           end
          else h_flit_tx_valid = 1'b0;
        end

        READ_REQ: begin
          flit_tx_data_hd[20:13] = lat_ar[60:53];
          flit_tx_data_hd[28:21] = lat_ar[52:45];
          flit_tx_data_hd[30:29] = lat_ar[44:43];
          flit_tx_data_hd[33:31] = lat_ar[42:40];
          flit_tx_data_hd[84:45] = lat_ar[39:0];
          flit_tx_data_hd[7]     = 1'b1;
          fdi_tx_eop_h           = 1'b1;
          h_flit_tx_valid        = 1'b1;
        end

        WRITE_RESP: begin
          flit_tx_data_hd[20:13] = lat_b[9:2];
          flit_tx_data_hd[35:34] = lat_b[1:0];
          flit_tx_data_hd[7]     = 1'b1;
          fdi_tx_eop_h           = 1'b1;
          h_flit_tx_valid        = 1'b1;
        end

        READ_RESP: begin
          flit_tx_data_hd[20:13]   = lat_r[10:3];
          flit_tx_data_hd[35:34]   = lat_r[2:1];
          flit_tx_data_hd[1983:256] = {lat_r[1034:11], 704'b0};
          flit_tx_data_hd[7]       = 1'b1;
          fdi_tx_eop_h             = 1'b1;
          h_flit_tx_valid          = 1'b1;
        end

        default: begin
          h_flit_tx_valid = 1'b0;
        end
      endcase
    end
    else begin
      flit_tx_data_hd[7] = 1'b1;
      fdi_tx_eop_h       = 1'b1;
      h_flit_tx_valid    = 1'b1;
    end
  end
end

always_ff @(posedge fdi_clk or negedge por_n) begin
  if (!por_n) begin
   st_88_B <= 1'b0;
    left_b0 <= '0;
  end
  else if (!fdi_rst_n) begin
   st_88_B <= 1'b0;
    left_b0 <= '0;
  end
  else if ((state == S_HEADER) && lat_type == WRITE_REQ && w_buf_valid && !wr_single_beat) begin
    if (!st_88_B) begin
      st_88_B <= 1'b1;
    end
    else begin
      st_88_B <= 1'b0;
      left_b0 <= {sel_w[448:129], 704'b0};
    end
  end
end
   
   
logic last_beat;
assign space_left = 8'd248 - fill_ptr;


	 // data flit assembly
	  always_ff @(posedge fdi_clk or negedge por_n) begin
	  if (!por_n) begin
	    fill_ptr           <= '0;
	    left_over_beat     <= '0;
	    left_over_beat_ind <= '0;
	    flit_tx_data_d     <= '0;
	    d_flit_tx_valid    <= '0;
	    last_leftover_pending <= 1'b0;
	  end
	  else if (!fdi_rst_n) begin
	    fill_ptr           <= '0;
	    left_over_beat     <= '0;
	    left_over_beat_ind <= '0;
	    flit_tx_data_d     <= '0;
	    d_flit_tx_valid    <= '0;
	    last_beat          <= 1'b0;
	    last_leftover_pending <= 1'b0;
	  end
	  else begin
	    if (state == S_HEADER && lat_type == WRITE_REQ && st_88_B && w_buf_valid) begin
	      left_over_beat     <= {sel_w[448:129], 704'b0};
	      left_over_beat_ind <= 8'd40;
	      fill_ptr           <= '0;
	      last_beat          <= 1'b0;
	      flit_tx_data_d     <= '0;
	      d_flit_tx_valid    <= 1'b0;
	      last_leftover_pending <= 1'b0;
	    end

	    if (state == S_DATA) begin
	      flit_tx_data_d[2047:1984] <= '0;

	      if (left_over_beat_ind > 0) begin
	        if (last_leftover_pending) begin
	          flit_tx_data_d[1983:0] <= ({left_over_beat, 960'b0} >> (fill_ptr * 8));
	          d_flit_tx_valid        <= 1'b1;
	          fill_ptr               <= '0;
	          last_beat              <= 1'b1;
	          last_leftover_pending  <= 1'b0;
	        end
	        else begin
	          flit_tx_data_d[1983:0] <= flit_tx_data_d[1983:0] | ({left_over_beat, 960'b0} >> (fill_ptr * 8));
	          fill_ptr               <= fill_ptr + left_over_beat_ind;
	        end
	        left_over_beat_ind      <= 0;
	      end
	      else if (w_buf_valid) begin
	        if (space_left >= 8'd128) begin
	          flit_tx_data_d[1983:0] <= flit_tx_data_d[1983:0] | ({sel_w[1152:129], 960'b0} >> (fill_ptr * 8));
	          fill_ptr               <= fill_ptr + 8'd128;
	          last_beat              <= sel_w[0];

	          if (sel_w[0] && (fill_ptr + 8'd128 < 8'd248)) begin
	             d_flit_tx_valid <= 1'b1;
	             fill_ptr        <= '0;
	          end
	          else if (fill_ptr + 8'd128 == 8'd248) begin
	            d_flit_tx_valid <= 1'b1;
	            fill_ptr        <= 0;
	          end
	        end
	        else begin
	          flit_tx_data_d[1983:0] <= flit_tx_data_d[1983:0] | ({sel_w[1152:129], 960'b0} >> (fill_ptr * 8));
	          left_over_beat         <= sel_w[1152:129] << (space_left * 8);
	          left_over_beat_ind     <= 8'd128 - space_left;
	          last_beat              <= 1'b0;
	          last_leftover_pending  <= sel_w[0];
	          d_flit_tx_valid        <= 1'b1;
	          fill_ptr               <= 0;
	        end
	      end

	      if (fdi_tx_ready && d_flit_tx_valid &&
	          !((left_over_beat_ind > 0) && last_leftover_pending)) begin
	           flit_tx_data_d  <= 0;
	           d_flit_tx_valid <= 0;
	      end
	    end
	    else begin
	      d_flit_tx_valid <= 1'b0;
	      flit_tx_data_d  <= '0;
	    end
	  end
	end



   // OUTPUT LOGIC
    always_comb begin
       if (state == S_HEADER) begin
        flit_tx_data = flit_tx_data_hd;
       end
       else if (state == S_DATA) begin
        flit_tx_data = flit_tx_data_d;
       end
       else begin
               flit_tx_data = '0;
        end
    end








// transaction id for thge completetion tracker
 always_comb begin
  if (lat_type == READ_REQ)
    tx_txn_id = lat_ar[60:53];
  else if (lat_type == WRITE_REQ) begin
    tx_txn_id = lat_aw[60:53];
  end
  else
    tx_txn_id = '0;
  end
 
  assign tx_port_id   = lat_port; // port_id
  assign tx_vcn       = (lat_vcn == 3'b00) ? 0 : 1  ; // vcn type
  assign tx_txn_valid = (state == S_HEADER) && h_flit_tx_valid && fdi_tx_ready && (lat_type == READ_REQ) && !credit_rtn_opcode_en; // transaction valid
 assign fdi_pktr_eop = (state == S_HEADER || state == S_DATA) &&  (h_flit_tx_valid || d_flit_tx_valid) && fdi_tx_ready && fdi_tx_eop; // eop for the port merge and the arbiter





// eop assingment from the header and data
always_comb begin
  fdi_tx_eop = 0;
  if ((state == S_HEADER) && wr_single_beat) begin
   fdi_tx_eop = 1'b1;
  end
  else if (state == S_HEADER) begin
    fdi_tx_eop = fdi_tx_eop_h;
  end
  else if (state == S_DATA) begin
    fdi_tx_eop = d_flit_tx_valid && last_beat;
  end
  else begin
    fdi_tx_eop = 0;
  end
end


  // detection of eop for data filt
   always_comb begin
    fdi_tx_eop_d = 0;
    if (state == S_DATA && d_flit_tx_valid)
      fdi_tx_eop_d = last_beat;
    else
      fdi_tx_eop_d = 0;
    end


endmodule



