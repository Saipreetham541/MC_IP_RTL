`timescale 1ns/1ps

module mc_arbiter
  import mc_pkg::*;
#(
  parameter int NUM_REQ = 32
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [NUM_REQ-1:0]          req_valid,   // Slot occupied
  input  logic [NUM_REQ-1:0]          req_legal,   // Slot timing-legal this cycle
  input  logic                        grant_ack,   // 1 = winner actually consumed downstream
  output logic [NUM_REQ-1:0]          grant,       // 1-hot winner mask
  output logic [$clog2(NUM_REQ)-1:0]  grant_idx,   // Binary winner index
  output logic                        grant_valid  // 1 = at least one eligible candidate exists
);

  localparam int IDX_W = $clog2(NUM_REQ);

  logic [CREDIT_CTR_WIDTH-1:0] wait_ctr [NUM_REQ-1:0];
  logic [NUM_REQ-1:0]          eligible;

  assign eligible = req_valid & req_legal;

  // Combinational Winner Selection:
  // Highest wait_ctr wins; ties broken by lowest index (0 beats 1, etc.)
  always_comb begin
    logic [CREDIT_CTR_WIDTH-1:0] max_ctr;
    logic                        found;

    grant_valid = 1'b0;
    grant_idx   = '0;
    max_ctr     = '0;
    found       = 1'b0;

    for (int i = 0; i < NUM_REQ; i++) begin
      if (eligible[i]) begin
        // Strictly greater (>) ensures lower index 'i' keeps the win on a tie
        if (!found || (wait_ctr[i] > max_ctr)) begin
          found       = 1'b1;
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

  // Sequential Wait Counter Update (Section 5.2)
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