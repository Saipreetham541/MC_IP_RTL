/* Module Name: axfdi_port_merge
   Clock Domain : FDI 625Mhz
   Engineer  : Vishwa Patwrai
   Company : Sevya Multimedia Technologies Pvt. Ltd.
*/

module axfdi_port_merge (
    input logic     fdi_clk,
    input logic     fdi_rst_n,
    input logic     por_n,
 
    input logic     AW_cdc_fifo_empty_0,// sub side port 0
    input logic     W_cdc_fifo_empty_0,// sub side port 0
    input logic     AR_cdc_fifo_empty_0,// sub side port 0
    input logic     R_cdc_fifo_empty_0,// mng side  port 0
    input logic     B_cdc_fifo_empty_0,// mng side  port 0

    input logic     AW_cdc_fifo_empty_1,// sub side  port1
    input logic     W_cdc_fifo_empty_1,// sub side  port1
    input logic     AR_cdc_fifo_empty_1,// sub side  port1
    input logic     R_cdc_fifo_empty_1,// mng side port1
    input logic     B_cdc_fifo_empty_1,// mng side port1

    input logic    eop, // end of packet form the packetizer
    input logic    crd_rtn, // credit return  

    output logic    port_id,
    output logic    write_req_vaild,
    output logic    read_req_vaild,
    output logic    write_resp_vaild,
    output logic    read_resp_vaild,
   // output logic  [1:0] vcn_sel  // 00 - NP , 01 - CPL , 10 -  VC_NP_HI  , 11 -VC_CPL_HI 
    //flag to the credit manager indicating pending tx available
    output logic pending_tx_available

);

   logic port0_data;
   logic port1_data;
   logic last_port;

   logic write_req_0;
   logic read_req_0;
   logic write_resp_0;
   logic read_resp_0;

   logic write_req_1;
   logic read_req_1;
   logic write_resp_1;
   logic read_resp_1;

   assign write_req_0 = ~AW_cdc_fifo_empty_0 & ~W_cdc_fifo_empty_0;
   assign read_req_0 = ~AR_cdc_fifo_empty_0;
   assign write_resp_0 = ~B_cdc_fifo_empty_0;
   assign read_resp_0 = ~R_cdc_fifo_empty_0;
   
   assign write_req_1 = ~AW_cdc_fifo_empty_1 & ~W_cdc_fifo_empty_1;
   assign read_req_1 = ~AR_cdc_fifo_empty_1;
   assign write_resp_1 = ~B_cdc_fifo_empty_1;
   assign read_resp_1 = ~R_cdc_fifo_empty_1;

  assign port0_data = write_req_0 | read_req_0 | write_resp_0 | read_resp_0;
  assign port1_data = write_req_1 | read_req_1 | write_resp_1 | read_resp_1;

   assign pending_tx_available = port0_data | port1_data;
   
   typedef enum logic [1:0] {
    IDLE    = 2'b00,    
    SEND_P0 = 2'b01,    
    SEND_P1 = 2'b10 ,
    CRD_RTN = 2'b11    
   } merge_fsm;

   merge_fsm cs;
   merge_fsm ns;

   always_ff @(posedge fdi_clk, negedge por_n) begin
    if (!por_n) begin
      cs <= IDLE;
      last_port <= 1'b1;
    end
    else begin
    if (!fdi_rst_n) begin
        cs <= IDLE;
        last_port <= 1'b1;
    end else begin
        cs <= ns; 

        if (cs == SEND_P0 && eop) begin
            last_port <= 1'b0;
        end
        else if (cs == SEND_P1 && eop) begin
            last_port <= 1'b1;
        end   
    end
end
end
   
   always_comb begin 
    ns =  cs;

     case (cs)
        IDLE:begin
            if (crd_rtn) begin
                ns = CRD_RTN;
            end 

            else if (port0_data && port1_data) begin
                if (last_port == 1) begin
                    ns = SEND_P0;
                end
                else begin
                    ns = SEND_P1;
                end
            end

            else if (port0_data) begin
                ns = SEND_P0;
            end
                
            else if (port1_data) begin
                ns = SEND_P1;
            end

            else ns = IDLE;
        end

        SEND_P0:begin
        if (eop) begin
            if (crd_rtn) begin
                ns = CRD_RTN;
            end
                
            else if (port1_data) begin
                ns = SEND_P1;
            end

            else if (port0_data) begin
                ns = SEND_P0;
            end

            else ns  = IDLE;
            end
        else begin
            ns = SEND_P0; 
        end
        end

         

        SEND_P1:begin
        if (eop)begin
            if (crd_rtn) begin
                ns = CRD_RTN;
            end
                
            else if (port0_data) begin
                ns = SEND_P0;
            end

            else if (port1_data) begin
                ns = SEND_P1;
            end

            else ns  = IDLE;
            end

        else begin
            ns = SEND_P1;
        end 
        end

        CRD_RTN:begin
        if (eop)begin
            if (port0_data && port1_data) begin
                if (last_port == 1) begin
                    ns = SEND_P0;
                end
                else begin
                    ns = SEND_P1;
                end
            end

            else if (port0_data) begin
                ns = SEND_P0;
            end
                
            else if (port1_data) begin
                ns = SEND_P1;
            end

            else ns = IDLE;
            end

            else begin
                ns = CRD_RTN;
            end
        end

        default: ns =   IDLE;
     endcase
    
   end

   always_ff @( posedge fdi_clk , negedge por_n) begin
    if (!por_n) begin
      write_req_vaild <= 0;
      read_req_vaild <= 0;
      write_resp_vaild <= 0;
      read_resp_vaild <= 0;
    end
    else begin
    if (!fdi_rst_n) begin
        write_req_vaild <= 0;
        read_req_vaild <= 0;
        write_resp_vaild <= 0;
        read_resp_vaild <= 0;
    end
    else begin
        case (cs)
            SEND_P0:begin
            write_req_vaild <= write_req_0;
            read_req_vaild <= read_req_0;
            write_resp_vaild <= write_resp_0;
            read_resp_vaild <= read_resp_0;
            end 
            SEND_P1:begin
            write_req_vaild <= write_req_1;
            read_req_vaild <= read_req_1;
            write_resp_vaild <= write_resp_1;
            read_resp_vaild <= read_resp_1;
            end
            default: begin
            write_req_vaild <= write_req_0;
            read_req_vaild <= read_req_0;
            write_resp_vaild <= write_resp_0;
            read_resp_vaild <= read_resp_0;
            end
        endcase
    end
    
   end
   end

   assign port_id = last_port;
    
endmodule
