/* Module Nmae : axfdi_axi_sub
   Clock Domain : AXI 500Mhz
*/

module axfdi_axi_sub #(                                  
    parameter AXI_DATA_W = 1024,
    parameter AXI_ADDR_W = 40,
    parameter AXI_ID_W   = 8
) (
    // clock and reset
    input  logic                    axi_clk,
    input  logic                    axi_rst_n,

    // Write Address Channel
    input  logic [AXI_ADDR_W-1:0]  awaddr,
    input  logic [AXI_ID_W-1:0]    awid,
    input  logic [7:0]              awlen,
    input  logic [2:0]              awsize,
    input  logic [1:0]              awburst,
    input  logic                    awvalid,
    output logic                    awready,

    // Write Data Channel
    input  logic [AXI_DATA_W-1:0]  wdata,
    input  logic [127:0]            wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    // Write Response Channel
    output logic [AXI_ID_W-1:0]    bid,
    output logic [1:0]              bresp,
    output logic                    bvalid,
    input  logic                    bready,

    // Read Address Channel
    input  logic [AXI_ADDR_W-1:0]  araddr,
    input  logic [AXI_ID_W-1:0]    arid,
    input  logic [7:0]              arlen,
    input  logic [2:0]              arsize,
    input  logic [1:0]              arburst,
    input  logic                    arvalid,
    output logic                    arready,

    // Read Data Channel
    output logic [AXI_DATA_W-1:0]  rdata,
    output logic [AXI_ID_W-1:0]    rid,
    output logic [1:0]              rresp,
    output logic                    rlast,
    output logic                    rvalid,
    input  logic                    rready,         

    // CDC FIFO ports — TX side 
    input  logic                    AW_cdc_full,
    output logic [60:0]             AW_cdc_data,    // {awid,awlen,awburst,awsize,awaddr}
    output logic                    AW_cdc_wr_en,   
    input  logic                    W_cdc_full,
    output logic [1152:0]           W_cdc_data,     // {wdata,wstrb,wlast}
    output logic                    W_cdc_wr_en,

    input  logic                    AR_cdc_full,
    output logic [60:0]             AR_cdc_data,    // {arid,arlen,arburst,arsize,araddr}
    output logic                    AR_cdc_wr_en,

    // CDC FIFO ports — RX side 
    input  logic                    B_cdc_empty,
    input  logic [9:0]              B_cdc_data,     // {bid,bresp}
    output logic                    B_cdc_rd_en,

    input  logic                    R_cdc_empty,
    input  logic [1034:0]           R_cdc_data,     // {rdata,rid,rresp,rlast}
    output logic                    R_cdc_rd_en
);


   // AW buffer signals
logic [60:0]    AW_buf_din;
logic [60:0]    AW_buf_dout;
logic           AW_buf_wr_en;
logic           AW_buf_rd_en;
logic           AW_buf_full;
logic           AW_buf_empty;

// W buffer signals
logic [1152:0]  W_buf_din;
logic [1152:0]  W_buf_dout;
logic           W_buf_wr_en;
logic           W_buf_rd_en;
logic           W_buf_full;
logic           W_buf_empty;

// AR buffer signals
logic [60:0]    AR_buf_din;
logic [60:0]    AR_buf_dout;
logic           AR_buf_wr_en;
logic           AR_buf_rd_en;
logic           AR_buf_full;
logic           AR_buf_empty;

// B buffer signals 
logic [9:0]     B_din;
logic [9:0]     B_buf_dout;
logic           B_buf_wr_en;
logic           B_buf_rd_en;
logic           B_buf_full;
logic           B_buf_empty;
logic           B_hold_valid;

// R buffer signals 
logic [1034:0]  R_buf_din;
logic [1034:0]  R_buf_dout;
logic           R_buf_wr_en;
logic           R_buf_rd_en;
logic           R_buf_full;
logic           R_buf_empty;


// AW channel signals AXI- Buffer
assign awready      = ~AW_buf_full;
assign AW_buf_din   = {awid, awlen, awburst, awsize, awaddr};
assign AW_buf_wr_en = awvalid & awready;  

// W channel Signal AXI- Buffer
assign wready      = ~W_buf_full;
assign W_buf_din   = {wdata, wstrb, wlast};   
assign W_buf_wr_en = wvalid & wready;

// AR channel Signal AXI- Buffer
assign arready      = ~AR_buf_full;
assign AR_buf_din   = {arid, arlen, arburst, arsize, araddr};
assign AR_buf_wr_en = arvalid & arready;


// fsm for paring the AW and W 
typedef enum logic [1:0] {
    IDLE    = 2'b00,    
    SEND_AW = 2'b01,    
    SEND_W  = 2'b10     
} pair_fsm;

