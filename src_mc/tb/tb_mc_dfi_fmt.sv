`timescale 1ns/1ps

module tb_dfi_formatter;
    logic        dfi_clk = 1'b0;
    logic        dfi_reset_n = 1'b0;

    logic        row_valid;
    logic        row_pc_sel;
    logic [2:0]  row_cmd;
    logic [1:0]  row_bg;
    logic [1:0]  row_ba;
    logic [13:0] row_addr;
    logic        dfi_row_val;
    logic [21:0] dfi_row;

    logic        col_valid;
    logic        col_pc_sel;
    logic [1:0]  col_cmd;
    logic [1:0]  col_bg;
    logic [1:0]  col_ba;
    logic [4:0]  col_addr;
    logic        dfi_col_val;
    logic [11:0] dfi_col;

    logic [63:0] wrdata;
    logic [7:0]  wrdata_mask;
    logic [1:0]  wrdata_en;
    logic [63:0] dfi_wrdata;
    logic [7:0]  dfi_wrdata_mask;
    logic [1:0]  dfi_wrdata_en;

    logic [63:0] dfi_rddata;
    logic [1:0]  dfi_rddata_valid;
    logic [1:0]  rddata_en;
    logic [1:0]  dfi_rddata_en;
    logic [31:0] rddata_pc0;
    logic [31:0] rddata_pc1;
    logic [1:0]  rddata_valid;

    always #5 dfi_clk = ~dfi_clk;

    mc_dfi_fmt dut (.*);

    initial begin
        $dumpfile("tb_dfi_formatter.vcd");
        $dumpvars(0, tb_dfi_formatter);

        row_valid = 1'b0;
        row_pc_sel = 1'b0;
        row_cmd = '0;
        row_bg = '0;
        row_ba = '0;
        row_addr = '0;
        col_valid = 1'b0;
        col_pc_sel = 1'b0;
        col_cmd = '0;
        col_bg = '0;
        col_ba = '0;
        col_addr = '0;
        wrdata = '0;
        wrdata_mask = '0;
        wrdata_en = '0;
        dfi_rddata = '0;
        dfi_rddata_valid = '0;
        rddata_en = '0;

        @(posedge dfi_clk);
        #1;
        if ({dfi_row_val, dfi_row, dfi_col_val, dfi_col, dfi_wrdata_en,
             dfi_rddata_en, rddata_valid} !== '0)
            $fatal(1, "reset did not clear formatter outputs");

        dfi_reset_n = 1'b1;
        row_valid = 1'b1;
        row_pc_sel = 1'b1;
        row_cmd = 3'b101;
        row_bg = 2'b10;
        row_ba = 2'b01;
        row_addr = 14'h2A5B;

        col_valid = 1'b1;
        col_pc_sel = 1'b0;
        col_cmd = 2'b11;
        col_bg = 2'b01;
        col_ba = 2'b10;
        col_addr = 5'b10110;

        wrdata = 64'h0123_4567_89AB_CDEF;
        wrdata_mask = 8'hA5;
        wrdata_en = 2'b11;
        dfi_rddata = 64'hFEDC_BA98_7654_3210;
        dfi_rddata_valid = 2'b10;
        rddata_en = 2'b01;

        @(posedge dfi_clk);
        #1;
        if (!dfi_row_val || dfi_row !== {1'b1, 3'b101, 2'b10, 2'b01, 14'h2A5B})
            $fatal(1, "row fields were not packed into their specified bit positions");
        if (!dfi_col_val || dfi_col !== {1'b0, 2'b11, 2'b01, 2'b10, 5'b10110})
            $fatal(1, "column fields were not packed into their specified bit positions");
        if (dfi_wrdata !== wrdata || dfi_wrdata_mask !== wrdata_mask ||
            dfi_wrdata_en !== wrdata_en)
            $fatal(1, "write data lanes, mask, or enables were not preserved");
        if (rddata_pc0 !== 32'h7654_3210 || rddata_pc1 !== 32'hFEDC_BA98 ||
            rddata_valid !== 2'b10 || dfi_rddata_en !== 2'b01)
            $fatal(1, "read data was not routed to its corresponding PC lanes");

        row_valid = 1'b0;
        col_valid = 1'b0;
        wrdata_en = 2'b00;
        dfi_rddata_valid = 2'b00;
        rddata_en = 2'b00;
        @(posedge dfi_clk);
        #1;
        if (dfi_row_val || dfi_col_val || dfi_wrdata_en != 2'b00 ||
            dfi_rddata_en != 2'b00 || rddata_valid != 2'b00)
            $fatal(1, "valid/enable strobes did not clear on the next cycle");

        $display("DFI formatter tests passed");
        $finish;
    end
endmodule
