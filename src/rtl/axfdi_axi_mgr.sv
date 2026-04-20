/* Module Name: axfdi_axi_mgr
   Clock Domain : AXI 500Mhz
   Engineer  : Vishwa Patwrai
   Project Name: AXFDI Bridge
   Description: Flit Die-to-Die Interface
   Company : Sevya Multimedia Technologies Pvt. Ltd.
*/
module axfdi_axi_mgr #(
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

  // AXI mng Write Address
  output logic [AXI_ADDR_W-1:0]  awaddr,
  output logic [AXI_ID_W-1:0]    awid,
  output logic [7:0]             awlen,
  output logic [2:0]             awsize,
  output logic [1:0]             awburst,
  output logic                   awvalid,
  input  logic                   awready,

  // AXI mng Write Data
  output logic [AXI_DATA_W-1:0]  wdata,
  output logic [127:0]           wstrb,
  output logic                   wlast,
  output logic                   wvalid,
  input  logic                   wready,

  // AXI mng Write Response
  input  logic [AXI_ID_W-1:0]    bid,
  input  logic [1:0]             bresp,
  input  logic                   bvalid,
  output logic                   bready,

  // AXI mng Read Address
  output logic [AXI_ADDR_W-1:0]  araddr,
  output logic [AXI_ID_W-1:0]    arid,
  output logic [7:0]             arlen,
  output logic [2:0]             arsize,
  output logic [1:0]             arburst,
  output logic                   arvalid,
  input  logic                   arready,

  // AXI mng Read Data
  input  logic [AXI_DATA_W-1:0]  rdata,
  input  logic [AXI_ID_W-1:0]    rid,
  input  logic [1:0]             rresp,
  input  logic                   rlast,
  input  logic                   rvalid,
  output logic                   rready,

  // CDC to mng
  input  logic [60:0]            AW_cdc_data,
  input  logic                   AW_cdc_empty,
  output logic                   AW_cdc_rd_en,

  input  logic [1152:0]          W_cdc_data,
  input  logic                   W_cdc_empty,
  output logic                   W_cdc_rd_en,

  input  logic [60:0]            AR_cdc_data,
  input  logic                   AR_cdc_empty,
  output logic                   AR_cdc_rd_en,

  output logic [1034:0]          R_cdc_data,
  input  logic                   R_cdc_full,
  output logic                   R_cdc_wr_en,

  output logic [9:0]             B_cdc_data,
  input  logic                   B_cdc_full,
  output logic                   B_cdc_wr_en
);

  // AW TX buffer signals
  logic [AW_W-1:0]  aw_buf_din, aw_buf_dout;
  logic             aw_buf_wen, aw_buf_ren;
  logic             aw_buf_full, aw_buf_empty;

  // W TX buffer signals
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

  logic [AW_W-1:0]  AW_hold_data;
  logic [W_W-1:0]   W_hold_data;
  logic [AR_W-1:0]  AR_hold_data;

  logic             AW_cdc_pending, AW_buf_wr_pending, AW_buf_rd_pending, AW_load_pending;
  logic             W_cdc_pending,  W_buf_wr_pending,  W_buf_rd_pending,  W_load_pending;
  logic             AR_cdc_pending, AR_buf_wr_pending, AR_buf_rd_pending, AR_load_pending;
  
  logic r_rd_pending,R_cdc_wr_en_r;
  logic [1034:0] R_cdc_data_r;

  // AR channel
  assign ar_buf_din = AR_hold_data;

  always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
      AR_cdc_rd_en      <= 1'b0;
      ar_buf_wen        <= 1'b0;
      ar_buf_ren        <= 1'b0;
      arvalid           <= 1'b0;
      arid              <= '0;
      arlen             <= '0;
      arsize            <= '0;
      arburst           <= '0;
      araddr            <= '0;
      AR_hold_data      <= '0;
      AR_cdc_pending    <= 1'b0;
      AR_buf_wr_pending <= 1'b0;
      AR_buf_rd_pending <= 1'b0;
      AR_load_pending   <= 1'b0;
    end else begin
      AR_cdc_rd_en <= 1'b0;
      ar_buf_wen   <= 1'b0;
      ar_buf_ren   <= 1'b0;

      if (!AR_cdc_pending && !AR_buf_wr_pending) begin
        if (!AR_cdc_empty && !ar_buf_full) begin
          AR_cdc_rd_en   <= 1'b1;
          AR_cdc_pending <= 1'b1;
        end
      end else if (AR_cdc_pending) begin
        AR_hold_data      <= AR_cdc_data;
        AR_cdc_pending    <= 1'b0;
        AR_buf_wr_pending <= 1'b1;
      end else if (AR_buf_wr_pending) begin
        if (!ar_buf_full) begin
          ar_buf_wen        <= 1'b1;
          AR_buf_wr_pending <= 1'b0;
        end
      end

      if (AR_load_pending) begin
        arvalid         <= 1'b1;
        arid            <= ar_buf_dout[60:53];
        arlen           <= ar_buf_dout[52:45];
        arburst         <= ar_buf_dout[44:43];
        arsize          <= ar_buf_dout[42:40];
        araddr          <= ar_buf_dout[39:0];
        AR_load_pending <= 1'b0;
      end else if (arvalid && arready) begin
        arvalid <= 1'b0;
      end else if (!AR_buf_rd_pending && !ar_buf_empty && !arvalid) begin
        ar_buf_ren       <= 1'b1;
        AR_buf_rd_pending <= 1'b1;
      end else if (AR_buf_rd_pending) begin
        AR_buf_rd_pending <= 1'b0;
        AR_load_pending   <= 1'b1;
      end
    end
  end

  TX_BUFF #(.DEPTH(AR_DEPTH), .DATA_WIDTH(AR_W)) u_ar_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(ar_buf_wen), .r_en(ar_buf_ren),
    .data_in(ar_buf_din), .data_out(ar_buf_dout),
    .full(ar_buf_full), .empty(ar_buf_empty)
  );

  // AW channel
  assign aw_buf_din = AW_hold_data;

  always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
      AW_cdc_rd_en      <= 1'b0;
      aw_buf_wen        <= 1'b0;
      aw_buf_ren        <= 1'b0;
      awvalid           <= 1'b0;
      awid              <= '0;
      awlen             <= '0;
      awsize            <= '0;
      awburst           <= '0;
      awaddr            <= '0;
      AW_hold_data      <= '0;
      AW_cdc_pending    <= 1'b0;
      AW_buf_wr_pending <= 1'b0;
      AW_buf_rd_pending <= 1'b0;
      AW_load_pending   <= 1'b0;
    end else begin
      AW_cdc_rd_en <= 1'b0;
      aw_buf_wen   <= 1'b0;
      aw_buf_ren   <= 1'b0;

      if (!AW_cdc_pending && !AW_buf_wr_pending) begin
        if (!AW_cdc_empty && !aw_buf_full) begin
          AW_cdc_rd_en   <= 1'b1;
          AW_cdc_pending <= 1'b1;
        end
      end else if (AW_cdc_pending) begin
        AW_hold_data      <= AW_cdc_data;
        AW_cdc_pending    <= 1'b0;
        AW_buf_wr_pending <= 1'b1;
      end else if (AW_buf_wr_pending) begin
        if (!aw_buf_full) begin
          aw_buf_wen        <= 1'b1;
          AW_buf_wr_pending <= 1'b0;
        end
      end

      if (AW_load_pending) begin
        awvalid         <= 1'b1;
        awid            <= aw_buf_dout[60:53];
        awlen           <= aw_buf_dout[52:45];
        awburst         <= aw_buf_dout[44:43];
        awsize          <= aw_buf_dout[42:40];
        awaddr          <= aw_buf_dout[39:0];
        AW_load_pending <= 1'b0;
      end else if (awvalid && awready) begin
        awvalid <= 1'b0;
      end else if (!AW_buf_rd_pending && !aw_buf_empty && !awvalid) begin
        aw_buf_ren        <= 1'b1;
        AW_buf_rd_pending <= 1'b1;
      end else if (AW_buf_rd_pending) begin
        AW_buf_rd_pending <= 1'b0;
        AW_load_pending   <= 1'b1;
      end
    end
  end

  TX_BUFF #(.DEPTH(AW_DEPTH), .DATA_WIDTH(AW_W)) u_aw_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(aw_buf_wen), .r_en(aw_buf_ren),
    .data_in(aw_buf_din), .data_out(aw_buf_dout),
    .full(aw_buf_full), .empty(aw_buf_empty)
  );

  // W channel
  assign w_buf_din = W_hold_data;

  always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
      W_cdc_rd_en      <= 1'b0;
      w_buf_wen        <= 1'b0;
      w_buf_ren        <= 1'b0;
      wvalid           <= 1'b0;
      wdata            <= '0;
      wstrb            <= '0;
      wlast            <= '0;
      W_hold_data      <= '0;
      W_cdc_pending    <= 1'b0;
      W_buf_wr_pending <= 1'b0;
      W_buf_rd_pending <= 1'b0;
      W_load_pending   <= 1'b0;
    end else begin
      W_cdc_rd_en <= 1'b0;
      w_buf_wen   <= 1'b0;
      w_buf_ren   <= 1'b0;

      if (!W_cdc_pending && !W_buf_wr_pending) begin
        if (!W_cdc_empty && !w_buf_full) begin
          W_cdc_rd_en   <= 1'b1;
          W_cdc_pending <= 1'b1;
        end
      end else if (W_cdc_pending) begin
        W_hold_data      <= W_cdc_data;
        W_cdc_pending    <= 1'b0;
        W_buf_wr_pending <= 1'b1;
      end else if (W_buf_wr_pending) begin
        if (!w_buf_full) begin
          w_buf_wen        <= 1'b1;
          W_buf_wr_pending <= 1'b0;
        end
      end

      if (W_load_pending) begin
        wvalid         <= 1'b1;
        wdata          <= w_buf_dout[1152:129];
        wstrb          <= w_buf_dout[128:1];
        wlast          <= w_buf_dout[0];
        W_load_pending <= 1'b0;
      end else if (wvalid && wready) begin
        wvalid <= 1'b0;
      end else if (!W_buf_rd_pending && !w_buf_empty && !wvalid) begin
        w_buf_ren        <= 1'b1;
        W_buf_rd_pending <= 1'b1;
      end else if (W_buf_rd_pending) begin
        W_buf_rd_pending <= 1'b0;
        W_load_pending   <= 1'b1;
      end
    end
  end

  TX_BUFF #(.DEPTH(W_DEPTH), .DATA_WIDTH(W_W)) u_w_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(w_buf_wen), .r_en(w_buf_ren),
    .data_in(w_buf_din), .data_out(w_buf_dout),
    .full(w_buf_full), .empty(w_buf_empty)
  );

  // B channel
  assign bready      = ~B_cdc_full;
  assign B_cdc_wr_en = bvalid & bready;
  assign B_cdc_data  = {bid, bresp};



  // R channel
  assign r_buf_din = {rdata, rid, rresp, rlast};
  assign rready    = ~r_buf_full;
  assign r_buf_wen = rvalid & rready;

  TX_BUFF #(.DEPTH(256), .DATA_WIDTH(R_W)) u_r_buf (
    .clk(axi_clk), .rst_n(axi_rst_n),
    .w_en(r_buf_wen), .r_en(r_buf_ren),
    .data_in(r_buf_din), .data_out(r_buf_dout),
    .full(r_buf_full), .empty(r_buf_empty)
  );

  always_ff @(posedge axi_clk) begin
    if (!axi_rst_n) begin
      R_cdc_wr_en_r <= 1'b0;
      R_cdc_data_r  <= '0;
      r_rd_pending  <= 1'b0;
    end else begin
      R_cdc_wr_en_r <= 1'b0;

      if (~r_rd_pending) begin
        if (~r_buf_empty & ~R_cdc_full) begin
          r_rd_pending <= 1'b1;
        end
      end else if (~R_cdc_full) begin
        R_cdc_wr_en_r <= 1'b1;
        R_cdc_data_r  <= r_buf_dout;
        r_rd_pending  <= 1'b0;
      end
    end
  end

  assign r_buf_ren  = ~r_buf_empty & ~R_cdc_full & ~r_rd_pending;
  assign R_cdc_wr_en = R_cdc_wr_en_r;
  assign R_cdc_data  = R_cdc_data_r;

endmodule






