/* Module Name: axfdi_axi_mgr
   Clock Domain : AXI 500Mhz
*/
module  axfdi_axi_mgr  #(                                  
    parameter AXI_DATA_W = 1024,
    parameter AXI_ADDR_W = 40,
    parameter AXI_ID_W   = 8
) (
    // clock and reset
    input logic                   axi_clk,
    input logic                   axi_rst_n,

    // Write Address Channel
    output logic [AXI_ADDR_W-1:0] awaddr,
    output logic [AXI_ID_W-1:0]   awid,
    output logic [7:0]            awlen,
    output logic [2:0]            awsize,
    output logic [1:0]            awburst,
    output logic                  awvalid,
    input logic                   awready,

    // Write Data Channel
    output logic [AXI_DATA_W-1:0] wdata,
    output logic [127:0]          wstrb,
    output logic                  wlast,
    output logic                  wvalid,
    input logic                   wready,

    // Write Response Channel
    input logic [AXI_ID_W-1:0]    bid,
    input logic [1:0]             bresp,
    input logic                   bvalid,
    output logic                  bready,

    // Read Address Channel
    output logic [AXI_ADDR_W-1:0] araddr,
    output logic [AXI_ID_W-1:0]   arid,
    output logic [7:0]            arlen,
    output logic [2:0]            arsize,
    output logic [1:0]            arburst,
    output logic                  arvalid,
    input logic                   arready,

    // Read Data Channel
    input logic [AXI_DATA_W-1:0]  rdata,
    input logic [AXI_ID_W-1:0]    rid,
    input logic [1:0]             rresp,
    input logic                   rlast,
    input logic                   rvalid,
    output logic                  rready,

    // CDC to mng 
    input logic [60:0]            AW_cdc_data,
    input logic                   AW_cdc_empty,
    output logic                  AW_cdc_rd_en,

    input logic [1152:0]          W_cdc_data,
    input logic                   W_cdc_empty,
    output logic                  W_cdc_rd_en,

    input logic [60:0]            AR_cdc_data,
    input logic                   AR_cdc_empty,
    output logic                  AR_cdc_rd_en,

    output logic [1034:0]         R_cdc_data,
    input logic                   R_cdc_full,
    output logic                  R_cdc_wr_en,

    output logic [9:0]            B_cdc_data,
    input logic                   B_cdc_full,
    output logic                  B_cdc_wr_en
);

    
logic [60:0]                         AR_buf_din;
logic [60:0]                         AR_buf_dout;
logic                                AR_buf_wr_en;
logic                                AR_buf_rd_en;
logic                                AR_buf_full;
logic                                AR_buf_empty;

logic [1034:0]                       R_buf_din;
logic [1034:0]                       R_buf_dout;
logic                                R_buf_wr_en;
logic                                R_buf_rd_en;
logic                                R_buf_full;
logic                                R_buf_empty;

 // AW buffer signals
logic [60:0]                         AW_buf_din;
logic [60:0]                         AW_buf_dout;
logic                                AW_buf_wr_en;
logic                                AW_buf_rd_en;
logic                                AW_buf_full;
logic                                AW_buf_empty;

// W buffer signals
logic [1152:0]                       W_buf_din;
logic [1152:0]                       W_buf_dout;
logic                                W_buf_wr_en;
logic                                W_buf_rd_en;
logic                                W_buf_full;
logic                                W_buf_empty;

// AW channel
assign AW_cdc_rd_en = ~AW_cdc_empty & ~AW_buf_full;
assign AW_buf_din   = AW_cdc_data;
assign AW_buf_wr_en = AW_cdc_rd_en;

// W channel
assign W_cdc_rd_en = ~W_cdc_empty & ~W_buf_full;
assign W_buf_din   = W_cdc_data;
assign W_buf_wr_en = W_cdc_rd_en;

// fsm for the sedn the burst data
typedef enum logic [1:0] {
    IDLE    = 2'b00,    
    SEND_AW = 2'b01,    
    SEND_W  = 2'b10     
} send_fsm;

send_fsm  send_state;     
send_fsm  send_next; 



always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        send_state <= IDLE;
    end else begin
        send_state <= send_next;    
    end
end

