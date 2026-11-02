`timescale 1ns/1ps
module tb_mc_async_fifo;
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;

    logic wclk, rclk;
    logic wrst_n, rrst_n;
    logic [DATA_WIDTH-1:0] wdata;
    logic wvalid;
    logic wready;
    logic [DATA_WIDTH-1:0] rdata;
    logic rvalid;
    logic rready;

    mc_async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .wdata  (wdata),
        .wvalid (wvalid),
        .wready (wready),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rdata  (rdata),
        .rvalid (rvalid),
        .rready (rready)
    );
    initial begin
        wclk = 0;
        forever #5 wclk = ~wclk;
    end
  
    initial begin
        rclk = 0;
        forever #7 rclk = ~rclk;
    end
  
    task automatic write_data(input logic [7:0] data);
        @(negedge wclk);
        wdata  = data;
        wvalid = 1;
        do
            @(posedge wclk);
        while (!wready);
        @(negedge wclk);
        wvalid = 0;
    endtask
  
    task automatic read_data(input logic [7:0] expected);
        wait (rvalid == 1);
        if (rdata !== expected) begin
            $display("FAIL: Expected %h, Got %h", expected, rdata);
            $fatal;
        end
        @(negedge rclk);
        rready = 1;
        @(posedge rclk);
        @(negedge rclk);
        rready = 0;
        $display("PASS: Read data = %h", expected);
    endtask

    integer i;
    initial begin
        wrst_n = 1;
        rrst_n = 1;
        wdata  = 0;
        wvalid = 0;
        rready = 0;
        #1;
        wrst_n = 0;
        rrst_n = 0;
        #30;
        wrst_n = 1;
        rrst_n = 1;
        #20;

        // Test 1: FIFO should start empty
        if (rvalid !== 0)
            $fatal(1, "FAIL: FIFO should be empty after reset");
        $display("PASS: Reset and empty check");

        // Test 2: Basic write and read
        write_data(8'h11);
        write_data(8'h22);
        write_data(8'h33);
        read_data(8'h11);
        read_data(8'h22);
        read_data(8'h33);
        $display("PASS: Basic write and read");

        // Test 3: Fill FIFO and check full
        for (i = 0; i < DEPTH; i = i + 1)
            write_data(8'(i + 32'h40));
        #1;
        if (wready !== 0)
            $fatal(1, "FAIL: FIFO did not become full");
        $display("PASS: FIFO full check");

        // Test 4: Drain FIFO and check empty
        for (i = 0; i < DEPTH; i = i + 1)
            read_data(8'(i + 32'h40));
        #1;
        if (rvalid !== 0)
            $fatal(1, "FAIL: FIFO did not become empty");
        $display("PASS: FIFO empty check");
      
        $display("ALL BASIC FIFO TESTS PASSED");
        #20;
        $finish;
    end
    initial begin
        $dumpfile("mc_async_fifo.vcd");
        $dumpvars(0, tb_mc_async_fifo);
    end
endmodule
