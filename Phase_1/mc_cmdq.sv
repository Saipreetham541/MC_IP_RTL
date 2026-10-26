`timescale 1ns/1ps

module mc_cmdq #(
  parameter int CMDQ_DEPTH   = 32,
  parameter int CMDQ_ADDR_W  = $clog2(CMDQ_DEPTH),
  parameter int CMD_ENTRY_W  = 36
) (
  input  logic                     clk,           // Scheduler clock for all queue state.
  input  logic                     rst_n,         // Synchronous active-low queue reset.

  // The decoder asserts push_val with one complete command. cmdq_full lets the
  // decoder stop before data is lost; cmdq_overflow reports an attempted push
  // while every slot is occupied.
  input  logic                     push_val,
  input  logic [CMD_ENTRY_W-1:0]   push_entry,
  output logic                     cmdq_full,
  output logic                     cmdq_overflow,

  // ACT and PRE are intermediate operations, so a slot is invalidated only
  // when its final RD/WR column command is granted.
  input  logic                     pop_val,
  input  logic [CMDQ_ADDR_W-1:0]   pop_idx,

  // The scheduler needs parallel visibility to evaluate and arbitrate every
  // occupied command instead of being restricted to FIFO order.
  output logic [CMDQ_DEPTH-1:0]    slot_valid,
  output logic [CMD_ENTRY_W-1:0]   slot_data [CMDQ_DEPTH-1:0]
);

  logic [CMD_ENTRY_W-1:0] entries [CMDQ_DEPTH-1:0];
  logic [CMDQ_DEPTH-1:0] valid_reg;
  logic [CMDQ_ADDR_W-1:0] free_idx;
  logic                   free_found;

  assign slot_valid    = valid_reg;
  assign slot_data     = entries;
  assign cmdq_full     = &valid_reg;
  assign cmdq_overflow = push_val && cmdq_full;

  // Lowest-index allocation keeps the logic deterministic and allows the
  // scheduler to use slot index as a stable identity until the command pops.
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
      // The granted column command completes this queue entry.
      if (pop_val) begin
        valid_reg[pop_idx] <= 1'b0;
      end

      // Store only when space exists; overflow remains visible to the caller.
      if (push_val && !cmdq_full) begin
        valid_reg[free_idx] <= 1'b1;
        entries[free_idx]   <= push_entry;
      end
    end
  end

endmodule : mc_cmdq
