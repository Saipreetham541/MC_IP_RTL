`timescale 1ns/1ps
module mc_timing_check
  import mc_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,

  // Command issued this cycle
  input  logic                      issued_act,
  input  logic                      issued_pre,
  input  logic                      issued_preall,
  input  logic                      issued_rd,
  input  logic                      issued_wr,
  input  logic                      issued_ref,
  input  logic [3:0]                issued_bank, // {BG, BA}

  // Legality vectors per bank
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

  // tFAW sliding window: stores timestamps of the last 4 activations
  logic [7:0] faw_timer [3:0];

  // Down-counter decrement helper
  function automatic [7:0] dec8(input [7:0] val);
    return (val > 8'd0) ? (val - 8'd1) : 8'd0;
  endfunction

  function automatic [9:0] dec10(input [9:0] val);
    return (val > 10'd0) ? (val - 10'd1) : 10'd0;
  endfunction

  // Global Refresh Lockout Check
  wire refresh_busy = (cnt_rfc > 10'd0);

  // --------------------------------------------------------------------------
  // Bank-level Legality Equations
  // --------------------------------------------------------------------------
  genvar b;
  generate
    for (b = 0; b < TOTAL_BANKS; b++) begin : gen_bank_legality
      assign legal_act[b] = (cnt_rp[b] == 0) && (cnt_rc[b] == 0) &&
                            (cnt_rrd == 0)   && (faw_timer[3] == 0) &&
                            !refresh_busy;

      assign legal_pre[b] = (cnt_ras[b] == 0) && (cnt_wr[b] == 0) &&
                            (cnt_rtp[b] == 0) && !refresh_busy;

      assign legal_rd[b]  = (cnt_rcd[b] == 0) && (cnt_ccd == 0) &&
                            (cnt_wtr == 0)    && !refresh_busy;

      assign legal_wr[b]  = (cnt_rcd[b] == 0) && (cnt_ccd == 0) &&
                            !refresh_busy;
    end
  endgenerate

  assign legal_ref = !refresh_busy && (cnt_rrd == 0);

  // --------------------------------------------------------------------------
  // Timing Counter Registers
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_rrd <= '0;
      cnt_ccd <= '0;
      cnt_wtr <= '0;
      cnt_rfc <= '0;
      for (int i = 0; i < 4; i++) faw_timer[i] <= '0;

      for (int i = 0; i < TOTAL_BANKS; i++) begin
        cnt_rcd[i] <= '0;
        cnt_ras[i] <= '0;
        cnt_rp[i]  <= '0;
        cnt_rc[i]  <= '0;
        cnt_wr[i]  <= '0;
        cnt_rtp[i] <= '0;
      end
    end else begin
      // Decrement shared counters
      cnt_rrd <= dec8(cnt_rrd);
      cnt_ccd <= dec8(cnt_ccd);
      cnt_wtr <= dec8(cnt_wtr);
      cnt_rfc <= dec10(cnt_rfc);
      for (int i = 0; i < 4; i++) faw_timer[i] <= dec8(faw_timer[i]);

      // Decrement per-bank counters
      for (int i = 0; i < TOTAL_BANKS; i++) begin
        cnt_rcd[i] <= dec8(cnt_rcd[i]);
        cnt_ras[i] <= dec8(cnt_ras[i]);
        cnt_rp[i]  <= dec8(cnt_rp[i]);
        cnt_rc[i]  <= dec8(cnt_rc[i]);
        cnt_wr[i]  <= dec8(cnt_wr[i]);
        cnt_rtp[i] <= dec8(cnt_rtp[i]);
      end

      // Update counters on command issue
      if (issued_act) begin
        cnt_rcd[issued_bank] <= T_RCD;
        cnt_ras[issued_bank] <= T_RAS;
        cnt_rc[issued_bank]  <= T_RC;
        cnt_rrd             <= T_RRD;

        // Shift sliding window for tFAW
        faw_timer[3] <= faw_timer[2];
        faw_timer[2] <= faw_timer[1];
        faw_timer[1] <= faw_timer[0];
        faw_timer[0] <= T_FAW;
      end

      if (issued_pre) begin
        cnt_rp[issued_bank] <= T_RP;
      end

      if (issued_preall) begin
        for (int i = 0; i < TOTAL_BANKS; i++) cnt_rp[i] <= T_RP;
      end

      if (issued_rd) begin
        cnt_ccd             <= T_CCD;
        cnt_rtp[issued_bank] <= T_RTP;
      end

      if (issued_wr) begin
        cnt_ccd             <= T_CCD;
        cnt_wtr             <= T_WTR;
        cnt_wr[issued_bank] <= T_WR;
      end

      if (issued_ref) begin
        cnt_rfc <= T_RFC;
      end
    end
  end

endmodule
