`default_nettype none
`timescale 1ns/1ps

// Self-checking current-RTL integration regression. The scoreboard consumes
// decoded requests and PUBLIC DFI traffic. Test-only forces bypass the AXI
// backend to retain direct queue/capacity/stress coverage of all 32 PCs. A separate PHY memory/return queue drives both independent lanes.
module tb_mc16x2;
  // Intentional testbench scheduling: blocking scoreboard/model updates occur
  // before/after NBA sampling, with the PHY driver on the opposite edge.
  /* verilator lint_off BLKSEQ */
  logic dfi_clk = 1'b0;
  logic ctl_reset_n;
  logic [31:0] cmd_push_val, cmdq_full, wdb_push_val, wdb_full;
  logic [31:0][35:0] cmd_push_entry;
  logic [31:0][31:0] wdb_push_data, rdb_data;
  logic [31:0][3:0] wdb_push_mask, wdb_alloc_ptr;
  logic [31:0] rdb_valid, rdb_ready;
  logic [31:0][7:0] rdb_axi_id;
  logic [15:0] dfi_row_val, dfi_col_val;
  logic [15:0][21:0] dfi_row;
  logic [15:0][11:0] dfi_col;
  logic [15:0][63:0] dfi_wrdata, dfi_rddata;
  logic [15:0][7:0] dfi_wrdata_mask;
  logic [15:0][1:0] dfi_wrdata_en, dfi_rddata_en, dfi_rddata_valid;
  logic [31:0] wr_done;
  logic [31:0] err_cmdq_overflow, err_wdb_overflow, err_ref_deadline_miss;
  logic [31:0] expected_cmd_overflow, expected_wdb_overflow;
  logic pair_returns;
  int unsigned seed, rng;
  int cycle_count;

  mc16x2 dut (
    .aclk(dfi_clk),
    .aresetn(ctl_reset_n),
    .s_axi_awid('0),
    .s_axi_awaddr('0),
    .s_axi_awlen('0),
    .s_axi_awsize('0),
    .s_axi_awburst('0),
    .s_axi_awlock('0),
    .s_axi_awqos('0),
    .s_axi_awcache('0),
    .s_axi_awprot('0),
    .s_axi_awvalid('0),
    .s_axi_awready(),
    .s_axi_wdata('0),
    .s_axi_wstrb('0),
    .s_axi_wlast('0),
    .s_axi_wvalid('0),
    .s_axi_wready(),
    .s_axi_bid(),
    .s_axi_bresp(),
    .s_axi_bvalid(),
    .s_axi_bready('0),
    .s_axi_arid('0),
    .s_axi_araddr('0),
    .s_axi_arlen('0),
    .s_axi_arsize('0),
    .s_axi_arburst('0),
    .s_axi_arlock('0),
    .s_axi_arqos('0),
    .s_axi_arcache('0),
    .s_axi_arprot('0),
    .s_axi_arvalid('0),
    .s_axi_arready(),
    .s_axi_rid(),
    .s_axi_rdata(),
    .s_axi_rresp(),
    .s_axi_rlast(),
    .s_axi_rvalid(),
    .s_axi_rready('0),
    .dfi_clk(dfi_clk),
    .ctl_reset_n(ctl_reset_n),
    .dfi_row_val(dfi_row_val),
    .dfi_row(dfi_row),
    .dfi_col_val(dfi_col_val),
    .dfi_col(dfi_col),
    .dfi_wrdata(dfi_wrdata),
    .dfi_wrdata_mask(dfi_wrdata_mask),
    .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata_en(dfi_rddata_en),
    .dfi_rddata(dfi_rddata),
    .dfi_rddata_valid(dfi_rddata_valid),
    .err_cmdq_overflow(err_cmdq_overflow),
    .err_wdb_overflow(err_wdb_overflow),
    .err_ref_deadline_miss(err_ref_deadline_miss)
  );

  // White-box core regression only; AXI tests exercise the normal public ports.
  // Reapply when stimulus changes for simulators that snapshot force RHS values.
  always @* begin
    force dut.cmd_push_val = cmd_push_val;
    force dut.cmd_push_entry = cmd_push_entry;
    force dut.wdb_push_val = wdb_push_val;
    force dut.wdb_push_data = wdb_push_data;
    force dut.wdb_push_mask = wdb_push_mask;
    force dut.rdb_ready = rdb_ready;
  end
  assign cmdq_full = dut.cmdq_full;
  assign wdb_full = dut.wdb_full;
  assign wdb_alloc_ptr = dut.wdb_alloc_ptr;
  assign rdb_valid = dut.rdb_valid;
  assign rdb_data = dut.rdb_data;
  assign rdb_axi_id = dut.rdb_axi_id;
  assign wr_done = dut.wr_done;
  always #0.5 dfi_clk <= ~dfi_clk;

  typedef struct packed {
    logic [7:0] id;
    logic wr;
    logic [13:0] row;
    logic [1:0] bg, ba;
    logic [4:0] col;
    logic [3:0] ptr;
  } command_t;
  typedef struct packed {
    logic valid;
    command_t command;
    logic [31:0] read_expect;
  } request_t;
  request_t requests [32][256];
  logic [31:0] reference_memory [32][16][4][32];
  logic [31:0] phy_memory [32][16][4][32];
  int pending_reads [32][16][4][32];
  logic [15:0] wb_live [32];
  logic [31:0] wb_data [32][16];
  logic [3:0] wb_mask [32][16];
  int queued [32], outstanding [32];
  int wr_count [32], rd_count [32], ret_count [32], ref_count [32];
  int busy_refresh [32], row_wait [32], col_wait [32];
  logic [15:0] bank_open [32], bank_seen [32], mask_seen [32];
  logic [3:0] row_seen [32];
  logic [13:0] open_row [32][16];
  int last_act [32][16], last_pre [32][16], last_wr_bank [32][16], last_rd_bank [32][16];
  int act_history [32][4], last_col [32], last_wr [32], last_ref [32];
  int row_contention [16], col_contention [16], split_bus [16], dual_returns [16];
  int parallel_channels;
  logic [31:0] stalled;
  logic [31:0][31:0] held_data;
  logic [31:0][7:0] held_id;
  logic [31:0] row_grant_snapshot, col_grant_snapshot;
  // Maximum outstanding reads is 16/PC; 64 entries give a checked margin.
  logic [31:0] return_data [32][64];
  int return_due [32][64], return_head [32], return_tail [32], previous_due [32];
  int next_id [32];

  function automatic logic [13:0] row_pattern(input int n);
    case (n & 3)
      0: return 14'h0001;
      1: return 14'h0123;
      2: return 14'h1555;
      default: return 14'h2AAA;
    endcase
  endfunction
  function automatic int row_index(input logic [13:0] row);
    for (int n = 0; n < 4; n++) if (row == row_pattern(n)) return n;
    $fatal(1, "Unexpected/truncated row address %h", row);
    return 0;
  endfunction
  function automatic int column_for(input int bank);
    return (7*bank + 3) % 32;
  endfunction
  function automatic logic [31:0] pattern(input int p, input int k);
    return 32'hA531_9E27 ^ (32'(p)*32'h1020_4081) ^ (32'(k)*32'h0101_9137) ^ seed;
  endfunction
  function automatic int unsigned random_word();
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    return rng;
  endfunction
  function automatic bit drained();
    for (int p = 0; p < 32; p++)
      if (queued[p] != 0 || outstanding[p] != 0 || wb_live[p] != 0 ||
          return_head[p] != return_tail[p] || rdb_valid[p]) return 0;
    return 1;
  endfunction
  function automatic bit odd_pcs_drained();
    for (int p = 1; p < 32; p += 2) if (ret_count[p] != 18) return 0;
    return 1;
  endfunction

  task automatic reset_model();
    cycle_count = 0;
    stalled = '0;
    held_data = '0;
    held_id = '0;
    parallel_channels = 0;
    foreach (requests[p,id]) requests[p][id] = '0;
    foreach (pending_reads[p,b,r,c]) pending_reads[p][b][r][c] = 0;
    for (int p = 0; p < 32; p++) begin
      wb_live[p] = '0;
      queued[p] = 0; outstanding[p] = 0;
      wr_count[p] = 0; rd_count[p] = 0; ret_count[p] = 0; ref_count[p] = 0;
      busy_refresh[p] = 0; row_wait[p] = 0; col_wait[p] = 0;
      bank_open[p] = '0; bank_seen[p] = '0; mask_seen[p] = '0; row_seen[p] = '0;
      last_col[p] = -1000000; last_wr[p] = -1000000; last_ref[p] = -1000000;
      return_head[p] = 0; return_tail[p] = 0; previous_due[p] = -1;
      for (int b = 0; b < 16; b++) begin
        wb_data[p][b] = '0; wb_mask[p][b] = '0; open_row[p][b] = '0;
        last_act[p][b] = -1000000; last_pre[p][b] = -1000000;
        last_wr_bank[p][b] = -1000000; last_rd_bank[p][b] = -1000000;
      end
      for (int a = 0; a < 4; a++) act_history[p][a] = -1000000;
    end
    for (int ch = 0; ch < 16; ch++) begin
      row_contention[ch] = 0; col_contention[ch] = 0;
      split_bus[ch] = 0; dual_returns[ch] = 0;
    end
  endtask

  // Scoreboard reset clears controller work/return queues, not external memory.
  // Inputs/completions are sampled before NBA; DFI is sampled 1 ps after NBA.
  always @(posedge dfi_clk) begin : scoreboard
    command_t cmd;
    int b, r, c, p, found, ptr, due;
    logic [31:0] payload;
    logic [3:0] mask;
    if (!ctl_reset_n) begin
      reset_model();
      #1ps;
      if (dfi_row_val !== '0 || dfi_col_val !== '0 || dfi_wrdata_en !== '0 ||
          dfi_rddata_en !== '0 || rdb_valid !== '0 || cmdq_full !== '0 || wdb_full !== '0)
        $fatal(1, "Reset did not clear command/data/status outputs");
    end else begin
      cycle_count++;
      if (err_cmdq_overflow !== expected_cmd_overflow ||
          err_wdb_overflow !== expected_wdb_overflow || err_ref_deadline_miss !== '0)
        $fatal(1, "Unexpected/missing error flags at cycle %0d CMDQ=%h WDB=%h REF=%h",
               cycle_count, err_cmdq_overflow, err_wdb_overflow, err_ref_deadline_miss);
      row_grant_snapshot = dut.row_grant;
      col_grant_snapshot = dut.col_grant;
      for (int q = 0; q < 32; q++) begin
        if (stalled[q] && (!rdb_valid[q] || rdb_data[q] !== held_data[q] || rdb_axi_id[q] !== held_id[q]))
          $fatal(1, "PC%0d completion changed under backpressure", q);
        stalled[q] = rdb_valid[q] && !rdb_ready[q];
        held_data[q] = rdb_data[q]; held_id[q] = rdb_axi_id[q];
        if (rdb_valid[q]) begin
          found = int'(rdb_axi_id[q]);
          if (!requests[q][found].valid || requests[q][found].command.wr ||
              rd_count[q] <= ret_count[q] || rdb_data[q] !== requests[q][found].read_expect)
            $fatal(1, "PC%0d wrong/duplicate read ID/data id=%0h got=%h expected=%h",
                   q, rdb_axi_id[q], rdb_data[q], requests[q][found].read_expect);
          if (rdb_ready[q]) begin
            requests[q][found].valid = 0; outstanding[q]--; ret_count[q]++;
          end
        end
        if (wdb_push_val[q] && !wdb_full[q]) begin
          ptr = int'(wdb_alloc_ptr[q]);
          if (wb_live[q][ptr]) $fatal(1, "PC%0d reused live WDB pointer %0d", q, ptr);
          wb_live[q][ptr] = 1;
          wb_data[q][ptr] = wdb_push_data[q]; wb_mask[q][ptr] = wdb_push_mask[q];
        end
        if (cmd_push_val[q] && !cmdq_full[q]) begin
          cmd = command_t'(cmd_push_entry[q]);
          if (requests[q][cmd.id].valid) $fatal(1, "Driver reused outstanding PC%0d ID%0d", q, cmd.id);
          b = int'({cmd.bg, cmd.ba}); r = row_index(cmd.row); c = int'(cmd.col);
          requests[q][cmd.id].valid = 1; requests[q][cmd.id].command = cmd;
          requests[q][cmd.id].read_expect = reference_memory[q][b][r][c];
          if (!cmd.wr) pending_reads[q][b][r][c]++;
          queued[q]++; outstanding[q]++;
        end
        row_wait[q] = dut.row_req_valid[q] && !dut.row_grant[q] ? row_wait[q]+1 : 0;
        col_wait[q] = dut.col_req_valid[q] && !dut.col_grant[q] ? col_wait[q]+1 : 0;
        if (row_wait[q] > 1024 || col_wait[q] > 2)
          $fatal(1, "PC%0d continuously eligible candidate made no progress", q);
      end
      for (int ch = 0; ch < 16; ch++) begin
        if (!$onehot0(dut.row_grant[2*ch +: 2]) || !$onehot0(dut.col_grant[2*ch +: 2]) ||
            ((dut.row_grant[2*ch +: 2] & ~dut.row_req_valid[2*ch +: 2]) != 0) ||
            ((dut.col_grant[2*ch +: 2] & ~dut.col_req_valid[2*ch +: 2]) != 0))
          $fatal(1, "CH%0d illegal/duplicate grant", ch);
        if ((dut.row_req_valid[2*ch +: 2] & dut.row_req_refresh[2*ch +: 2]) != 0 &&
            (dut.row_grant[2*ch +: 2] & dut.row_req_refresh[2*ch +: 2]) == 0)
          $fatal(1, "CH%0d refresh priority violated", ch);
        if (&dut.row_req_valid[2*ch +: 2]) row_contention[ch]++;
        if (&dut.col_req_valid[2*ch +: 2]) col_contention[ch]++;
        if (&dfi_rddata_valid[ch]) dual_returns[ch]++;
      end
      #1ps;
      if ($countones(dfi_row_val) > 1 || $countones(dfi_col_val) > 1) parallel_channels++;
      for (int ch = 0; ch < 16; ch++) begin
        if (dfi_row_val[ch] !== (|row_grant_snapshot[2*ch +: 2]) ||
            dfi_col_val[ch] !== (|col_grant_snapshot[2*ch +: 2]))
          $fatal(1, "CH%0d formatter valid/grant feedback mismatch", ch);
        if (dfi_row_val[ch]) begin
          p = 2*ch + int'(dfi_row[ch][21]);
          if (!row_grant_snapshot[p]) $fatal(1, "CH%0d row PC-select misroute", ch);
          b = int'(dfi_row[ch][17:14]);
          if (cycle_count - last_ref[p] < 350) $fatal(1, "PC%0d row inside tRFC", p);
          case (dfi_row[ch][20:18])
            3'b001: begin
              r = row_index(dfi_row[ch][13:0]);
              if (bank_open[p][b] || cycle_count-last_pre[p][b] < 14 ||
                  cycle_count-last_act[p][b] < 50 || cycle_count-act_history[p][0] < 6 ||
                  cycle_count-act_history[p][3] < 32) $fatal(1, "PC%0d illegal ACT/timing", p);
              bank_open[p][b] = 1; open_row[p][b] = dfi_row[ch][13:0];
              bank_seen[p][b] = 1; row_seen[p][r] = 1; last_act[p][b] = cycle_count;
              for (int a = 3; a > 0; a--) act_history[p][a] = act_history[p][a-1];
              act_history[p][0] = cycle_count;
            end
            3'b010: begin
              if (!bank_open[p][b] || cycle_count-last_act[p][b] < 34 ||
                  cycle_count-last_wr_bank[p][b] < 18 || cycle_count-last_rd_bank[p][b] < 8)
                $fatal(1, "PC%0d illegal PRE/tRAS/tWR/tRTP", p);
              bank_open[p][b] = 0; last_pre[p][b] = cycle_count;
            end
            3'b100: begin
              if (bank_open[p] != 0) $fatal(1, "PC%0d REF with open banks", p);
              for (int k = 0; k < 16; k++)
                if (cycle_count-last_pre[p][k] < 14) $fatal(1, "PC%0d REF before tRP", p);
              ref_count[p]++; if (queued[p] > 0) busy_refresh[p]++;
              last_ref[p] = cycle_count;
            end
            default: $fatal(1, "CH%0d unsupported row encoding", ch);
          endcase
        end
        if (dfi_row_val[ch] && dfi_col_val[ch] && dfi_row[ch][21] != dfi_col[ch][11]) split_bus[ch]++;
        if (dfi_col_val[ch]) begin
          p = 2*ch + int'(dfi_col[ch][11]);
          if (!col_grant_snapshot[p]) $fatal(1, "CH%0d column PC-select misroute", ch);
          b = int'(dfi_col[ch][8:5]); c = int'(dfi_col[ch][4:0]); r = row_index(open_row[p][b]);
          if (!bank_open[p][b] || cycle_count-last_act[p][b] < 18 ||
              cycle_count-last_col[p] < 4 || cycle_count-last_ref[p] < 350 || queued[p] <= 0)
            $fatal(1, "PC%0d illegal column/tRCD/tCCD/tRFC", p);
          last_col[p] = cycle_count; queued[p]--;
          case (dfi_col[ch][10:9])
            2'b10: begin
              found = -1;
              for (int id = 0; id < 256; id++)
                if (requests[p][id].valid && requests[p][id].command.wr &&
                    requests[p][id].command.row == open_row[p][b] &&
                    {requests[p][id].command.bg, requests[p][id].command.ba} == 4'(b) &&
                    requests[p][id].command.col == 5'(c)) begin
                  if (found >= 0) $fatal(1, "Ambiguous duplicate write address in test stimulus");
                  found = id;
                end
              if (found < 0) $fatal(1, "PC%0d unsolicited/misrouted WR", p);
              ptr = int'(requests[p][found].command.ptr);
              payload = dfi_wrdata[ch][(p%2)*32 +: 32]; mask = dfi_wrdata_mask[ch][(p%2)*4 +: 4];
              if (!wb_live[p][ptr] || payload !== wb_data[p][ptr] || mask !== wb_mask[p][ptr])
                $fatal(1, "PC%0d WDB pointer/data/mask or lane isolation mismatch", p);
              // Explicit model convention: DFI DM=1 inhibits a byte write.
              for (int byte_n = 0; byte_n < 4; byte_n++) begin
                if (!wb_mask[p][ptr][byte_n]) reference_memory[p][b][r][c][byte_n*8 +: 8] = wb_data[p][ptr][byte_n*8 +: 8];
                if (!mask[byte_n]) phy_memory[p][b][r][c][byte_n*8 +: 8] = payload[byte_n*8 +: 8];
              end
              mask_seen[p][mask] = 1; wb_live[p][ptr] = 0;
              requests[p][found].valid = 0; outstanding[p]--; wr_count[p]++;
              last_wr[p] = cycle_count; last_wr_bank[p][b] = cycle_count;
            end
            2'b01: begin
              if (cycle_count-last_wr[p] < 8 || pending_reads[p][b][r][c] <= 0)
                $fatal(1, "PC%0d unsolicited/misrouted RD or tWTR violation", p);
              pending_reads[p][b][r][c]--; rd_count[p]++; last_rd_bank[p][b] = cycle_count;
              if (rd_count[p]-ret_count[p] > 16 || return_tail[p]-return_head[p] >= 64)
                $fatal(1, "PC%0d overissued RDB/PHY capacity", p);
              due = ((cycle_count + 8 + int'((seed ^ 32'(p) ^ 32'(rd_count[p])) & 7) + 15)/16)*16;
              if (due <= previous_due[p]) due = previous_due[p]+1;
              previous_due[p] = due;
              return_data[p][return_tail[p]%64] = phy_memory[p][b][r][c];
              return_due[p][return_tail[p]%64] = due; return_tail[p]++;
            end
            default: $fatal(1, "CH%0d unsupported column encoding", ch);
          endcase
        end
        for (int pc = 0; pc < 2; pc++) begin
          logic wr_expected, rd_expected;
          wr_expected = dfi_col_val[ch] && (int'(dfi_col[ch][11]) == pc) && (dfi_col[ch][10:9] == 2'b10);
          rd_expected = dfi_col_val[ch] && (int'(dfi_col[ch][11]) == pc) && (dfi_col[ch][10:9] == 2'b01);
          if (dfi_wrdata_en[ch][pc] !== wr_expected || dfi_rddata_en[ch][pc] !== rd_expected)
            $fatal(1, "CH%0d PC%0d command/data-enable alignment mismatch", ch, pc);
          if (!wr_expected && (dfi_wrdata[ch][pc*32 +: 32] !== 0 || dfi_wrdata_mask[ch][pc*4 +: 4] !== 0))
            $fatal(1, "CH%0d PC%0d inactive write lane leaked payload", ch, pc);
        end
      end
      for (int q = 0; q < 32; q++)
        if (wdb_full[q] !== (&wb_live[q]) || cmdq_full[q] !== (queued[q] == 32))
          $fatal(1, "PC%0d queue/full status or WDB release mismatch", q);
    end
  end

  // Independent, in-order PHY responses. Paired mode deliberately exercises
  // simultaneous returns on both lanes; normal mode permits independent delay.
  always @(negedge dfi_clk) begin : phy_driver
    bit pair_ready;
    dfi_rddata_valid = '0; dfi_rddata = '0;
    if (ctl_reset_n) begin
      for (int ch = 0; ch < 16; ch++) begin
        pair_ready = 1;
        for (int pc = 0; pc < 2; pc++)
          if (return_head[2*ch+pc] == return_tail[2*ch+pc] ||
              return_due[2*ch+pc][return_head[2*ch+pc]%64] > cycle_count) pair_ready = 0;
        for (int pc = 0; pc < 2; pc++) begin
          int p;
          p = 2*ch+pc;
          if ((!pair_returns || pair_ready) && return_head[p] < return_tail[p] &&
              return_due[p][return_head[p]%64] <= cycle_count) begin
            dfi_rddata_valid[ch][pc] = 1;
            dfi_rddata[ch][pc*32 +: 32] = return_data[p][return_head[p]%64];
            return_head[p]++;
          end
        end
      end
    end
  end

  task automatic reset_dut();
    @(negedge dfi_clk);
    ctl_reset_n = 0; cmd_push_val = '0; wdb_push_val = '0; rdb_ready = '0;
    expected_cmd_overflow = '0; expected_wdb_overflow = '0; pair_returns = 0;
    repeat (4) @(negedge dfi_clk);
    if (wdb_alloc_ptr !== '0) $fatal(1, "Reset left nonzero WDB allocation pointers");
    ctl_reset_n = 1;
    repeat (2) @(negedge dfi_clk);
  endtask

  // kind 0=read, 1=write with payload, 2=write waiting for absent payload.
  task automatic batch(input int kind, input int id, input int bank);
    command_t cmd;
    @(negedge dfi_clk);
    cmd_push_val = '0; wdb_push_val = '0;
    for (int p = 0; p < 32; p++) begin
      if (cmdq_full[p] || (kind == 1 && wdb_full[p])) $fatal(1, "Directed stimulus has no admission space");
      cmd = '{id:8'(id), wr:(kind != 0), row:row_pattern(p+bank),
              bg:2'(bank/4), ba:2'(bank%4), col:5'(column_for(bank)), ptr:wdb_alloc_ptr[p]};
      cmd_push_entry[p] = cmd; cmd_push_val[p] = 1;
      if (kind == 1) begin
        wdb_push_val[p] = 1; wdb_push_data[p] = pattern(p,bank); wdb_push_mask[p] = 4'(bank);
      end
    end
    @(negedge dfi_clk);
    cmd_push_val = '0; wdb_push_val = '0;
  endtask

  task automatic drain_all();
    int limit;
    limit = 0;
    while (!drained() && limit < 5000) begin @(negedge dfi_clk); limit++; end
    if (!drained()) $fatal(1, "Drain timeout: PC0 queued=%0d outstanding=%0d", queued[0], outstanding[0]);
  endtask

  initial begin : stimulus
    int baseline [32];
    int limit, id, bank;
    command_t cmd;
    seed = 1;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    rng = seed == 0 ? 1 : seed;
    ctl_reset_n = 0; cmd_push_val = '0; cmd_push_entry = '0;
    wdb_push_val = '0; wdb_push_data = '0; wdb_push_mask = '0; rdb_ready = '0;
    expected_cmd_overflow = '0; expected_wdb_overflow = '0; pair_returns = 0;
    foreach (reference_memory[p,b,r,c]) begin
      reference_memory[p][b][r][c] = '0; phy_memory[p][b][r][c] = '0;
    end
    $display("mc16x2 regression seed=%0d", seed);
    reset_dut();

    $display("TEST reset during in-flight reads");
    batch(0, 1, 0);
    limit = 0;
    while (rd_count[31] == 0 && limit < 100) begin @(negedge dfi_clk); limit++; end
    if (rd_count[31] == 0 || return_head[31] == return_tail[31]) $fatal(1, "No in-flight work for reset test");
    reset_dut();
    repeat (32) @(negedge dfi_clk);
    if (rdb_valid != 0 || !drained()) $fatal(1, "Stale completions survived reset");

    $display("TEST all-PC WDB capacity and deliberate overflow");
    for (int n = 0; n < 16; n++) begin
      @(negedge dfi_clk);
      wdb_push_val = '1;
      for (int p = 0; p < 32; p++) begin wdb_push_data[p] = pattern(p,n); wdb_push_mask[p] = 4'(n); end
      @(negedge dfi_clk); wdb_push_val = '0;
    end
    if (wdb_full !== '1) $fatal(1, "WDB capacity is not 16 in every PC");
    @(negedge dfi_clk); expected_wdb_overflow = '1; wdb_push_val = '1;
    @(negedge dfi_clk); wdb_push_val = '0; expected_wdb_overflow = '0;
    reset_dut();

    $display("TEST all-PC CMDQ capacity and deliberate overflow");
    for (int n = 0; n < 32; n++) batch(2, n, n%16);
    if (cmdq_full !== '1) $fatal(1, "CMDQ capacity is not 32 in every PC");
    @(negedge dfi_clk); expected_cmd_overflow = '1; cmd_push_val = '1;
    @(negedge dfi_clk); cmd_push_val = '0; expected_cmd_overflow = '0;
    reset_dut();

    $display("TEST all channels/PCs/banks, distinct data, all masks and WDB reuse");
    rdb_ready = '1;
    for (int n = 0; n < 16; n++) batch(1, n, n);
    drain_all();
    repeat (50) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++)
      if (wr_count[p] != 16 || bank_seen[p] != 16'hFFFF || mask_seen[p] != 16'hFFFF || row_seen[p] != 4'hF)
        $fatal(1, "PC%0d missing directed write/address/mask coverage", p);

    $display("TEST all-PC RDB capacity, simultaneous PHY lanes and independent PC stalls");
    rdb_ready = '0; pair_returns = 1;
    for (int n = 0; n < 18; n++) batch(0, 64+n, n%16);
    repeat (250) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++)
      if (rd_count[p] != 16 || ret_count[p] != 0 || queued[p] != 2 || !rdb_valid[p])
        $fatal(1, "PC%0d RDB full/backpressure failed issued=%0d queued=%0d", p, rd_count[p], queued[p]);
    // PC1 must drain while its sibling PC0 remains blocked.
    pair_returns = 0;
    rdb_ready = 32'hAAAA_AAAA;
    limit = 0;
    while (!odd_pcs_drained() && limit < 500) begin @(negedge dfi_clk); limit++; end
    for (int p = 0; p < 32; p++)
      if ((p%2 == 0 && (ret_count[p] != 0 || rd_count[p] != 16)) ||
          (p%2 == 1 && ret_count[p] != 18)) $fatal(1, "PC%0d sibling backpressure leaked", p);
    pair_returns = 0; rdb_ready = '1; drain_all();

    $display("TEST row conflict and different-PC row/column issue in the same cycle");
    repeat (50) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++) baseline[p] = ret_count[p];
    @(negedge dfi_clk);
    for (int p = 0; p < 32; p++) begin
      cmd = '{id:8'd96, wr:(p%2 == 0), row:row_pattern(p + (p%2 == 0 ? 1 : 0)),
              bg:2'b00, ba:2'b00, col:5'(column_for(0)), ptr:wdb_alloc_ptr[p]};
      cmd_push_entry[p] = cmd; cmd_push_val[p] = 1;
      if (p%2 == 0) begin wdb_push_val[p] = 1; wdb_push_data[p] = pattern(p,96); wdb_push_mask[p] = 0; end
    end
    @(negedge dfi_clk); cmd_push_val = '0; wdb_push_val = '0;
    drain_all();
    for (int p = 1; p < 32; p += 2)
      if (ret_count[p] != baseline[p]+1) $fatal(1, "Mixed row/column read did not complete");

    $display("TEST seeded saturation, randomized RREADY, pointer wrap and refresh under load");
    for (int p = 0; p < 32; p++) next_id[p] = 128;
    for (int n = 0; n < 4500; n++) begin
      @(negedge dfi_clk);
      cmd_push_val = '0;
      rdb_ready = random_word();
      for (int p = 0; p < 32; p++) begin
        id = next_id[p]; bank = int'(random_word() & 15);
        if (!cmdq_full[p] && !requests[p][id].valid && (random_word() & 1) != 0) begin
          cmd = '{id:8'(id), wr:1'b0, row:row_pattern(p+bank),
                  bg:2'(bank/4), ba:2'(bank%4), col:5'(column_for(bank)), ptr:4'b0};
          cmd_push_entry[p] = cmd; cmd_push_val[p] = 1;
          next_id[p] = (id+1)%256;
        end
      end
    end
    @(negedge dfi_clk); cmd_push_val = '0; rdb_ready = '1;
    drain_all();
    repeat (4) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++)
      if (ref_count[p] == 0 || busy_refresh[p] == 0 || rd_count[p] != ret_count[p] || rd_count[p] < 100)
        $fatal(1, "PC%0d missing refresh/load/completion coverage", p);
    for (int ch = 0; ch < 16; ch++) begin
      if (row_contention[ch] == 0 || col_contention[ch] == 0 || split_bus[ch] == 0 || dual_returns[ch] == 0)
        $fatal(1, "CH%0d missing arbitration/split-bus/dual-return coverage", ch);
      $display("CH%0d PASS writes=%0d/%0d reads=%0d/%0d refresh=%0d/%0d row-contention=%0d col-contention=%0d split=%0d dual-return=%0d",
               ch, wr_count[2*ch], wr_count[2*ch+1], rd_count[2*ch], rd_count[2*ch+1],
               ref_count[2*ch], ref_count[2*ch+1], row_contention[ch], col_contention[ch], split_bus[ch], dual_returns[ch]);
    end
    if (parallel_channels == 0) $fatal(1, "No concurrent channel issue observed");

    $display("TEST reset recovery and command waiting for delayed payload");
    reset_dut();
    rdb_ready = '1;
    // External memory survives reset; new IDs must still match its old data.
    batch(0, 2, 0);
    drain_all();
    @(negedge dfi_clk);
    for (int p = 0; p < 32; p++) begin
      cmd = '{id:8'd3, wr:1'b1, row:row_pattern(p), bg:2'b00, ba:2'b00, col:5'd30, ptr:4'd0};
      cmd_push_entry[p] = cmd; cmd_push_val[p] = 1;
    end
    @(negedge dfi_clk); cmd_push_val = '0;
    // No other allocation intervenes: pointer zero is reserved by this test.
    repeat (40) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++)
      if (wr_count[p] != 0 || queued[p] != 1 || wdb_alloc_ptr[p] != 0)
        $fatal(1, "PC%0d issued a write before its payload arrived", p);
    wdb_push_val = '1;
    for (int p = 0; p < 32; p++) begin wdb_push_data[p] = pattern(p,100); wdb_push_mask[p] = 0; end
    @(negedge dfi_clk); wdb_push_val = '0;
    drain_all();
    @(negedge dfi_clk);
    for (int p = 0; p < 32; p++) begin
      cmd = '{id:8'd4, wr:1'b0, row:row_pattern(p), bg:2'b00, ba:2'b00, col:5'd30, ptr:4'd0};
      cmd_push_entry[p] = cmd; cmd_push_val[p] = 1;
    end
    @(negedge dfi_clk); cmd_push_val = '0;
    drain_all();
    repeat (4) @(negedge dfi_clk);
    for (int p = 0; p < 32; p++)
      if (wr_count[p] != 1 || rd_count[p] != 2 || ret_count[p] != 2)
        $fatal(1, "PC%0d failed post-reset/delayed-payload recovery", p);
    $display("PASS mc16x2 seed=%0d: all 32 PCs, 16 channels, bank/row/mask coverage, capacity, stalls, reset, timing and busy refresh checked", seed);
    $finish;
  end

  initial begin
    #30000;
    $fatal(1, "mc16x2 regression watchdog");
  end
  /* verilator lint_on BLKSEQ */
endmodule : tb_mc16x2
`default_nettype wire
