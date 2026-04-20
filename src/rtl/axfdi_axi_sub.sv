/* Module Name: axfdi_axi_sub
   Clock Domain : AXI 500Mhz
   Engineer  : Vishwa Patwrai
   Project Name: AXFDI Bridge
   Description: Flit Die-to-Die Interface
   Company : Sevya Multimedia Technologies Pvt. Ltd.
*/

module axfdi_axi_sub #(
  parameter AXI_DATA_W = 1024,
  parameter AXI_ADDR_W = 40,
  parameter AXI_ID_W   = 8,
  parameter AW_DEPTH   = 32,
  parameter W_DEPTH    = 64,
  parameter AR_DEPTH   = 32,
  parameter AW_W = AXI_ID_W + 8 + 2 + 3 + AXI_ADDR_W,
  parameter W_W  = AXI_DATA_W + 128 + 1,
  parameter AR_W = AXI_ID_W + 8 + 2 + 3 + AXI_ADDR_W,
  parameter B_W  = AXI_ID_W + 2,
  parameter R_W  = AXI_DATA_W + AXI_ID_W + 2 + 1
)(
  input  logic                   axi_clk,
  input  logic                   axi_rst_n,

  // AXI SUB Write Address
  input  logic [AXI_ADDR_W-1:0]  awaddr,
  input  logic [AXI_ID_W-1:0]    awid,
  input  logic [7:0]             awlen,
  input  logic [2:0]             awsize,
  input  logic [1:0]             awburst,
  input  logic                   awvalid,
  output logic                   awready,

  // AXI SUB Write Data
  input  logic [AXI_DATA_W-1:0]  wdata,
  input  logic [127:0]           wstrb,
  input  logic                   wlast,
  input  logic                   wvalid,
  output logic                   wready,

  // AXI SUB Write Response (
  output logic [AXI_ID_W-1:0]   bid,
  output logic [1:0]             bresp,
  output logic                   bvalid,
  input  logic                   bready,

  // AXI SUB Read Address
  input  logic [AXI_ADDR_W-1:0]  araddr,
  input  logic [AXI_ID_W-1:0]    arid,
  input  logic [7:0]             arlen,
  input  logic [2:0]             arsize,
  input  logic [1:0]             arburst,
  input  logic                   arvalid,
  output logic                   arready,

  // AXI SUB Read Data 
  output logic [AXI_DATA_W-1:0]  rdata,
  output logic [AXI_ID_W-1:0]   rid,
  output logic [1:0]             rresp,
  output logic                   rlast,
  output logic                   rvalid,
  input  logic                   rready,

  // TX CDC outputs 
  input  logic                   AW_cdc_full,
  output logic                   AW_cdc_wr_en,
  output logic [AW_W-1:0]        AW_cdc_data,

  input  logic                   W_cdc_full,
  output logic                   W_cdc_wr_en,
  output logic [W_W-1:0]         W_cdc_data,

  input  logic                   AR_cdc_full,
  output logic                   AR_cdc_wr_en,
  output logic [AR_W-1:0]        AR_cdc_data,

  // B channel output 
  output logic                   B_cdc_rd_en,
  input  logic [B_W-1:0]         B_cdc_data, 
  input  logic                   B_cdc_empty,

  //  R channel
  output logic                   R_cdc_rd_en,
  input  logic [R_W-1:0]         R_cdc_data,
  input  logic                   R_cdc_empty
);

  // AW TX buffer signals 
  logic [AW_W-1:0]  aw_buf_din, aw_buf_dout;
  logic             aw_buf_wen, aw_buf_ren;
  logic             aw_buf_full, aw_buf_empty;

  //  W TX buffer signals 
  logic [W_W-1:0]   w_buf_din, w_buf_dout;
  logic             w_buf_wen, w_buf_ren;
  logic             w_buf_full, w_buf_empty;

  // AR TX buffer signals
  logic [AR_W-1:0]  ar_buf_din, ar_buf_dout;
  logic             ar_buf_wen, ar_buf_ren;
  logic             ar_buf_full, ar_buf_empty;

  // R RX buffer signals 
  logic [R_W-1:0]   r_buf_din, r_buf_dout;
  logic             r_buf_wen, r_buf_ren;
  logic             r_buf_full, r_buf_empty;

  //reg for the write and read en
  logic             AW_cdc_wr_en_r;
  logic [AW_W-1:0]  AW_cdc_data_r;
  logic             W_cdc_wr_en_r;
  logic [W_W-1:0]   W_cdc_data_r;
  logic             AR_cdc_wr_en_r;
  logic [AR_W-1:0]  AR_cdc_data_r;
  logic [B_W-1:0]   B_din;

  // AW channel
  assign aw_buf_din = {awid, awlen, awburst, awsize, awaddr};
  assign awready    = ~aw_buf_full;
  assign aw_buf_wen = awvalid & awready;

  TX_BUFF #(.DEPTH(AW_DEPTH), .DATA_WIDTH(AW_W)) u_aw_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(aw_buf_wen), .r_en(aw_buf_ren),
    .data_in(aw_buf_din), .data_out(aw_buf_dout),
    .full(aw_buf_full), .empty(aw_buf_empty)
  );

  // W channel
  assign w_buf_din  = {wdata, wstrb, wlast};
  assign wready     = ~w_buf_full;
  assign w_buf_wen  = wvalid & wready;

  TX_BUFF #(.DEPTH(W_DEPTH), .DATA_WIDTH(W_W)) u_w_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(w_buf_wen), .r_en(w_buf_ren),
    .data_in(w_buf_din), .data_out(w_buf_dout),
    .full(w_buf_full), .empty(w_buf_empty)
  );

  //  AW+W Pair 
  wire pair_aw_w = ~aw_buf_empty & ~w_buf_empty
                 & ~AW_cdc_full  & ~W_cdc_full;

  assign aw_buf_ren = pair_aw_w;
  assign w_buf_ren  = pair_aw_w;


  always_ff @(posedge axi_clk ) begin
    if (!axi_rst_n) begin
      AW_cdc_wr_en_r <= '0;
      AW_cdc_data_r <= '0;
      W_cdc_wr_en_r  <= '0;
      W_cdc_data_r  <= '0;
    end else begin
      AW_cdc_wr_en_r <= pair_aw_w & ~AW_cdc_full;
      AW_cdc_data_r <= aw_buf_dout;
      W_cdc_wr_en_r  <= pair_aw_w & ~W_cdc_full;
      W_cdc_data_r  <= w_buf_dout;
    end
  end

  assign AW_cdc_wr_en = AW_cdc_wr_en_r;
  assign AW_cdc_data = AW_cdc_data_r;
  assign W_cdc_wr_en  = W_cdc_wr_en_r;
  assign W_cdc_data  = W_cdc_data_r;

  // AR Channel
  assign ar_buf_din = {arid, arlen, arburst, arsize, araddr};
  assign arready    = ~ar_buf_full;
  assign ar_buf_wen = arvalid & arready;

  TX_BUFF #(.DEPTH(AR_DEPTH), .DATA_WIDTH(AR_W)) u_ar_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(ar_buf_wen), .r_en(ar_buf_ren),
    .data_in(ar_buf_din), .data_out(ar_buf_dout),
    .full(ar_buf_full), .empty(ar_buf_empty)
  );

  assign ar_buf_ren = ~ar_buf_empty & ~AR_cdc_full;

  always_ff @(posedge axi_clk ) begin
    if (!axi_rst_n) begin
      AR_cdc_wr_en_r <= '0;
      AR_cdc_data_r <= '0;
    end else begin
      AR_cdc_wr_en_r <= ar_buf_ren & ~AR_cdc_full;
      AR_cdc_data_r <= ar_buf_dout;
    end
  end

  assign AR_cdc_wr_en = AR_cdc_wr_en_r;
  assign AR_cdc_data = AR_cdc_data_r;
  
  // B Channel
  
  logic B_hold_valid;
  logic b_cdc_pending;

  
