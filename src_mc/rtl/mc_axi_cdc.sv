module mc_axi_cdc (

    // =========================================================
    // CLOCKS AND RESETS
    // =========================================================
    input  logic aclk,
    input  logic aresetn,

    input  logic dfi_clk,
    input  logic ctl_reset_n,

    // =========================================================
    // AW CHANNEL: AXI -> CONTROLLER
    // Width = 72 bits, Depth = 8
    // =========================================================
    input  logic [7:0]  s_awid,
    input  logic [7:0]  s_awlen,
    input  logic [2:0]  s_awsize,
    input  logic [1:0]  s_awburst,
    input  logic [39:0] s_awaddr,
    input  logic [3:0]  s_awqos,
    input  logic [3:0]  s_awcache,
    input  logic [2:0]  s_awprot,
    input  logic        s_awvalid,
    output logic        s_awready,

    output logic [7:0]  m_awid,
    output logic [7:0]  m_awlen,
    output logic [2:0]  m_awsize,
    output logic [1:0]  m_awburst,
    output logic [39:0] m_awaddr,
    output logic [3:0]  m_awqos,
    output logic [3:0]  m_awcache,
    output logic [2:0]  m_awprot,
    output logic        m_awvalid,
    input  logic        m_awready,

    // =========================================================
    // DECODED WRITE ADDRESS: CONTROLLER DOMAIN
    // =========================================================
    output logic [3:0]  m_aw_ch_sel,
    output logic        m_aw_pc_sel,
    output logic [13:0] m_aw_row_addr,
    output logic [1:0]  m_aw_bank_group,
    output logic [1:0]  m_aw_bank_addr,
    output logic [4:0]  m_aw_col_addr,

    // =========================================================
    // W CHANNEL: AXI -> CONTROLLER
    // Width = 289 bits, Depth = 16
    // =========================================================
    input  logic [255:0] s_wdata,
    input  logic [31:0]  s_wstrb,
    input  logic         s_wlast,
    input  logic         s_wvalid,
    output logic         s_wready,

    output logic [255:0] m_wdata,
    output logic [31:0]  m_wstrb,
    output logic         m_wlast,
    output logic         m_wvalid,
    input  logic         m_wready,

    // =========================================================
    // AR CHANNEL: AXI -> CONTROLLER
    // Width = 72 bits, Depth = 8
    // =========================================================
    input  logic [7:0]  s_arid,
    input  logic [7:0]  s_arlen,
    input  logic [2:0]  s_arsize,
    input  logic [1:0]  s_arburst,
    input  logic [39:0] s_araddr,
    input  logic [3:0]  s_arqos,
    input  logic [3:0]  s_arcache,
    input  logic [2:0]  s_arprot,
    input  logic        s_arvalid,
    output logic        s_arready,

    output logic [7:0]  m_arid,
    output logic [7:0]  m_arlen,
    output logic [2:0]  m_arsize,
    output logic [1:0]  m_arburst,
    output logic [39:0] m_araddr,
    output logic [3:0]  m_arqos,
    output logic [3:0]  m_arcache,
    output logic [2:0]  m_arprot,
    output logic        m_arvalid,
    input  logic        m_arready,

    // =========================================================
    // DECODED READ ADDRESS: CONTROLLER DOMAIN
    // =========================================================
    output logic [3:0]  m_ar_ch_sel,
    output logic        m_ar_pc_sel,
    output logic [13:0] m_ar_row_addr,
    output logic [1:0]  m_ar_bank_group,
    output logic [1:0]  m_ar_bank_addr,
    output logic [4:0]  m_ar_col_addr,

    // =========================================================
    // B CHANNEL: CONTROLLER -> AXI
    // Width = 10 bits, Depth = 8
    // =========================================================
    input  logic [7:0] m_bid,
    input  logic [1:0] m_bresp,
    input  logic       m_bvalid,
    output logic       m_bready,

    output logic [7:0] s_bid,
    output logic [1:0] s_bresp,
    output logic       s_bvalid,
    input  logic       s_bready,

    // =========================================================
    // R CHANNEL: CONTROLLER -> AXI
    // Width = 267 bits, Depth = 16
    // =========================================================
    input  logic [7:0]   m_rid,
    input  logic [255:0] m_rdata,
    input  logic [1:0]   m_rresp,
    input  logic         m_rlast,
    input  logic         m_rvalid,
    output logic         m_rready,

    output logic [7:0]   s_rid,
    output logic [255:0] s_rdata,
    output logic [1:0]   s_rresp,
    output logic         s_rlast,
    output logic         s_rvalid,
    input  logic         s_rready
);

    // =========================================================
    // 1. PACK AXI FIELDS INTO FIFO WORDS
    // =========================================================

    logic [71:0]  aw_wdata, aw_rdata;
    logic [288:0] w_wdata,  w_rdata;
    logic [71:0]  ar_wdata, ar_rdata;
    logic [9:0]   b_wdata,  b_rdata;
    logic [266:0] r_wdata,  r_rdata;

    assign aw_wdata = {
        s_awid, s_awlen, s_awsize, s_awburst,
        s_awaddr, s_awqos, s_awcache, s_awprot
    };

    assign w_wdata = {s_wdata, s_wstrb, s_wlast};

    assign ar_wdata = {
        s_arid, s_arlen, s_arsize, s_arburst,
        s_araddr, s_arqos, s_arcache, s_arprot
        };

    assign b_wdata = {m_bid, m_bresp};

    assign r_wdata = {m_rid, m_rdata, m_rresp, m_rlast};


    // =========================================================
    // 2. AW FIFO: aclk -> dfi_clk
    // =========================================================

    mc_async_fifo #(
        .DATA_WIDTH (72),
        .DEPTH      (8)
    ) u_aw_fifo (
        .wclk   (aclk),
        .wrst_n (aresetn),
        .wdata  (aw_wdata),
        .wvalid (s_awvalid),
        .wready (s_awready),

        .rclk   (dfi_clk),
        .rrst_n (ctl_reset_n),
        .rdata  (aw_rdata),
        .rvalid (m_awvalid),
        .rready (m_awready)
    );

    assign {
        m_awid, m_awlen, m_awsize, m_awburst,
        m_awaddr, m_awqos, m_awcache, m_awprot
    } = aw_rdata;


    // =========================================================
    // 3. W FIFO: aclk -> dfi_clk
    // =========================================================

    mc_async_fifo #(
        .DATA_WIDTH (289),
        .DEPTH      (16)
    ) u_w_fifo (
        .wclk   (aclk),
        .wrst_n (aresetn),
        .wdata  (w_wdata),
        .wvalid (s_wvalid),
        .wready (s_wready),

        .rclk   (dfi_clk),
        .rrst_n (ctl_reset_n),
        .rdata  (w_rdata),
        .rvalid (m_wvalid),
        .rready (m_wready)
    );

    assign {m_wdata, m_wstrb, m_wlast} = w_rdata;


    // =========================================================
    // 4. AR FIFO: aclk -> dfi_clk
    // =========================================================

    mc_async_fifo #(
        .DATA_WIDTH (72),
        .DEPTH      (8)
    ) u_ar_fifo (
        .wclk   (aclk),
        .wrst_n (aresetn),
        .wdata  (ar_wdata),
        .wvalid (s_arvalid),
        .wready (s_arready),

        .rclk   (dfi_clk),
        .rrst_n (ctl_reset_n),
        .rdata  (ar_rdata),
        .rvalid (m_arvalid),
        .rready (m_arready)
    );

    assign {
        m_arid, m_arlen, m_arsize, m_arburst,
        m_araddr, m_arqos, m_arcache, m_arprot
        } = ar_rdata;


    // =========================================================
    // 5. WRITE ADDRESS DECODER
    // Decode the AW FIFO output in the dfi_clk domain.
    // =========================================================

    mc_addr_decode u_aw_decode (
        .addr        (m_awaddr),
        .ch_sel      (m_aw_ch_sel),
        .pc_sel      (m_aw_pc_sel),
        .row_addr    (m_aw_row_addr),
        .bank_group  (m_aw_bank_group),
        .bank_addr   (m_aw_bank_addr),
        .col_addr    (m_aw_col_addr),
        .byte_offset  ()
    );


    // =========================================================
    // 6. READ ADDRESS DECODER
    // Decode the AR FIFO output in the dfi_clk domain.
    // =========================================================

    mc_addr_decode u_ar_decode (
        .addr        (m_araddr),
        .ch_sel      (m_ar_ch_sel),
        .pc_sel      (m_ar_pc_sel),
        .row_addr    (m_ar_row_addr),
        .bank_group  (m_ar_bank_group),
        .bank_addr   (m_ar_bank_addr),
        .col_addr    (m_ar_col_addr),
        .byte_offset  ()
    );


    // =========================================================
    // 7. B FIFO: dfi_clk -> aclk
    // =========================================================

    mc_async_fifo #(
        .DATA_WIDTH (10),
        .DEPTH      (8)
    ) u_b_fifo (
        .wclk   (dfi_clk),
        .wrst_n (ctl_reset_n),
        .wdata  (b_wdata),
        .wvalid (m_bvalid),
        .wready (m_bready),

        .rclk   (aclk),
        .rrst_n (aresetn),
        .rdata  (b_rdata),
        .rvalid (s_bvalid),
        .rready (s_bready)
    );

    assign {s_bid, s_bresp} = b_rdata;


    // =========================================================
    // 8. R FIFO: dfi_clk -> aclk
    // =========================================================

    mc_async_fifo #(
        .DATA_WIDTH (267),
        .DEPTH      (16)
    ) u_r_fifo (
        .wclk   (dfi_clk),
        .wrst_n (ctl_reset_n),
        .wdata  (r_wdata),
        .wvalid (m_rvalid),
        .wready (m_rready),

        .rclk   (aclk),
        .rrst_n (aresetn),
        .rdata  (r_rdata),
        .rvalid (s_rvalid),
        .rready (s_rready)
    );

    assign {
        s_rid, s_rdata, s_rresp, s_rlast
    } = r_rdata;

endmodule
