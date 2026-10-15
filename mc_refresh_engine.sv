`timescale 1ns/1ps
module mc_refresh_engine
  import mc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        ref_ack,      // Asserted when REF command is issued
  output logic        ref_req       // Refresh is due and pending
);

  logic [12:0] refi_counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      refi_counter <= T_REFI;
      ref_req      <= 1'b0;
    end else begin
      if (ref_ack) begin
        ref_req <= 1'b0;
      end

      if (refi_counter == 13'd0) begin
        refi_counter <= T_REFI;
        ref_req      <= 1'b1; // Top priority refresh becomes pending
      end else begin
        refi_counter <= refi_counter - 1'b1;
      end
    end
  end

endmodule
