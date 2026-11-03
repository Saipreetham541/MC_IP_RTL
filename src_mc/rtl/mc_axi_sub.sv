`default_nettype none
`timescale 1ns/1ps

// Post-CDC AXI transaction engine. One active burst preserves per-ID ordering
// and completed-write visibility. Aligned INCR transfers: 1..32 bytes/beat,
// 1..16 beats/burst. AW/AR arbitration is round-robin between transactions.
// A column is one 32-byte memory location; cores buffer an entire AXI beat.
// B is posted after all valid beats are owned by the cores. New transactions
// wait for their data transfers to finish, preserving read-after-write order.
module mc_axi_sub (
  input logic clk, rst_n,
  input logic enable,
  input logic [15:0] channel_enable,
  input logic [31:0] wdata_timeout,
  input logic [7:0] awid,
  input logic [39:0] awaddr,
  input logic [7:0] awlen,
  input logic [2:0] awsize,
  input logic [1:0] awburst,
  input logic awvalid,
  output logic awready,
  input logic [255:0] wdata,
  input logic [31:0] wstrb,
  input logic wlast, wvalid,
  output logic wready,
  output logic [7:0] bid,
  output logic [1:0] bresp,
  output logic bvalid,
  input logic bready,
  input logic [7:0] arid,
  input logic [39:0] araddr,
  input logic [7:0] arlen,
  input logic [2:0] arsize,
  input logic [1:0] arburst,
  input logic arvalid,
  output logic arready,
  output logic [7:0] rid,
  output logic [255:0] rdata,
  output logic [1:0] rresp,
  output logic rlast, rvalid,
  input logic rready,
  output logic [31:0] cmd_push_val,
  output logic [31:0][35:0] cmd_push_entry,
  input logic [31:0] cmdq_full,
  output logic [31:0] wdb_push_val,
  output logic [31:0][255:0] wdb_push_data,
  output logic [31:0][31:0] wdb_push_mask,
  input logic [31:0][3:0] wdb_alloc_ptr,
  input logic [31:0] wdb_full,
  input logic [31:0] write_done,
  input logic [31:0] rdb_valid,
  input logic [31:0][255:0] rdb_data,
  input logic [31:0][7:0] rdb_axi_id,
  output logic [31:0] rdb_ready,
  output logic busy, write_faulted,
  output logic error_protocol, error_timeout,
  output logic write_complete, read_complete
);
  typedef enum logic [2:0] {IDLE, WRITE_DATA, WRITE_RESPONSE, WRITE_DRAIN,
                           READ_COMMAND, READ_WAIT, READ_RESPONSE} state_t;
  state_t state;
  logic [39:0] address;
  logic [7:0] transaction_id, length, beat;
  logic [2:0] size;
  logic [1:0] response;
  logic prefer_read;
  logic [5:0] pending_writes;
  logic [31:0] timeout_count;
  logic [255:0] read_buffer;
  logic [1:0] read_response;
  logic [3:0] channel;
  logic pc;
  logic [13:0] row;
  logic [1:0] bg, bank;
  logic [4:0] col, offset;
  logic [4:0] destination;
  logic [31:0] byte_lanes;
  logic bad_write_beat, accept_write_command;
  logic [255:0] read_lane_mask;

  mc_addr_decode u_addr_decode (
    .addr(address), .ch_sel(channel), .pc_sel(pc), .row_addr(row),
    .bank_group(bg), .bank_addr(bank), .col_addr(col), .byte_offset(offset)
  );
  assign destination = {channel, pc};
  assign busy = (state != IDLE);
  assign bad_write_beat = (wlast != (beat == length)) || ((wstrb & ~byte_lanes) != 0);
  assign accept_write_command = (state == WRITE_DATA) && wvalid && wready &&
                                response == 0 && !bad_write_beat;

  function automatic logic [1:0] validate(
    input logic [39:0] addr, input logic [7:0] len,
    input logic [2:0] sz, input logic [1:0] burst
  );
    logic [40:0] final_address;
    if (addr[39:33] != 0 || !channel_enable[addr[32:29]]) return 2'b11;
    if (len > 15 || sz > 5 || burst != 2'b01) return 2'b10;
    final_address = {1'b0,addr} + ((41'(len)+1) << sz) - 1;
    if ((addr & ((40'd1 << sz)-1)) != 0 || final_address[40:12] != {1'b0,addr[39:12]})
      return 2'b10;
    return 2'b00;
  endfunction

  always_comb begin
    byte_lanes = '0;
    read_lane_mask = '0;
    for (int n = 0; n < 32; n++) begin
      byte_lanes[n] = (n >= int'(offset)) && (n < int'(offset) + (1 << size));
      read_lane_mask[n*8 +: 8] = {8{byte_lanes[n]}};
    end
    awready = state == IDLE && enable && !write_faulted && (!arvalid || !prefer_read);
    arready = state == IDLE && enable && (!awvalid || prefer_read || write_faulted);
    wready = state == WRITE_DATA &&
             ((response != 0 || bad_write_beat) || (!cmdq_full[destination] && !wdb_full[destination]));
    bid = transaction_id;
    bresp = response;
    bvalid = state == WRITE_RESPONSE;
    rid = transaction_id;
    rdata = read_buffer;
    rresp = read_response;
    rlast = beat == length;
    rvalid = state == READ_RESPONSE;
    cmd_push_val = '0; cmd_push_entry = '0;
    wdb_push_val = '0; wdb_push_data = '0; wdb_push_mask = '0;
    rdb_ready = '0;
    if (accept_write_command) begin
      cmd_push_val[destination] = 1;
      cmd_push_entry[destination] = {transaction_id, 1'b1, row, bg, bank, col, wdb_alloc_ptr[destination]};
      wdb_push_val[destination] = 1;
      wdb_push_data[destination] = wdata;
      wdb_push_mask[destination] = ~wstrb;
    end
    if (state == READ_COMMAND && response == 0 && !cmdq_full[destination]) begin
      cmd_push_val[destination] = 1;
      cmd_push_entry[destination] = {transaction_id, 1'b0, row, bg, bank, col, 4'b0};
    end
    if (state == READ_WAIT) rdb_ready[destination] = 1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE; address <= '0; transaction_id <= '0;
      length <= '0; beat <= '0; size <= '0; response <= '0;
      prefer_read <= 0; pending_writes <= 0; timeout_count <= 0;
      read_buffer <= '0; read_response <= '0;
      error_protocol <= 0; error_timeout <= 0; write_faulted <= 0;
      write_complete <= 0; read_complete <= 0;
    end else begin
      error_protocol <= 0; error_timeout <= 0;
      write_complete <= 0; read_complete <= 0;
      pending_writes <= pending_writes + 6'(accept_write_command) - 6'($countones(write_done));
      case (state)
        IDLE: begin
          timeout_count <= 0;
          if (awvalid && awready) begin
            transaction_id <= awid; address <= awaddr; length <= awlen;
            size <= awsize; beat <= 0; response <= validate(awaddr,awlen,awsize,awburst);
            state <= WRITE_DATA;
            if (validate(awaddr,awlen,awsize,awburst) != 0) error_protocol <= 1;
          end else if (arvalid && arready) begin
            transaction_id <= arid; address <= araddr; length <= arlen;
            size <= arsize; beat <= 0; response <= validate(araddr,arlen,arsize,arburst);
            state <= READ_COMMAND;
            if (validate(araddr,arlen,arsize,arburst) != 0) error_protocol <= 1;
          end
        end
        WRITE_DATA: begin
          if (wvalid && wready) begin
            timeout_count <= 0;
            if (bad_write_beat) begin
              if (response == 0) response <= 2'b10;
              error_protocol <= 1;
            end
            if (beat == length) state <= WRITE_RESPONSE;
            else begin beat <= beat+1'b1; address <= address+(40'd1 << size); end
          end else if (!wvalid && wdata_timeout != 0) begin
            if (timeout_count >= wdata_timeout-1) begin
              response <= 2'b10; error_timeout <= 1; write_faulted <= 1;
              state <= WRITE_RESPONSE;
            end else timeout_count <= timeout_count+1'b1;
          end
        end
        WRITE_RESPONSE: if (bready) begin
          write_complete <= 1; prefer_read <= 1; state <= WRITE_DRAIN;
        end
        WRITE_DRAIN: if (pending_writes == 0) state <= IDLE;
        READ_COMMAND: begin
          if (response != 0) begin
            read_buffer <= 0; read_response <= response; state <= READ_RESPONSE;
          end else if (!cmdq_full[destination]) state <= READ_WAIT;
        end
        READ_WAIT: if (rdb_valid[destination]) begin
          read_buffer <= rdb_data[destination] & read_lane_mask;
          read_response <= (rdb_axi_id[destination] == transaction_id) ? 2'b00 : 2'b10;
          if (rdb_axi_id[destination] != transaction_id) error_protocol <= 1;
          state <= READ_RESPONSE;
        end
        READ_RESPONSE: if (rready) begin
          if (beat == length) begin
            read_complete <= 1; prefer_read <= 0; state <= IDLE;
          end else begin
            beat <= beat+1'b1; address <= address+(40'd1 << size); state <= READ_COMMAND;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
