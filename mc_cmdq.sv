`timescale 1ns/1ps

module mc_cmdq
  import mc_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  // Push interface (from Address Decoder / Router)
  input  logic                     push_val,
  input  cmd_entry_t               push_entry,
  output logic                     cmdq_full,
  output logic                     cmdq_overflow, // Error flag for Section 10

  // Pop / Invalidate interface (from Scheduler when RD/WR column cmd issues)
  input  logic                     pop_val,
  input  logic [CMDQ_ADDR_W-1:0]   pop_idx,

  // Continuous live visibility of all 32 slots to Scheduler
  output logic [CMDQ_DEPTH-1:0]    slot_valid,
  output cmd_entry_t               slot_data [CMDQ_DEPTH-1:0]
);

  cmd_entry_t            entries [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0] valid_reg;

  assign slot_valid    = valid_reg;
  assign slot_data     = entries;
  assign cmdq_full     = &valid_reg;
  assign cmdq_overflow = push_val && cmdq_full;

  // Priority encoder: find the lowest-index empty slot
  logic [CMDQ_ADDR_W-1:0] free_idx;
  logic                   free_found;

  always_comb begin
    free_idx   = '0;
    free_found = 1'b0;
    for (int i = 0; i < CMDQ_DEPTH; i++) begin
      if (!valid_reg[i] && !free_found) begin
        free_idx   = CMDQ_ADDR_W'(i);
        free_found = 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_reg <= '0;
      for (int i = 0; i < CMDQ_DEPTH; i++) begin
        entries[i] <= '0;
      end
    end else begin
      // Free slot when RD/WR column command wins arbitration
      if (pop_val) begin
        valid_reg[pop_idx] <= 1'b0;
      end

      // Allocate slot when new command arrives
      if (push_val && !cmdq_full) begin
        valid_reg[free_idx] <= 1'b1;
        entries[free_idx]   <= push_entry;
      end
    end
  end

endmodule : mc_cmdq