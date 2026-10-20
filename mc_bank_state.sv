`timescale 1ns/1ps

module mc_bank_state
  import mc_pkg::*;
(
  input  logic                      clk,          // Advances bank-open state.
  input  logic                      rst_n,        // Synchronous active-low reset.

  // Enable inputs are accepted-command pulses, not candidate requests. This is
  // required so a command rejected by channel arbitration cannot corrupt state.
  input  logic                      cmd_act_en,    // Opens one bank at update_row.
  input  logic                      cmd_pre_en,    // Closes one selected bank.
  input  logic                      cmd_preall_en, // Closes all banks for PREALL/refresh cleanup.
  input  logic [BG_ADDR_W-1:0]      update_bg,    // Bank-group half of the flat bank index.
  input  logic [BANK_ADDR_W-1:0]    update_bank,  // Bank half of the flat bank index.
  input  logic [ROW_ADDR_W-1:0]     update_row,   // Row remembered when ACT opens a bank.

  // The scheduler reads this table combinationally to distinguish a page hit,
  // a closed bank, and a row conflict for every queued command.
  output logic [TOTAL_BANKS-1:0]    bank_is_open,
  output logic [ROW_ADDR_W-1:0]     open_row [TOTAL_BANKS-1:0]
);

  // Concatenation matches the address mapping used throughout the scheduler.
  wire [BANK_IDX_W-1:0] flat_update_bank = {update_bg, update_bank};

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      bank_is_open <= '0;
      for (int i = 0; i < TOTAL_BANKS; i++) begin
        open_row[i] <= '0;
      end
    end else begin
      // PREALL has priority because it invalidates every individual open row.
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
