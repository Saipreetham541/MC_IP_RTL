`timescale 1ns/1ps

module mc_bank_state
  import mc_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,

  // Execution updates from scheduler when command wins arbitration
  input  logic                      cmd_act_en,
  input  logic                      cmd_pre_en,
  input  logic                      cmd_preall_en,
  input  logic [BG_ADDR_W-1:0]      update_bg,
  input  logic [BANK_ADDR_W-1:0]    update_bank,
  input  logic [ROW_ADDR_W-1:0]     update_row,

  // Continuous live status to scheduler
  output logic [TOTAL_BANKS-1:0]    bank_is_open,
  output logic [ROW_ADDR_W-1:0]     open_row [TOTAL_BANKS-1:0]
);

  wire [3:0] flat_update_bank = {update_bg, update_bank};

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      bank_is_open <= '0;
      for (int i = 0; i < TOTAL_BANKS; i++) begin
        open_row[i] <= '0;
      end
    end else begin
      if (cmd_preall_en) begin
        bank_is_open <= '0;
      end else begin
        if (cmd_act_en) begin
          bank_is_open[flat_update_bank] <= 1'b1;
          open_row[flat_update_bank]     <= update_row;
        end else if (cmd_pre_en) begin
          bank_is_open[flat_update_bank] <= 1'b0;
        end
      end
    end
  end

endmodule : mc_bank_state