always_comb begin
    send_next    = send_state;
    AW_buf_rd_en = 1'b0;
    W_buf_rd_en  = 1'b0;

    case (send_state)

        IDLE: begin
            if (!AW_buf_empty && !W_buf_empty) begin
                send_next = SEND_AW;
            end
        end

        SEND_AW: begin
            if (awvalid && 
            
            awready) begin
                AW_buf_rd_en = 1'b1;    
                send_next    = SEND_W;  
            end
        end

        SEND_W: begin
            if (!W_buf_empty && wready) begin
                W_buf_rd_en = 1'b1;     
                if (W_buf_dout[0] == 1'b1) begin
                    // wlast == 1  next sate is idel
                    send_next = IDLE;
                end
                else send_next = SEND_W ;
            end
        end

        default: send_next = IDLE;

    endcase
end

always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        awvalid      <= 1'b0;
        awid          <= 8'h0;
        awlen         <= 8'h0;
        awburst       <= 2'h0;
        awsize        <= 3'h0;
        awaddr        <= 40'h0;

        wdata          <= 1024'h0;
        wstrb          <= 128'h0;
        wlast          <= 1'b0;
        wvalid         <= 1'b0;
        
    end else begin
            case (send_state)
                SEND_AW: begin
                if (!awvalid) begin
                      awvalid      <= 1'b1;
                          awid          <= AW_buf_dout[60:53];
                          awlen         <= AW_buf_dout[52:45];
                          awburst       <= AW_buf_dout[44:43];
                          awsize        <= AW_buf_dout[42:40];
                          awaddr        <= AW_buf_dout[39:0];
                end
                else if (awvalid && awready) begin
                        awvalid <= 1'b0; 
                end
                end
                SEND_W: begin
                if (!wvalid) begin
                    wdata          <= W_buf_dout[1152:129];
                    wstrb          <= W_buf_dout[128:1];
                    wlast          <= W_buf_dout[0];
                    wvalid         <= 1'b1;
                end
                else if (wvalid && wready) begin
                    if (!W_buf_empty) begin
                        wdata          <= W_buf_dout[1152:129];
                        wstrb          <= W_buf_dout[128:1];
                        wlast          <= W_buf_dout[0];
                        wvalid         <= 1'b1;
                    end
                    else wvalid <= 1'b0;
                         
                end
                end
                default: begin
                awvalid      <= 1'b0;
                awid          <= 8'h0;
                awlen         <= 8'h0;
                awburst       <= 2'h0;
                awsize        <= 3'h0;
                awaddr        <= 40'h0;
        
                wdata          <= 1024'h0;
                wstrb          <= 128'h0;
                wlast          <= 1'b0;
                wvalid         <= 1'b0;
                end
                  
            endcase
    end
end

// AR channel
assign AR_cdc_rd_en = ~AR_cdc_empty & ~AR_buf_full;
assign AR_buf_din   = AR_cdc_data;
assign AR_buf_wr_en = AR_cdc_rd_en;

always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        arvalid      <= 1'b0;
        arid          <= 8'h0;
        arlen         <= 8'h0;
        arburst       <= 2'h0;
        arsize        <= 3'h0;
        araddr        <= 40'h0;
        AR_buf_rd_en <= 1'b0;
    end else begin
        AR_buf_rd_en <= 1'b0;    

        if (!AR_buf_empty && !arvalid) begin
            arvalid      <= 1'b1;
            arid          <= AR_buf_dout[60:53];
            arlen         <= AR_buf_dout[52:45];
            arburst       <= AR_buf_dout[44:43];
            arsize        <= AR_buf_dout[42:40];
            araddr        <= AR_buf_dout[39:0];
            AR_buf_rd_en   <= 1'b1;
        end else if (arvalid && arready) begin
            arvalid <= 1'b0;
        end
    end
end

// R channel 
assign rready = !R_buf_full;
assign R_buf_din  = {rdata,rid,rresp,rlast};
assign R_buf_wr_en = rvalid && rready;

assign R_buf_rd_en = ~R_buf_empty & ~R_cdc_full;
assign R_cdc_data  = R_buf_dout;
assign R_cdc_wr_en = R_buf_rd_en;

// B channel   
assign bready = !B_cdc_full;
assign B_cdc_data  = {bid,bresp};
assign B_cdc_wr_en = bvalid && bready;

// buffers

TX_BUFF  #(.DEPTH(32), .DATA_WIDTH(61)) axfdi_aw_dispatch (
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (AW_buf_wr_en),
    .data_in  (AW_buf_din),
    .r_en     (AW_buf_rd_en),
    .data_out (AW_buf_dout),
    .full     (AW_buf_full),
    .empty    (AW_buf_empty)
);

TX_BUFF  #(.DEPTH(64), .DATA_WIDTH(1153)) axfdi_w_reassem ( 
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (W_buf_wr_en),
    .data_in  (W_buf_din),
    .r_en     (W_buf_rd_en),
    .data_out (W_buf_dout),
    .full     (W_buf_full),
    .empty    (W_buf_empty)
);

TX_BUFF  #(.DEPTH(32), .DATA_WIDTH(61)) axfdi_ar_dispatch (
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (AR_buf_wr_en),
    .data_in  (AR_buf_din),
    .r_en     (AR_buf_rd_en),
    .data_out (AR_buf_dout),
    .full     (AR_buf_full),
    .empty    (AR_buf_empty)
);

TX_BUFF  #(.DEPTH(256), .DATA_WIDTH(1035)) axfdi_r_reassem (
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (R_buf_wr_en),
    .data_in  (R_buf_din),
    .r_en     (R_buf_rd_en),
    .data_out (R_buf_dout),
    .full     (R_buf_full),         
    .empty    (R_buf_empty)
);



endmodule




