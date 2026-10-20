`timescale 1ns/1ps

module mc_arbiter
  import mc_pkg::*;
#(
  parameter int NUM_REQ = 32
) (
  input  logic                        clk,         // Advances per-request wait counters.
  input  logic                        rst_n,       // Synchronous active-low reset.
  input  logic [NUM_REQ-1:0]          req_valid,   // Marks occupied/requesting slots.
  input  logic [NUM_REQ-1:0]          req_legal,   // Masks requests blocked by timing/resources.
  input  logic                        grant_ack,   // Confirms the selected request really issued.
  output logic [NUM_REQ-1:0]          grant,       // One-hot form used for per-slot updates.
  output logic [$clog2(NUM_REQ)-1:0]  grant_idx,   // Binary form used to index command storage.
  output logic                        grant_valid  // Distinguishes slot zero from no selection.
);

  localparam int IDX_W = $clog2(NUM_REQ);

  logic [CREDIT_CTR_WIDTH-1:0] wait_ctr [NUM_REQ-1:0];
  logic [NUM_REQ-1:0]          eligible;

  // A request participates only when a command exists and can legally execute.
  assign eligible = req_valid & req_legal;

  // Combinational Winner Selection:
  // Highest wait_ctr wins; ties broken by lowest index (0 beats 1, etc.)
  always_comb begin
    logic [CREDIT_CTR_WIDTH-1:0] max_ctr;

    grant_valid = 1'b0;
    grant_idx   = '0;
    max_ctr     = '0;

    for (int i = 0; i < NUM_REQ; i++) begin
      if (eligible[i]) begin
        // Strictly greater (>) ensures lower index 'i' keeps the win on a tie
        if (!grant_valid || (wait_ctr[i] > max_ctr)) begin
          grant_valid = 1'b1;
          max_ctr     = wait_ctr[i];
          grant_idx   = IDX_W'(i);
        end
      end
    end
  end

  // 1-Hot Grant Decode
  always_comb begin
    grant = '0;
    if (grant_valid) begin
      grant[grant_idx] = 1'b1;
    end
  end

  // Eligible losers age so they eventually outrank newer traffic. The counter
  // resets only after downstream acceptance; a denied winner must retry.
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        wait_ctr[i] <= '0;
      end
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        if (!req_valid[i]) begin
          // Empty slot resets to 0
          wait_ctr[i] <= '0;
        end else if (grant[i] && grant_ack) begin
          // Winner was issued -> reset counter to 0
          wait_ctr[i] <= '0;
        end else if (eligible[i]) begin
          // Ready & legal, but lost arbitration -> saturating increment
          if (wait_ctr[i] != {CREDIT_CTR_WIDTH{1'b1}}) begin
            wait_ctr[i] <= wait_ctr[i] + 1'b1;
          end
        end
      end
    end
  end

endmodule : mc_arbiter
