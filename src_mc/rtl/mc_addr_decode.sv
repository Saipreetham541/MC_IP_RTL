`timescale 1ns/1ps
`default_nettype none

// Controller-domain AXI dispatch/address backend: one transaction and one core
// word active at a time, enforcing dependencies and same-ID response order.
// AW is retained through AWLEN+1 independently received W beats. Each 256-bit
// beat is converted to 32-bit PC words using the contiguous 1GiB address map.
// Naturally aligned 1..32-byte transfers; FIXED, INCR and legal WRAP bursts.
// Input contract: the upstream master supplies legal, naturally aligned bursts
// within [0,1GiB), normal (non-exclusive) accesses, legal strobes and correct
// WLAST. Hardware protocol/error checking is intentionally omitted. B/R return
// OKAY; write completion is counted from AWLEN, not inferred from WLAST.
module mc_addr_decode (
  input  wire logic clk, rst_n,
  input  wire logic [7:0] awid, awlen,
  input  wire logic [39:0] awaddr,
  input  wire logic [2:0] awsize,
  input  wire logic [1:0] awburst,
  input  wire logic awvalid,
  output logic awready,
  input  wire logic [255:0] wdata,
  input  wire logic [31:0] wstrb,
  input  wire logic wvalid,
  output logic wready,
  output logic [7:0] bid,
  output logic [1:0] bresp,
  output logic bvalid,
  input  wire logic bready,
  input  wire logic [7:0] arid, arlen,
  input  wire logic [39:0] araddr,
  input  wire logic [2:0] arsize,
  input  wire logic [1:0] arburst,
  input  wire logic arvalid,
  output logic arready,
  output logic [7:0] rid,
  output logic [255:0] rdata,
  output logic [1:0] rresp,
  output logic rlast, rvalid,
  input  wire logic rready,
  output logic [31:0] cmd_push_val,
  output logic [31:0][35:0] cmd_push_entry,
  input  wire logic [31:0] cmdq_full,
  output logic [31:0] wdb_push_val,
  output logic [31:0][31:0] wdb_push_data,
  output logic [31:0][3:0] wdb_push_mask,
  input  wire logic [31:0][3:0] wdb_alloc_ptr,
  input  wire logic [31:0] wdb_full, wr_done,
  input  wire logic [31:0] rdb_valid,
  output logic [31:0] rdb_ready,
  input  wire logic [31:0][31:0] rdb_data
);
  typedef enum logic [3:0] {
    IDLE, W_DATA, W_ISSUE, W_WAIT, B_RESP,
    R_ISSUE, R_WAIT, R_RESP
  } state_t;
  state_t state;
  logic [7:0] txn_id, beat_index, txn_len;
  logic [39:0] beat_addr, wrap_mask;
  logic [2:0] txn_size;
  logic [1:0] txn_burst;
  logic prefer_read;
  logic [255:0] write_beat, read_beat;
  logic [31:0] write_strobes;
  logic [2:0] word_index;
  logic [31:0] byte_enable;
  logic [5:0] beat_bytes, first_lane, final_lane;
  logic [39:0] next_addr;
  logic [13:0] row;
  logic [1:0] bg, bank;
  logic [4:0] col, target;
  logic final_word;
  logic [3:0] word_strobes;

  logic accept_write, last_beat, write_word_done;
  logic [39:0] selected_addr;
  logic [7:0] selected_id, selected_len;
  logic [2:0] selected_size;
  logic [1:0] selected_burst;

  // AW and AR share one descriptor-capture path. Arbitration still alternates
  // preference when both request FIFOs contain an address.
  assign accept_write = awvalid && awready;
  assign selected_id    = accept_write ? awid    : arid;
  assign selected_addr  = accept_write ? awaddr  : araddr;
  assign selected_len   = accept_write ? awlen   : arlen;
  assign selected_size  = accept_write ? awsize  : arsize;
  assign selected_burst = accept_write ? awburst : arburst;

  // The selected word changes only the low three column bits. All other
  // address fields come directly from the current beat address.
  assign col    = {beat_addr[6:5], word_index};
  assign bank   = beat_addr[8:7];
  assign bg     = beat_addr[10:9];
  assign row    = beat_addr[24:11];
  assign target = beat_addr[29:25];
  assign last_beat = beat_index == txn_len;
  assign write_word_done = (state == W_ISSUE && word_strobes == 0) ||
                           (state == W_WAIT && wr_done[target]);
  assign beat_bytes = 6'd1 << txn_size;
  assign first_lane = {1'b0, beat_addr[4:0]};
  assign final_lane = first_lane + beat_bytes - 6'd1;
  assign final_word = word_index == final_lane[4:2];
  assign word_strobes = write_strobes[word_index*4 +: 4];
  always_comb begin
    for (int n = 0; n < 32; n++)
      byte_enable[n] = (n >= int'(first_lane)) && (n <= int'(final_lane));
    next_addr = beat_addr;
    if (txn_burst == 2'b01) next_addr = beat_addr + {34'b0, beat_bytes};
    if (txn_burst == 2'b10)
      next_addr = (beat_addr & ~wrap_mask) |
                  ((beat_addr + {34'b0, beat_bytes}) & wrap_mask);
  end

  // State-held responses never depend on READY. Assembly is unchanged while
  // the completed beat is offered to the return CDC FIFO.
  always_comb begin
    awready = rst_n && state == IDLE && (!arvalid || !prefer_read);
    arready = rst_n && state == IDLE && (!awvalid || prefer_read);
    wready = rst_n && state == W_DATA;
    bid = txn_id;
    bresp = 2'b00;
    bvalid = rst_n && state == B_RESP;
    rid = txn_id;
    rdata = read_beat;
    rresp = 2'b00;
    rlast = last_beat;
    rvalid = rst_n && state == R_RESP;
    cmd_push_val = '0;
    cmd_push_entry = '0;
    wdb_push_val = '0;
    wdb_push_data = '0;
    wdb_push_mask = '0;
    rdb_ready = '0;
    if (rst_n && state == W_ISSUE && word_strobes != 0 &&
        !cmdq_full[target] && !wdb_full[target]) begin
      cmd_push_val[target] = 1'b1;
      cmd_push_entry[target] = {txn_id, 1'b1, row, bg, bank, col, wdb_alloc_ptr[target]};
      wdb_push_val[target] = 1'b1;
      wdb_push_data[target] = write_beat[word_index*32 +: 32];
      wdb_push_mask[target] = ~word_strobes;
    end
    if (rst_n && state == R_ISSUE && !cmdq_full[target]) begin
      cmd_push_val[target] = 1'b1;
      cmd_push_entry[target] = {txn_id, 1'b0, row, bg, bank, col, 4'b0};
    end
    if (rst_n && state == R_WAIT) rdb_ready[target] = 1'b1;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      txn_id <= '0;
      beat_index <= '0;
      txn_len <= '0;
      beat_addr <= '0;
      wrap_mask <= '0;
      txn_size <= '0;
      txn_burst <= '0;
      prefer_read <= 1'b0;
      write_beat <= '0;
      write_strobes <= '0;
      read_beat <= '0;
      word_index <= '0;
    end else begin
      case (state)
        IDLE: if (accept_write || (arvalid && arready)) begin
          txn_id <= selected_id;
          txn_len <= selected_len;
          txn_size <= selected_size;
          txn_burst <= selected_burst;
          beat_addr <= selected_addr;
          beat_index <= '0;
          word_index <= selected_addr[4:2];
          read_beat <= '0;
          wrap_mask <= (({32'b0, selected_len} + 40'd1) << selected_size) - 40'd1;
          prefer_read <= accept_write;
          state <= accept_write ? W_DATA : R_ISSUE;
        end
        W_DATA: if (wvalid && wready) begin
          write_beat <= wdata;
          write_strobes <= wstrb & byte_enable;
          word_index <= beat_addr[4:2];
          state <= W_ISSUE;
        end
        W_ISSUE, W_WAIT: begin
          if (state == W_ISSUE && cmd_push_val[target]) state <= W_WAIT;
          // A masked word finishes immediately; other words wait for formatter
          // capture. Both cases share the same word/beat advancement logic.
          if (write_word_done) begin
            if (!final_word) begin
              word_index <= word_index + 1'b1;
              state <= W_ISSUE;
            end else if (last_beat) state <= B_RESP;
            else begin
              beat_index <= beat_index + 1'b1;
              beat_addr <= next_addr;
              state <= W_DATA;
            end
          end
        end
        B_RESP: if (bready) state <= IDLE;
        R_ISSUE: if (cmd_push_val[target]) state <= R_WAIT;
        R_WAIT: if (rdb_valid[target]) begin
          for (int n = 0; n < 4; n++)
            if (byte_enable[word_index*4+n])
              read_beat[word_index*32+n*8 +: 8] <= rdb_data[target][n*8 +: 8];
          if (final_word) state <= R_RESP;
          else begin word_index <= word_index + 1'b1; state <= R_ISSUE; end
        end
        R_RESP: if (rready) begin
          if (last_beat) state <= IDLE;
          else begin
            beat_index <= beat_index + 1'b1;
            beat_addr <= next_addr;
            word_index <= next_addr[4:2];
            read_beat <= '0;
            state <= R_ISSUE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
