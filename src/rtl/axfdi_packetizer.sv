
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

    output logic                       tx_vcn,
    output logic [txn_id_w-1:0]        tx_txn_id,
    output logic                       tx_port_id,
    input logic                      tx_write_done,
    output logic                       tx_txn_valid,
    // -------- FDI --------
    output logic [FDI_FLIT_WIDTH-1:0] flit_tx_data,
    output logic                      flit_tx_valid,
    output logic                      fdi_tx_sop,
    output logic                      fdi_tx_eop,
    input logic                       fdi_tx_ready
);

    typedef enum logic [2:0] {
        WRITE_REQ  = 3'd0,
        READ_REQ   = 3'd1,
        WRITE_RESP = 3'd2,
        READ_RESP  = 3'd3,
        CREDIT_RTN = 3'd4,
        NOP        = 3'd5 
    } txn_t;


    // PORT MUX
    
    logic [AW_AR_DATA_W-1:0]   aw_data, ar_data;
    logic [W_DATA_W-1:0] w_data;
    logic [R_DATA_W-1:0] r_data;
    logic [B_DATA_W-1:0]    b_data;


    always_comb begin
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
    end

   
    // TX AVAILABLE
    
   /* always_comb begin
        pending_tx_available =
            WRITE_REQ ||
            READ_REQ ||
            WRITE_RESP ||
            READ_RESP;
    end */

    
    // START CONDITION
   
    logic start_txn;

    always_comb begin
        if (credit_rtn_opcode_en)
            start_txn = 1;
        else begin
            case (txn_type)
                WRITE_REQ:  start_txn = 1;
                READ_REQ:   start_txn = 1;
                WRITE_RESP: start_txn = 1;
                READ_RESP:  start_txn = 1;
                NOP      :  start_txn = 0;
                default:    start_txn = 0;
            endcase
        end
    end

   
    // FSM
    
    typedef enum logic [1:0] {IDLE, HEADER} state_t;
    state_t state, next_state;

    always_ff @(posedge fdi_clk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) state <= IDLE;
        else state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
          IDLE: if (start_txn) next_state = HEADER;
          HEADER: if (fdi_tx_ready) next_state = IDLE;
          //aravind: added default state
          default: next_state = state;
        endcase
    end

    
    // CREDIT DECREMENT
    
    always_comb begin
        tx_credit_decr_flag = 0;
        tx_credit_vcn       = 3'b0;

        if (state == HEADER && !credit_rtn_opcode_en) begin
            tx_credit_decr_flag = 1;
            tx_credit_vcn       = vcn_sel;
        end
    end

    // CREDIT DONE
    
    assign credit_rtn_done = (state == HEADER && fdi_tx_ready && credit_rtn_opcode_en);

    
    // OUTPUT LOGIC
    
    always_comb begin
        flit_tx_data  = '0;
        flit_tx_valid = 0;
        fdi_tx_sop    = 0;
        fdi_tx_eop    = 0;

        if (state == HEADER) begin
            flit_tx_valid = 1;
            fdi_tx_sop    = 1;
            fdi_tx_eop    = 1;

            // COMMON HEADER
            flit_tx_data[2:0]  = 3'b110;
            flit_tx_data[5:3]  = vcn_sel;
            flit_tx_data[6]    = 1;
            flit_tx_data[7]    = 1;
           //concated to match the size
            flit_tx_data[11:8] = (credit_rtn_opcode_en) ? {1'b0,CREDIT_RTN} : {1'b0,txn_type};
            flit_tx_data[12]   = port_id_i;

            // CREDIT FIELDS 
            if (credit_rtn_opcode_en || credit_rtn_piggy_en) begin
                flit_tx_data[37:36] = rx_credit_rtn_vcn;
                flit_tx_data[43:38] = rx_credit_rtn_cnt;
            end

            // NO WSTRB
            flit_tx_data[44] = 0;
            flit_tx_data[255:128] = 0;

            if (!credit_rtn_opcode_en) begin
                case (txn_type)

                    WRITE_REQ: begin
                        flit_tx_data[20:13] = aw_data[7:0];
                        flit_tx_data[28:21] = aw_data[15:8];
                        flit_tx_data[30:29] = aw_data[17:16];
                        flit_tx_data[33:31] = aw_data[20:18];
                        flit_tx_data[84:45] = aw_data[60:21];
                       //width mismatch: aravind
                        flit_tx_data[1983:256] = {w_data[1023:0], 704'b0}; //aravind
                    end

                    READ_REQ: begin
                        flit_tx_data[20:13] = ar_data[7:0];
                        flit_tx_data[28:21] = ar_data[15:8];
                        flit_tx_data[30:29] = ar_data[17:16];
                        flit_tx_data[33:31] = ar_data[20:18];
                        flit_tx_data[84:45] = ar_data[60:21];
                    end

                    WRITE_RESP: begin
                        flit_tx_data[20:13] = b_data[7:0];
                        flit_tx_data[35:34] = b_data[9:8];
                    end

                    READ_RESP: begin
                        flit_tx_data[20:13] = r_data[7:0];
                        flit_tx_data[35:34] = r_data[9:8];
                       //width mismatch: aravind
                        flit_tx_data[1983:256] = {r_data[1023:0], 704'b0};//aravind
                    end
                  //added default statement :aravind
                  default: begin
                     flit_tx_data[20:13] = '0;
                        flit_tx_data[35:34] = '0;
                        flit_tx_data[1983:256] = '0;
                  end
                endcase
            end
        end
    end

endmodule

