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
    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wptr_bin, wptr_gray;
    logic [PTR_WIDTH-1:0] rptr_bin, rptr_gray;

    // Synchronizers for Gray-coded pointers
    logic [PTR_WIDTH-1:0] rptr_gray_w1, rptr_gray_w2;
    logic [PTR_WIDTH-1:0] wptr_gray_r1, wptr_gray_r2;

    logic wfull, rempty;

    logic [PTR_WIDTH-1:0] wbin_next, wgray_next;
    logic [PTR_WIDTH-1:0] rbin_next, rgray_next;

    logic wfull_next, rempty_next;

    wire w_do = wvalid && wready;
    wire r_do = rvalid && rready;

    // Calculate next pointers
    always_comb begin
        wbin_next  = wptr_bin + {{(PTR_WIDTH-1){1'b0}}, w_do};
        wgray_next = (wbin_next >> 1) ^ wbin_next;

        rbin_next  = rptr_bin + {{(PTR_WIDTH-1){1'b0}}, r_do};
        rgray_next = (rbin_next >> 1) ^ rbin_next;
    end
        
    assign wfull_next = (wgray_next == {~rptr_gray_w2[PTR_WIDTH-1:PTR_WIDTH-2], rptr_gray_w2[PTR_WIDTH-3:0]});
    assign rempty_next = (rgray_next == wptr_gray_r2);

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
endmodule