pair_fsm  pair_state;     
pair_fsm  pair_next; 



always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        pair_state <= IDLE;
    end else begin
        pair_state <= pair_next;    
    end
end

always_comb begin
    pair_next    = pair_state;
    AW_buf_rd_en = 1'b0;
    W_buf_rd_en  = 1'b0;

    case (pair_state)

        IDLE: begin
            // AW and W pair
            if (!AW_buf_empty && !W_buf_empty) begin
                pair_next = SEND_AW;
            end
        end

        SEND_AW: begin
            if (!AW_cdc_full) begin
                AW_buf_rd_en = 1'b1;    
                pair_next    = SEND_W;  
            end
        end

        SEND_W: begin
            if (!W_buf_empty && !W_cdc_full) begin
                W_buf_rd_en = 1'b1;     
                if (W_buf_dout[0] == 1'b1) begin
                    // wlast == 1  next sate is idel
                    pair_next = IDLE;
                end
                else pair_next = SEND_W ;
            end
        end

        default: pair_next = IDLE;

    endcase
end

// AW info into the cdc fifo
assign AW_cdc_data  = AW_buf_dout;
assign AW_cdc_wr_en = AW_buf_rd_en;    

// W info into the cdc fifo
assign W_cdc_data   = W_buf_dout;
assign W_cdc_wr_en  = W_buf_rd_en;

// AR info into the cdc fifo
assign AR_buf_rd_en = ~AR_buf_empty & ~AR_cdc_full;
assign AR_cdc_data  = AR_buf_dout;
assign AR_cdc_wr_en = AR_buf_rd_en;


// b channel
assign B_cdc_rd_en = ~B_cdc_empty & ~B_hold_valid;

// Deliver B response to AXI master
always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        bvalid      <= 1'b0;
        bid         <= 8'h0;
        bresp       <= 2'b00;
        B_din       <= 10'h00;
        b_hold_valid<= 0    ;
    end else begin
         
        if (B_cdc_rd_en) begin
            B_din       <= B_cdc_data;
            B_hold_valid <= 1;
        end

       
        if (B_hold_valid) begin
            bvalid <= 1;
            bid    <= B_din[9:2];
            bresp  <= B_din[1:0];
        end

        
        if (bvalid && bready) begin
            bvalid       <= 0;
            B_hold_valid <= 0;
        end
    end
end

// R channel
assign R_cdc_rd_en = ~R_cdc_empty & ~R_buf_full;
assign R_buf_din   = R_cdc_data;
assign R_buf_wr_en = R_cdc_rd_en;

always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        rvalid      <= 1'b0;
        rdata       <= '0;
        rid         <= '0;
        rresp       <= 2'b00;
        rlast       <= 1'b0;
        R_buf_rd_en <= 1'b0;
    end else begin
        R_buf_rd_en <= 1'b0;    

        if (!R_buf_empty && !rvalid) begin
            rvalid      <= 1'b1;
            rlast       <= R_buf_dout[0];
            rresp       <= R_buf_dout[2:1];
            rid         <= R_buf_dout[10:3];
            rdata       <= R_buf_dout[1034:11];
            R_buf_rd_en <= 1'b1;
        end else if (rvalid && rready) begin
            rvalid <= 1'b0;
        end
    end
end

// TX Buffers
TX_BUFF axfdi_aw_buf #(.DEPTH(32), .DATA_WIDTH(61)) u_aw_buf (
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (AW_buf_wr_en),
    .data_in  (AW_buf_din),
    .r_en     (AW_buf_rd_en),
    .data_out (AW_buf_dout),
    .full     (AW_buf_full),
    .empty    (AW_buf_empty)
);

TX_BUFF axfdi_w_buf #(.DEPTH(64), .DATA_WIDTH(1153)) u_w_buf (  // 64 deep — W can arrive before AW
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (W_buf_wr_en),
    .data_in  (W_buf_din),
    .r_en     (W_buf_rd_en),
    .data_out (W_buf_dout),
    .full     (W_buf_full),
    .empty    (W_buf_empty)
);

TX_BUFF axfdi_ar_buf #(.DEPTH(32), .DATA_WIDTH(61)) u_ar_buf (
    .clk      (axi_clk),
    .rst_n    (axi_rst_n),
    .w_en     (AR_buf_wr_en),
    .data_in  (AR_buf_din),
    .r_en     (AR_buf_rd_en),
    .data_out (AR_buf_dout),
    .full     (AR_buf_full),
    .empty    (AR_buf_empty)
);


// RX buff for R channel
TX_BUFF R_RX_buff#(.DEPTH(256), .DATA_WIDTH(1035)) u_r_buf (
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
