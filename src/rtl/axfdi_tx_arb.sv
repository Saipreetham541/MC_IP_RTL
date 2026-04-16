module axfdi_tx_arb  
(
    input logic    fdi_clk,
    input logic    fdi_rst_n,
     
    //signals from the port merge
    input logic    port_id_i,
    input logic    write_req_vaild,
    input logic    read_req_vaild,
    input logic    write_resp_vaild,
    input logic    read_resp_vaild,
   
    // from the packetizer
    input logic    eop,
   
    // from the csr
    input logic    [3:0]vcn_np_weig,
    input logic    [3:0]vcn_cpl_weig,


    // from the credit manager
    input logic    tx_vc_cpl_credit_ind,
    input logic    tx_vc_np_credit_ind,
  //input logic    vcn_hi_np_weig,
  //input logic    vcn_hi_cpl_weig,
    input logic    crd_rtn,
   
    //ouptut to the packetizer
    output logic   [2:0] txn_type,
    output logic   [1:0] vcn_sel,
    output logic        port_id_o
);
    //vcn for arbitration
    logic  cpl_valid;
    logic  np_vaild;
    logic cpl_txn_vaild;
    logic np_txn_vaild;
   
    // counter for the weights
    logic [3:0] cpl_cnt;
    logic [3:0] np_cnt;
    logic reload;
    logic [3:0] cpl_cnt_next, np_cnt_next;
    
    logic crd_rtn_valid;


   
    //vcn for arbitration
    assign np_vaild = write_req_vaild | read_req_vaild ;
    assign cpl_valid = write_resp_vaild | read_resp_vaild ;


    assign cpl_txn_vaild = (cpl_valid) && (cpl_cnt > 0) && (!tx_vc_cpl_credit_ind);
    assign np_txn_vaild = (np_vaild) && (np_cnt > 0) && (!tx_vc_np_credit_ind);


    // txn_type
     typedef enum logic [2:0] {
    WRITE_REQ    = 3'b000,    
    READ_REQ     = 3'b001,
    WRITE_RESP   = 3'b010,
    READ_RESP    = 3'b011,
    CREDIT_RTN   = 3'b100,
    NOP          = 3'b101    
     } opcode;


     opcode  s_txn_type;
     opcode  r_txn_type;
     opcode  s_last_req;
     opcode  r_last_req;
     opcode  s_last_resp;
     opcode  r_last_resp;


    //vcn type
     typedef enum logic [1:0] {
    VCN_CPL    = 2'b00,    
    VCN_NP     = 2'b01,
    VCN_HI_NP  = 2'b10,
    VCN_HI_CPL = 2'b11    
     } VCN;


     VCN  s_vcn_sel;
     VCN  r_vcn_sel;


    // arbiter fsm
    typedef enum logic [1:0] {
    IDLE    = 2'b00,    
    CPL     = 2'b01,
    NP      = 2'b10    
    } ar_fsm;


    ar_fsm cs;
    ar_fsm ns;


// decrement of the counters when one cpl or np is done
always_comb begin
    cpl_cnt_next = cpl_cnt;
    np_cnt_next  = np_cnt;


    if (eop) begin
        case (vcn_sel)
            VCN_CPL: if (cpl_cnt > 0)
                        cpl_cnt_next = cpl_cnt - 1;


            VCN_NP : if (np_cnt > 0)
                        np_cnt_next = np_cnt - 1;
        endcase
    end
end


assign reload = (cpl_cnt_next == 0) && (np_cnt_next == 0);
   
    always_ff @(posedge fdi_clk) begin
    if (!fdi_rst_n) begin
        cpl_cnt <= vcn_cpl_weig;
        np_cnt  <= vcn_np_weig;
    end
    else if (eop) begin
        if (reload) begin
            cpl_cnt <= vcn_cpl_weig;
            np_cnt  <= vcn_np_weig;
        end
        else begin
            cpl_cnt <= cpl_cnt_next;
            np_cnt  <= np_cnt_next;
        end
    end
end


    // perent state logc
    always_ff @( posedge fdi_clk  ) begin
        if (!fdi_rst_n) begin
            cs <= IDLE;
        end
        else begin
            cs <= ns;
        end
       
    end
   
    // next state logc
    always_comb begin
        ns = cs;
         if (crd_rtn) begin
            ns = IDLE;
         end
        else begin
            if (eop)begin
            case (cs)
                IDLE:begin
                    if(cpl_txn_vaild)begin
                        ns = CPL;
                    end
                    else if (np_txn_vaild) begin
                        ns = NP;
                    end
                end


                CPL:begin
                    if (cpl_txn_vaild && (cpl_cnt >= np_cnt)) begin
                        ns = CPL;
                    end
                    else if (np_txn_vaild) begin
                        ns = NP;
                    end
                end
                NP: begin
                    if(cpl_txn_vaild)begin
                        ns = CPL;
                    end
                    else begin
                        ns = IDLE;
                    end
                end
                default: ns = IDLE;
            endcase
        end
        end
        else begin
            ns = cs;
        end
    end


    always_comb begin
        s_txn_type =  r_txn_type ;
        s_vcn_sel = r_vcn_sel;
        s_last_resp = r_last_resp;
        s_last_req = r_last_req;


        case (cs)
            IDLE:begin
                s_txn_type = NOP;
                s_vcn_sel = VCN_CPL;
            end
            CPL:begin
                 s_vcn_sel = VCN_CPL;
                if((write_resp_vaild && r_last_resp != WRITE_RESP)|| (write_resp_vaild && !read_resp_vaild))begin
                    s_txn_type = WRITE_RESP;
                    s_last_resp = WRITE_RESP;
                   
                end
                else if ((read_resp_vaild && r_last_resp != READ_RESP)|| (read_resp_vaild && !write_resp_vaild )) begin
                    s_txn_type = READ_RESP;
                    s_last_resp = READ_RESP;
                end
            end
            NP:begin
                 s_vcn_sel = VCN_NP;
                if((write_req_vaild && r_last_req != WRITE_REQ) || (write_req_vaild && !read_req_vaild))begin
                    s_txn_type = WRITE_REQ;
                    s_last_req = WRITE_REQ;
                   
                end
                else if ((read_req_vaild && r_last_req != READ_REQ) ||  (read_req_vaild && !write_req_vaild)) begin
                    s_txn_type = READ_REQ;
                    s_last_req = READ_REQ;
                end
            end
            default: begin
            s_txn_type =  r_txn_type ;
            s_vcn_sel = r_vcn_sel;
            s_last_resp = r_last_resp;
            s_last_req = r_last_req;
            end
        endcase
    end


    always_ff @( posedge fdi_clk ) begin
        if(!fdi_rst_n)begin
            r_txn_type <= NOP;
            r_vcn_sel <= VCN_CPL;
            r_last_resp <= READ_REQ;
            r_last_req <= READ_RESP;
        end
        else begin
            port_id_o <= port_id_i;
            if(crd_rtn_valid)begin 
            r_txn_type <= CREDIT_RTN;
            end 
            else begin
            r_txn_type <= s_txn_type;
            r_vcn_sel <= s_vcn_sel;
            end
            r_last_resp <= s_last_resp;
            r_last_req <= s_last_req;
            
        end
    end

   assign crd_rtn_valid = crd_rtn;
   assign txn_type = r_txn_type;
   assign vcn_sel = r_vcn_sel;
endmodule


