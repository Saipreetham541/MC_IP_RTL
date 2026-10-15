`timescale 1ns/1ps
module mc_arbiter
  import mc_pkg::*;
#(
  parameter int NUM_REQ = 32
)(
  input  logic                      clk,
  input  logic                      rst_n,

  input  logic [NUM_REQ-1:0]        req_valid,    // Active request valid
  input  logic [NUM_REQ-1:0]        req_legal,    // Timing legality mask
  output logic [NUM_REQ-1:0]        grant,        // 1-hot grant output
  output logic [$clog2(NUM_REQ)-1:0] grant_idx,    // Binary winner index
  output logic                      grant_valid   // Any grant asserted
);

  localparam int IDX_W = $clog2(NUM_REQ);
  // 8-bit saturating wait counters
  logic [CREDIT_CTR_WIDTH-1:0] wait_ctr [NUM_REQ-1:0];
  logic [NUM_REQ-1:0]          eligible;

  assign eligible = req_valid & req_legal;

  // --------------------------------------------------------------------------
  // Combinational Winner Selection (Highest Counter, Ties broken by lower index)
  // Designed for bounded logic levels (≤ 6 levels)
  // --------------------------------------------------------------------------
  always_comb begin
    grant_valid = |eligible;
    grant_idx   = '0;

    if (grant_valid) begin
      // Find the first eligible request as baseline
      for (int i = NUM_REQ-1; i >= 0; i--) begin
        if (eligible[i]) grant_idx = IDX_W'(i);
      end

      // Compare against remaining candidates
      for (int i = 0; i < NUM_REQ; i++) begin
        if (eligible[i]) begin
          if (wait_ctr[i] > wait_ctr[grant_idx]) begin
            grant_idx = IDX_W'(i);
          end
        end
      end
    end
  end

  // Decode binary grant index to 1-hot
  always_comb begin
    grant = '0;
    if (grant_valid) begin
      grant[grant_idx] = 1'b1;
    end
  end

  // --------------------------------------------------------------------------
  // Wait Counter Maintenance
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        wait_ctr[i] <= '0;
      end
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        if (grant[i]) begin
          wait_ctr[i] <= '0;
        end else if (eligible[i]) begin
          if (wait_ctr[i] != {CREDIT_CTR_WIDTH{1'b1}}) begin
            wait_ctr[i] <= wait_ctr[i] + 1'b1; // Saturate at 255
          end
        end else begin
          // Hold counter value if not eligible this cycle
          wait_ctr[i] <= wait_ctr[i];
        end
      end
    end
  end

endmodule
