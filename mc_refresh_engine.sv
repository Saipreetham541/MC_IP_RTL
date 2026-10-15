`timescale 1ns/1ps

module mc_refresh_engine
  import mc_pkg::*;
(
  input  logic clk,
  input  logic rst_n,
  input  logic ref_ack,           // Pulsed by scheduler when REF command is issued
  output logic ref_req,           // High when refresh is pending (top priority)
  output logic ref_deadline_miss  // Pulsed if tREFI expires while previous ref_req is still pending
);

  logic [12:0] refi_counter;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      refi_counter      <= T_REFI - 13'd1;
      ref_req           <= 1'b0;
      ref_deadline_miss <= 1'b0;
    end else begin
      ref_deadline_miss <= 1'b0;

      if (ref_ack) begin
        ref_req <= 1'b0;
      end

      if (refi_counter == 13'd0) begin
        refi_counter <= T_REFI - 13'd1;
        ref_req      <= 1'b1;
        // Flag error if previous refresh still wasn't acknowledged (Section 10)
        if (ref_req && !ref_ack) begin
          ref_deadline_miss <= 1'b1;
        end
      end else begin
        refi_counter <= refi_counter - 13'd1;
      end
    end
  end

endmodule : mc_refresh_engine