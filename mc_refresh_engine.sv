`timescale 1ns/1ps

module mc_refresh_engine
  import mc_pkg::*;
(
  input  logic clk,               // Advances the periodic refresh interval.
  input  logic rst_n,             // Synchronous active-low reset.
  input  logic ref_ack,           // Scheduler actually issued the requested REF.
  output logic ref_req,           // Held high so refresh cannot be lost while banks drain.
  output logic ref_deadline_miss  // Pulses when another interval expires before acknowledgement.
);

  // Counts remaining cycles until refresh service becomes due.
  logic [12:0] refi_counter;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      refi_counter      <= T_REFI - 13'd1;
      ref_req           <= 1'b0;
      ref_deadline_miss <= 1'b0;
    end else begin
      ref_deadline_miss <= 1'b0;

      // Acknowledgement clears the outstanding request. A simultaneous interval
      // expiry below creates the next request, so elapsed refresh debt is kept.
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
