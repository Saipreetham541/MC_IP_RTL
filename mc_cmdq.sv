`timescale 1ns/1ps
module mc_cmdq
  import mc_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  // Push interface (from CDC router)
  input  logic                     push_val,
  input  cmd_entry_t               push_entry,
  output logic                     cmdq_full,

  // Invalidation / Pop interface (from Scheduler Grant)
  input  logic                     pop_val,
  input  logic [CMDQ_ADDR_W-1:0]   pop_idx,

  // Live slot status to scheduler
  output logic [CMDQ_DEPTH-1:0]    slot_valid,
  output cmd_entry_t               slot_data [CMDQ_DEPTH-1:0]
);

  cmd_entry_t entries [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0] valid_reg;

  assign slot_valid = valid_reg;
  assign slot_data  = entries;
  assign cmdq_full  = &valid_reg;

  // Find lowest free slot for push
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_reg <= '0;
      for (int i = 0; i < CMDQ_DEPTH; i++) entries[i] <= '0;
    end else begin
      // Invalidate on pop
      if (pop_val) begin
        valid_reg[pop_idx] <= 1'b0;
      end

      // Enqueue on push
      if (push_val && !cmdq_full) begin
        valid_reg[free_idx] <= 1'b1;
        entries[free_idx]   <= push_entry;
      end
    end
  end

endmodule
