`timescale 1ns/1ps
`default_nettype none

module tb_mc_channel_integration;

  localparam int NUM_PC = 2;
  localparam int CREDIT_CTR_WIDTH = 8;

  // ------------------------------------------------------------
  // Clock / reset
  // ------------------------------------------------------------
  logic dfi_clk;
  logic dfi_reset_n;

  // ------------------------------------------------------------
  // ROW request interface
  // ------------------------------------------------------------
  logic [NUM_PC-1:0]       row_req_valid;
  logic [NUM_PC-1:0]       row_req_legal;
  logic [NUM_PC-1:0]       row_req_refresh;

  logic [NUM_PC-1:0][2:0]  row_cmd;
  logic [NUM_PC-1:0][1:0]  row_bg;
  logic [NUM_PC-1:0][1:0]  row_ba;
  logic [NUM_PC-1:0][13:0] row_addr;

  logic [NUM_PC-1:0]       row_issue;

  // ------------------------------------------------------------
  // COLUMN request interface
  // ------------------------------------------------------------
  logic [NUM_PC-1:0]       col_req_valid;
  logic [NUM_PC-1:0]       col_req_legal;
  logic [NUM_PC-1:0]       col_req_refresh;

  logic [NUM_PC-1:0][1:0]  col_cmd;
  logic [NUM_PC-1:0][1:0]  col_bg;
  logic [NUM_PC-1:0][1:0]  col_ba;
  logic [NUM_PC-1:0][4:0]  col_addr;

  logic [NUM_PC-1:0]       col_issue;

  // ------------------------------------------------------------
  // WRITE DATA
  // ------------------------------------------------------------
  logic [NUM_PC-1:0][31:0] wrdata_pc;
  logic [NUM_PC-1:0][3:0]  wrdata_mask_pc;
  logic [NUM_PC-1:0]       wrdata_en_pc;

  logic [63:0]             dfi_wrdata;
  logic [7:0]              dfi_wrdata_mask;
  logic [1:0]              dfi_wrdata_en;

  // ------------------------------------------------------------
  // READ DATA
  // ------------------------------------------------------------
  logic [63:0]             dfi_rddata;
  logic [1:0]              dfi_rddata_valid;
  logic [1:0]              rddata_en_pc;

  logic [1:0]              dfi_rddata_en;
  logic [31:0]             rddata_pc0;
  logic [31:0]             rddata_pc1;
  logic [1:0]              rddata_valid;

  // ------------------------------------------------------------
  // DFI COMMAND OUTPUTS
  // ------------------------------------------------------------
  logic                    dfi_row_val;
  logic [21:0]             dfi_row;

  logic                    dfi_col_val;
  logic [11:0]             dfi_col;


  // ============================================================
  // DUT
  // ============================================================
  mc_channel_integration #(
    .NUM_PC           (NUM_PC),
    .CREDIT_CTR_WIDTH (CREDIT_CTR_WIDTH)
  ) dut (

    .dfi_clk          (dfi_clk),
    .dfi_reset_n      (dfi_reset_n),

    // ROW
    .row_req_valid    (row_req_valid),
    .row_req_legal    (row_req_legal),
    .row_req_refresh  (row_req_refresh),
    .row_cmd          (row_cmd),
    .row_bg           (row_bg),
    .row_ba           (row_ba),
    .row_addr         (row_addr),
    .row_issue        (row_issue),

    // COLUMN
    .col_req_valid    (col_req_valid),
    .col_req_legal    (col_req_legal),
    .col_req_refresh  (col_req_refresh),
    .col_cmd          (col_cmd),
    .col_bg           (col_bg),
    .col_ba           (col_ba),
    .col_addr         (col_addr),
    .col_issue        (col_issue),

    // WRITE DATA
    .wrdata_pc        (wrdata_pc),
    .wrdata_mask_pc   (wrdata_mask_pc),
    .wrdata_en_pc     (wrdata_en_pc),
    .dfi_wrdata       (dfi_wrdata),
    .dfi_wrdata_mask  (dfi_wrdata_mask),
    .dfi_wrdata_en    (dfi_wrdata_en),

    // READ DATA
    .dfi_rddata       (dfi_rddata),
    .dfi_rddata_valid (dfi_rddata_valid),
    .rddata_en_pc     (rddata_en_pc),
    .dfi_rddata_en    (dfi_rddata_en),
    .rddata_pc0       (rddata_pc0),
    .rddata_pc1       (rddata_pc1),
    .rddata_valid     (rddata_valid),

    // DFI
    .dfi_row_val      (dfi_row_val),
    .dfi_row          (dfi_row),
    .dfi_col_val      (dfi_col_val),
    .dfi_col          (dfi_col)
  );


  // ============================================================
  // CLOCK
  // 10 ns period
  // ============================================================
  initial begin
    dfi_clk = 1'b0;

    forever #5 dfi_clk = ~dfi_clk;
  end


  // ============================================================
  // TESTBENCH INITIALIZATION
  // ============================================================
  initial begin

    dfi_reset_n = 1'b0;

    row_req_valid   = '0;
    row_req_legal   = '0;
    row_req_refresh = '0;

    row_cmd  = '0;
    row_bg   = '0;
    row_ba   = '0;
    row_addr = '0;

    col_req_valid   = '0;
    col_req_legal   = '0;
    col_req_refresh = '0;

    col_cmd  = '0;
    col_bg   = '0;
    col_ba   = '0;
    col_addr = '0;

    wrdata_pc      = '0;
    wrdata_mask_pc = '0;
    wrdata_en_pc   = '0;

    dfi_rddata       = '0;
    dfi_rddata_valid = '0;
    rddata_en_pc     = '0;

    // ----------------------------------------------------------
    // Reset
    // ----------------------------------------------------------
    #20;
    dfi_reset_n = 1'b1;

    $display("=================================================");
    $display(" PHASE 4 TEST START");
    $display("=================================================");


    // ==========================================================
    // TEST 1
    // Basic PC0 row request
    // ==========================================================
    $display("");
    $display("TEST 1: PC0 ROW request");

    row_cmd[0]  = 3'b001;
    row_bg[0]   = 2'b01;
    row_ba[0]   = 2'b10;
    row_addr[0] = 14'h1234;

    row_req_valid[0] = 1'b1;
    row_req_legal[0] = 1'b1;

    #20;

    row_req_valid[0] = 1'b0;
    row_req_legal[0] = 1'b0;

    #10;


    // ==========================================================
    // TEST 2
    // Both PCs request ROW simultaneously
    // PC0 and PC1 initially have equal credit.
    // PC0 should win tie because lower index wins.
    // ==========================================================
    $display("");
    $display("TEST 2: PC0 vs PC1 ROW tie");

    row_cmd[0]  = 3'b001;
    row_bg[0]   = 2'b00;
    row_ba[0]   = 2'b01;
    row_addr[0] = 14'h1111;

    row_cmd[1]  = 3'b010;
    row_bg[1]   = 2'b10;
    row_ba[1]   = 2'b11;
    row_addr[1] = 14'h2222;

    row_req_valid = 2'b11;
    row_req_legal = 2'b11;

    #10;

    row_req_valid = 2'b00;
    row_req_legal = 2'b00;

    #20;


    // ==========================================================
    // TEST 3
    // Credit aging
    //
    // PC1 waits while PC0 is illegal.
    // PC1's wait counter increases.
    // Then PC0 becomes legal.
    // PC1 should have greater credit and win.
    // ==========================================================
    $display("");
    $display("TEST 3: Credit aging / waiting PC wins");

    row_cmd[0]  = 3'b011;
    row_cmd[1]  = 3'b001;

    row_bg[0]   = 2'b00;
    row_bg[1]   = 2'b01;

    row_ba[0]   = 2'b00;
    row_ba[1]   = 2'b01;

    row_addr[0] = 14'h3000;
    row_addr[1] = 14'h4000;

    // PC1 is requesting and legal.
    // PC0 is requesting but NOT legal.
    row_req_valid = 2'b11;
    row_req_legal = 2'b10;

    #40;

    // Now PC0 becomes legal.
    row_req_legal = 2'b11;

    #10;

    row_req_valid = 2'b00;
    row_req_legal = 2'b00;

    #20;


    // ==========================================================
    // TEST 4
    // Priority / refresh
    //
    // PC0 normal request
    // PC1 refresh request
    //
    // PC1 should win because refresh is priority.
    // ==========================================================
    $display("");
    $display("TEST 4: Refresh priority");

    row_cmd[0]  = 3'b001;
    row_cmd[1]  = 3'b011;

    row_req_valid   = 2'b11;
    row_req_legal   = 2'b11;
    row_req_refresh = 2'b10;

    #10;

    row_req_valid   = 2'b00;
    row_req_legal   = 2'b00;
    row_req_refresh = 2'b00;

    #20;


    // ==========================================================
    // TEST 5
    // Row and column simultaneously
    //
    // PC0 -> ROW
    // PC1 -> COLUMN
    //
    // Both should be granted in the same cycle.
    // ==========================================================
    $display("");
    $display("TEST 5: Simultaneous ROW and COLUMN");

    row_cmd[0]  = 3'b001;
    row_bg[0]   = 2'b01;
    row_ba[0]   = 2'b01;
    row_addr[0] = 14'h5555;

    col_cmd[1]  = 2'b01;
    col_bg[1]   = 2'b10;
    col_ba[1]   = 2'b11;
    col_addr[1] = 5'b10101;

    row_req_valid = 2'b01;
    row_req_legal = 2'b01;

    col_req_valid = 2'b10;
    col_req_legal = 2'b10;

    #10;

    row_req_valid = 2'b00;
    row_req_legal = 2'b00;

    col_req_valid = 2'b00;
    col_req_legal = 2'b00;

    #20;


    // ==========================================================
    // TEST 6
    // Both ROW and COLUMN active, different PCs
    //
    // PC1 -> ROW
    // PC0 -> COLUMN
    // ==========================================================
    $display("");
    $display("TEST 6: ROW PC1 + COLUMN PC0");

    row_cmd[1]  = 3'b010;
    row_bg[1]   = 2'b11;
    row_ba[1]   = 2'b10;
    row_addr[1] = 14'h6666;

    col_cmd[0]  = 2'b10;
    col_bg[0]   = 2'b01;
    col_ba[0]   = 2'b00;
    col_addr[0] = 5'b11010;

    row_req_valid = 2'b10;
    row_req_legal = 2'b10;

    col_req_valid = 2'b01;
    col_req_legal = 2'b01;

    #10;

    row_req_valid = 2'b00;
    row_req_legal = 2'b00;

    col_req_valid = 2'b00;
    col_req_legal = 2'b00;

    #20;


    // ==========================================================
    // TEST 7
    // WRITE DATA PATH
    // ==========================================================
    $display("");
    $display("TEST 7: WRITE DATA");

    wrdata_pc[0]      = 32'hAAAAAAAA;
    wrdata_pc[1]      = 32'h55555555;

    wrdata_mask_pc[0] = 4'b0011;
    wrdata_mask_pc[1] = 4'b1100;

    wrdata_en_pc      = 2'b11;

    #10;

    wrdata_pc      = '0;
    wrdata_mask_pc = '0;
    wrdata_en_pc   = '0;

    #20;


    // ==========================================================
    // TEST 8
    // READ DATA PATH
    // ==========================================================
    $display("");
    $display("TEST 8: READ DATA");

    dfi_rddata = 64'h12345678_DEADBEEF;
    dfi_rddata_valid = 2'b11;
    rddata_en_pc = 2'b11;

    #10;

    dfi_rddata = '0;
    dfi_rddata_valid = '0;
    rddata_en_pc = '0;

    #20;


    // ==========================================================
    // END
    // ==========================================================
    $display("");
    $display("=================================================");
    $display(" PHASE 4 TEST COMPLETE");
    $display("=================================================");

    $finish;
  end


  // ============================================================
  // WAVEFORM DUMP
  // ============================================================
  initial begin
    $dumpfile("phase4.vcd");
    $dumpvars(0, tb_mc_channel_integration);
  end


  // ============================================================
  // SIMPLE MONITOR
  // ============================================================
  always @(posedge dfi_clk) begin

    if (dfi_reset_n) begin

      $display(
        "T=%0t | ROW req=%b legal=%b grant=%b valid=%b pc=%b | COL req=%b legal=%b grant=%b valid=%b pc=%b",
        $time,
        row_req_valid,
        row_req_legal,
        row_issue,
        dfi_row_val,
        dut.u_channel_arbiter.row_pc_sel,
        col_req_valid,
        col_req_legal,
        col_issue,
        dfi_col_val,
        dut.u_channel_arbiter.col_pc_sel
      );

    end
  end

endmodule

`default_nettype wire