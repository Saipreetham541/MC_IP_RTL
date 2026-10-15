`timescale 1ns/1ps

module mc_timing_check
  import mc_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,

  // Commands actually issued this cycle (after winning arbitration)
  input  logic                      issued_act,
  input  logic                      issued_pre,
  input  logic                      issued_preall,
  input  logic                      issued_rd,
  input  logic                      issued_wr,
  input  logic                      issued_ref,
  input  logic [3:0]                issued_bank, // {BG[1:0], BA[1:0]}

  // Legality bit-vectors output to scheduler
  output logic [TOTAL_BANKS-1:0]    legal_act,
  output logic [TOTAL_BANKS-1:0]    legal_pre,
  output logic [TOTAL_BANKS-1:0]    legal_rd,
  output logic [TOTAL_BANKS-1:0]    legal_wr,
  output logic                      legal_ref
);

  // Per-bank down-counters
  logic [7:0] cnt_rcd [TOTAL_BANKS-1:0];
  logic [7:0] cnt_ras [TOTAL_BANKS-1:0];
  logic [7:0] cnt_rp  [TOTAL_BANKS-1:0];
  logic [7:0] cnt_rc  [TOTAL_BANKS-1:0];
  logic [7:0] cnt_wr  [TOTAL_BANKS-1:0];
  logic [7:0] cnt_rtp [TOTAL_BANKS-1:0];

  // Per-PC shared down-counters
  logic [7:0] cnt_rrd;
  logic [7:0] cnt_ccd;
  logic [7:0] cnt_wtr;
  logic [9:0] cnt_rfc;

  // 4-entry shift register tracking the last 4 ACT commands for tFAW
  logic [7:0] faw_timer [3:0];

  function automatic [7:0] dec8(input logic [7:0] val);
    return (val > 8'd0) ? (val - 8'd1) : 8'd0;
  endfunction

  function automatic [9:0] dec10(input logic [9:0] val);
    return (val > 10'd0) ? (val - 10'd1) : 10'd0;
  endfunction

  wire refresh_busy = (cnt_rfc > 10'd0);

  // Legality Combinational Logic per Bank
  genvar b;
  generate
    for (b = 0; b < TOTAL_BANKS; b++) begin : gen_bank_legality
      assign legal_act[b] = (cnt_rp[b]  == 8'd0) && (cnt_rc[b] == 8'd0) &&
                            (cnt_rrd    == 8'd0) && (faw_timer[3] == 8'd0) &&
                            !refresh_busy;

      assign legal_pre[b] = (cnt_ras[b] == 8'd0) && (cnt_wr[b] == 8'd0) &&
                            (cnt_rtp[b] == 8'd0) && !refresh_busy;

      assign legal_rd[b]  = (cnt_rcd[b] == 8'd0) && (cnt_ccd == 8'd0) &&
                            (cnt_wtr    == 8'd0) && !refresh_busy;

      assign legal_wr[b]  = (cnt_rcd[b] == 8'd0) && (cnt_ccd == 8'd0) &&
                            !refresh_busy;
    end
  endgenerate

  // All-bank refresh is legal when not already refreshing and ACT spacing is clear
  assign legal_ref = !refresh_busy && (cnt_rrd == 8'd0);

  // Sequential Down-Counters
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cnt_rrd <= '0;
      cnt_ccd <= '0;
      cnt_wtr <= '0;
      cnt_rfc <= '0;
      for (int i = 0; i < 4; i++) begin
        faw_timer[i] <= '0;
      end
      for (int i = 0; i < TOTAL_BANKS; i++) begin
        cnt_rcd[i] <= '0;
        cnt_ras[i] <= '0;
        cnt_rp[i]  <= '0;
        cnt_rc[i]  <= '0;
        cnt_wr[i]  <= '0;
        cnt_rtp[i] <= '0;
      end
    end else begin
      // 1. Default every cycle: decrement all active counters by 1
      cnt_rrd <= dec8(cnt_rrd);
      cnt_ccd <= dec8(cnt_ccd);
      cnt_wtr <= dec8(cnt_wtr);
      cnt_rfc <= dec10(cnt_rfc);
      for (int i = 0; i < 4; i++) begin
        faw_timer[i] <= dec8(faw_timer[i]);
      end
      for (int i = 0; i < TOTAL_BANKS; i++) begin
        cnt_rcd[i] <= dec8(cnt_rcd[i]);
        cnt_ras[i] <= dec8(cnt_ras[i]);
        cnt_rp[i]  <= dec8(cnt_rp[i]);
        cnt_rc[i]  <= dec8(cnt_rc[i]);
        cnt_wr[i]  <= dec8(cnt_wr[i]);
        cnt_rtp[i] <= dec8(cnt_rtp[i]);
      end

      // 2. Load counters when a command is issued (using T_PARAM - 1 for exact cycle spacing)
      if (issued_act) begin
        cnt_rcd[issued_bank] <= T_RCD - 8'd1;
        cnt_ras[issued_bank] <= T_RAS - 8'd1;
        cnt_rc[issued_bank]  <= T_RC  - 8'd1;
        cnt_rrd              <= T_RRD - 8'd1;
        // Shift the 4-activation window and insert new T_FAW timer
        faw_timer[3]         <= dec8(faw_timer[2]);
        faw_timer[2]         <= dec8(faw_timer[1]);
        faw_timer[1]         <= dec8(faw_timer[0]);
        faw_timer[0]         <= T_FAW - 8'd1;
      end

      if (issued_pre) begin
        cnt_rp[issued_bank] <= T_RP - 8'd1;
      end

      if (issued_preall) begin
        for (int i = 0; i < TOTAL_BANKS; i++) begin
          cnt_rp[i] <= T_RP - 8'd1;
        end
      end

      if (issued_rd) begin
        cnt_ccd              <= T_CCD - 8'd1;
        cnt_rtp[issued_bank] <= T_RTP - 8'd1;
      end

      if (issued_wr) begin
        cnt_ccd              <= T_CCD - 8'd1;
        cnt_wtr              <= T_WTR - 8'd1;
        cnt_wr[issued_bank]  <= T_WR  - 8'd1;
      end

      if (issued_ref) begin
        cnt_rfc <= T_RFC - 10'd1;
      end
    end
  end

endmodule : mc_timing_check