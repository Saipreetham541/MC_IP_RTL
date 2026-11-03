module mc_axi_sub #(
    parameter int AXI_DATA_W = 256,
    parameter int AXI_ADDR_W = 40,
    parameter int AXI_ID_W   = 8
) (
    //==================================================
    // AXI WRITE ADDRESS CHANNEL
    //==================================================
    input  logic [AXI_ID_W-1:0]   awid,
    input  logic [AXI_ADDR_W-1:0] awaddr,
    input  logic [7:0]            awlen,
    input  logic [2:0]            awsize,
    input  logic [1:0]            awburst,
    input  logic [3:0]            awqos,
    input  logic [3:0]            awcache,
    input  logic [2:0]            awprot,
    input  logic                  awvalid,
    output logic                  awready,

    //==================================================
    // AXI WRITE DATA CHANNEL
    //==================================================
    input  logic [AXI_DATA_W-1:0]   wdata,
    input  logic [AXI_DATA_W/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    //==================================================
    // AXI WRITE RESPONSE CHANNEL
    //==================================================
    output logic [AXI_ID_W-1:0] bid,
    output logic [1:0]          bresp,
    output logic                bvalid,
    input  logic                bready,

    //==================================================
    // AXI READ ADDRESS CHANNEL
    //==================================================
    input  logic [AXI_ID_W-1:0]   arid,
    input  logic [AXI_ADDR_W-1:0] araddr,
    input  logic [7:0]            arlen,
    input  logic [2:0]            arsize,
    input  logic [1:0]            arburst,
    input  logic [3:0]            arqos,
    input  logic                  arvalid,
    output logic                  arready,

    //==================================================
    // AXI READ DATA CHANNEL
    //==================================================
    output logic [AXI_ID_W-1:0]   rid,
    output logic [AXI_DATA_W-1:0] rdata,
    output logic [1:0]            rresp,
    output logic                  rlast,
    output logic                  rvalid,
    input  logic                  rready,

    //==================================================
    // CDC CONNECTION: WRITE ADDRESS
    //==================================================
    output logic [AXI_ID_W-1:0]   cdc_awid,
    output logic [AXI_ADDR_W-1:0] cdc_awaddr,
    output logic [7:0]            cdc_awlen,
    output logic [2:0]            cdc_awsize,
    output logic [1:0]            cdc_awburst,
    output logic [3:0]            cdc_awqos,
    output logic [3:0]            cdc_awcache,
    output logic [2:0]            cdc_awprot,
    output logic                  cdc_awvalid,
    input  logic                  cdc_awready,

    //==================================================
    // CDC CONNECTION: WRITE DATA
    //==================================================
    output logic [AXI_DATA_W-1:0]   cdc_wdata,
    output logic [AXI_DATA_W/8-1:0] cdc_wstrb,
    output logic                    cdc_wlast,
    output logic                    cdc_wvalid,
    input  logic                    cdc_wready,

    //==================================================
    // CDC CONNECTION: WRITE RESPONSE
    //==================================================
    input  logic [AXI_ID_W-1:0] cdc_bid,
    input  logic [1:0]          cdc_bresp,
    input  logic                cdc_bvalid,
    output logic                cdc_bready,

    //==================================================
    // CDC CONNECTION: READ ADDRESS
    //==================================================
    output logic [AXI_ID_W-1:0]   cdc_arid,
    output logic [AXI_ADDR_W-1:0] cdc_araddr,
    output logic [7:0]            cdc_arlen,
    output logic [2:0]            cdc_arsize,
    output logic [1:0]            cdc_arburst,
    output logic [3:0]            cdc_arqos,
    output logic                  cdc_arvalid,
    input  logic                  cdc_arready,

    //==================================================
    // CDC CONNECTION: READ DATA
    //==================================================
    input  logic [AXI_ID_W-1:0]   cdc_rid,
    input  logic [AXI_DATA_W-1:0] cdc_rdata,
    input  logic [1:0]            cdc_rresp,
    input  logic                  cdc_rlast,
    input  logic                  cdc_rvalid,
    output logic                  cdc_rready
);

    //==================================================
    // WRITE ADDRESS: AXI -> CDC
    //==================================================
    assign cdc_awid    = awid;
    assign cdc_awaddr  = awaddr;
    assign cdc_awlen   = awlen;
    assign cdc_awsize  = awsize;
    assign cdc_awburst = awburst;
    assign cdc_awqos   = awqos;
    assign cdc_awcache = awcache;
    assign cdc_awprot  = awprot;
    assign cdc_awvalid = awvalid;

    assign awready = cdc_awready;

    //==================================================
    // WRITE DATA: AXI -> CDC
    //==================================================
    assign cdc_wdata  = wdata;
    assign cdc_wstrb  = wstrb;
    assign cdc_wlast  = wlast;
    assign cdc_wvalid = wvalid;

    assign wready = cdc_wready;

    //==================================================
    // WRITE RESPONSE: CDC -> AXI
    //==================================================
    assign bid        = cdc_bid;
    assign bresp      = cdc_bresp;
    assign bvalid     = cdc_bvalid;
    assign cdc_bready = bready;

    //==================================================
    // READ ADDRESS: AXI -> CDC
    //==================================================
    assign cdc_arid    = arid;
    assign cdc_araddr  = araddr;
    assign cdc_arlen   = arlen;
    assign cdc_arsize  = arsize;
    assign cdc_arburst = arburst;
    assign cdc_arqos   = arqos;
    assign cdc_arvalid = arvalid;

    assign arready = cdc_arready;

    //==================================================
    // READ DATA: CDC -> AXI
    //==================================================
    assign rid        = cdc_rid;
    assign rdata      = cdc_rdata;
    assign rresp      = cdc_rresp;
    assign rlast      = cdc_rlast;
    assign rvalid     = cdc_rvalid;
    assign cdc_rready = rready;
endmodule
