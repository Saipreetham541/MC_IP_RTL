module mc_async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8
) (
    // Write clock domain
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic                  wvalid,
    output logic                  wready,

    // Read clock domain
    input  logic                  rclk,
    input  logic                  rrst_n,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rvalid,
    input  logic                  rready
);

    // DEPTH must be a power of two and at least 4.
    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wptr_bin, wptr_gray;
    logic [PTR_WIDTH-1:0] rptr_bin, rptr_gray;

    // Synchronizers for Gray-coded pointers
    (* ASYNC_REG = "TRUE" *)
    logic [PTR_WIDTH-1:0] rptr_gray_w1, rptr_gray_w2;

    (* ASYNC_REG = "TRUE" *)
    logic [PTR_WIDTH-1:0] wptr_gray_r1, wptr_gray_r2;

    logic wfull, rempty;

    logic [PTR_WIDTH-1:0] wbin_next, wgray_next;
    logic [PTR_WIDTH-1:0] rbin_next, rgray_next;

    logic wfull_next, rempty_next;

    wire w_do = wvalid && wready;
    wire r_do = rvalid && rready;

    // Binary-to-Gray conversion
    function automatic logic [PTR_WIDTH-1:0] bin_to_gray(
        input logic [PTR_WIDTH-1:0] value
    );
        bin_to_gray = (value >> 1) ^ value;
    endfunction

    // Calculate next pointers
    always_comb begin
        wbin_next  = wptr_bin + w_do;
        wgray_next = bin_to_gray(wbin_next);

        rbin_next  = rptr_bin + r_do;
        rgray_next = bin_to_gray(rbin_next);
    end

    // Full detection: If the next write pointer reaches the read pointer after one complete lap, mark the FIFO
    // full, read pointer with its two most significant Gray bits inverted.
    always_comb begin
        wfull_next =
            (wgray_next ==
             {~rptr_gray_w2[PTR_WIDTH-1:PTR_WIDTH-2],
                rptr_gray_w2[PTR_WIDTH-3:0]});
    end

    // Empty detection: next read pointer equals synchronized
    // write pointer.
    always_comb begin
        rempty_next = (rgray_next == wptr_gray_r2);
    end

    // Handshake outputs
    assign wready = !wfull;
    assign rvalid = !rempty;

    // First-word-fall-through read interface
    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];

    // Write pointer and memory
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
            wfull     <= 1'b0;
        end else begin
            if (w_do) begin
                mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
            end

            wptr_bin  <= wbin_next;
            wptr_gray <= wgray_next;
            wfull     <= wfull_next;
        end
    end

    // Read pointer
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
            rempty    <= 1'b1;
        end else begin
            rptr_bin  <= rbin_next;
            rptr_gray <= rgray_next;
            rempty    <= rempty_next;
        end
    end

    // Synchronize read pointer into write clock domain
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rptr_gray_w1 <= '0;
            rptr_gray_w2 <= '0;
        end else begin
            rptr_gray_w1 <= rptr_gray;
            rptr_gray_w2 <= rptr_gray_w1;
        end
    end

    // Synchronize write pointer into read clock domain
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wptr_gray_r1 <= '0;
            wptr_gray_r2 <= '0;
        end else begin
            wptr_gray_r1 <= wptr_gray;
            wptr_gray_r2 <= wptr_gray_r1;
        end
    end

    // Basic parameter checks
    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0)
            $error("mc_async_fifo: DEPTH must be a power of two >= 4");
    end

endmodule