always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        B_cdc_rd_en   <= 1'b0;
        bvalid       <= 1'b0;
        bid          <= '0;
        bresp        <= 2'b00;
        B_din        <= '0;
        B_hold_valid <= 1'b0;
        b_cdc_pending <= 1'b0;
    end else begin
        B_cdc_rd_en <= 1'b0;

        if (!b_cdc_pending) begin
            if (!B_cdc_empty && !B_hold_valid) begin
                B_cdc_rd_en   <= 1'b1;
                b_cdc_pending <= 1'b1;
            end
        end else begin
            B_din        <= B_cdc_data;
            B_hold_valid <= 1'b1;
            b_cdc_pending <= 1'b0;
        end

        if (B_hold_valid) begin
            bvalid <= 1'b1;
            bid    <= B_din[9:2];
            bresp  <= B_din[1:0];
        end

        if (bvalid && bready) begin
            bvalid       <= 1'b0;
            B_hold_valid <= 1'b0;
        end
    end
end


logic r_cdc_pending;
logic r_load_pending;

// R channel
assign r_buf_din   = R_cdc_data;

always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
        R_cdc_rd_en   <= 1'b0;
       
        r_buf_ren   <= 1'b0;
        rvalid <= 1'b0;
        rdata  <= '0;
        rid    <= '0;
        rresp  <= 2'b00;
        rlast  <= 1'b0;
        r_cdc_pending  <= 1'b0;
        r_load_pending <= 1'b0;
    end else begin
        R_cdc_rd_en <= 1'b0;
        r_buf_wen <= 1'b0;
       

      
        if (!r_cdc_pending) begin
            if (!R_cdc_empty && !r_buf_full) begin
                R_cdc_rd_en   <= 1'b1;
                r_cdc_pending <= 1'b1;
            end
        end else if (!r_buf_full) begin
            r_buf_ren   <= 1'b1;
            r_cdc_pending <= 1'b0;
        end

        
        if (r_load_pending) begin
            rvalid <= 1'b1;
            rlast  <= r_buf_dout[0];
            rresp  <= r_buf_dout[2:1];
            rid    <= r_buf_dout[10:3];
            rdata  <= r_buf_dout[1034:11];
            r_load_pending <= 1'b0;
        end else if (rvalid && rready) begin
            rvalid <= 1'b0;
        end else if (!r_buf_empty && !rvalid) begin
            r_buf_ren    <= 1'b1;
            r_load_pending <= 1'b1;
        end
    end
end

TX_BUFF #(.DEPTH(256), .DATA_WIDTH(R_W)) u_r_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(r_buf_wen), .r_en(r_buf_ren),
    .data_in(r_buf_din), .data_out(r_buf_dout),
    .full(r_buf_full), .empty(r_buf_empty)
  );

endmodule

