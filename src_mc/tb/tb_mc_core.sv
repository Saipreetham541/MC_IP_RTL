`timescale 1ns/1ps

// Waveform demo: reset, write one word, then read the same word back.
// A small behavioral memory supplies read data after READ_LATENCY clocks.
// Full stress, backpressure and refresh coverage lives in tb_mc16x2.
module tb_mc_core;
  localparam int DATA_W = 32;
  localparam int MASK_W = DATA_W / 8;
  localparam int AXI_ID_W = 8;
  localparam int WDB_DEPTH = 16;
  localparam int WDB_ADDR_W = $clog2(WDB_DEPTH);
  localparam int ROW_ADDR_W = 14;
  localparam int COL_ADDR_W = 5;
  localparam int BG_ADDR_W = 2;
  localparam int BANK_ADDR_W = 2;
  localparam int READ_LATENCY = 5;
  localparam logic [2:0] ROW_CMD_ACT = 3'b001;
  localparam logic [1:0] COL_CMD_RD = 2'b01;
  localparam logic [1:0] COL_CMD_WR = 2'b10;
  localparam logic [ROW_ADDR_W-1:0] TEST_ROW = 14'h0123;
  localparam logic [COL_ADDR_W-1:0] TEST_COL = 5'h04;
  localparam logic [DATA_W-1:0] TEST_DATA = 32'h1234_ABCD;
  localparam logic [MASK_W-1:0] TEST_MASK = 4'b0000;
  localparam logic [AXI_ID_W-1:0] WRITE_ID = 8'h11;
  localparam logic [AXI_ID_W-1:0] READ_ID = 8'h21;

  typedef struct packed {
    logic [AXI_ID_W-1:0] axi_id;
    logic is_write;
    logic [ROW_ADDR_W-1:0] row;
    logic [BG_ADDR_W-1:0] bankgroup;
    logic [BANK_ADDR_W-1:0] bank;
    logic [COL_ADDR_W-1:0] col;
    logic [WDB_ADDR_W-1:0] wdb_ptr;
  } cmd_entry_t;

  logic clk;
  logic rst_n;
  logic cmd_push_val;
  cmd_entry_t cmd_push_entry;
  logic cmdq_full;
  logic wdb_push_val;
  logic [DATA_W-1:0] wdb_push_data;
  logic [MASK_W-1:0] wdb_push_mask;
  logic [WDB_ADDR_W-1:0] wdb_alloc_ptr;
  logic wdb_full;
  logic [WDB_ADDR_W-1:0] wdb_raddr;
  logic [DATA_W-1:0] wdb_rdata;
  logic [MASK_W-1:0] wdb_rmask;
  logic wdb_pop_val;
  logic [WDB_ADDR_W-1:0] wdb_pop_ptr;
  logic dfi_rddata_valid;
  logic [DATA_W-1:0] dfi_rddata;
  logic rdb_valid;
  logic rdb_ready;
  logic [DATA_W-1:0] rdb_data;
  logic [AXI_ID_W-1:0] rdb_axi_id;
  logic row_req_val;
  logic row_req_is_ref;
  logic [2:0] row_req_cmd;
  logic [ROW_ADDR_W-1:0] row_req_addr;
  logic [BG_ADDR_W-1:0] row_req_bg;
  logic [BANK_ADDR_W-1:0] row_req_bank;
  logic row_req_grant;
  logic col_req_val;
  logic [1:0] col_req_cmd;
  logic [COL_ADDR_W-1:0] col_req_addr;
  logic [BG_ADDR_W-1:0] col_req_bg;
  logic [BANK_ADDR_W-1:0] col_req_bank;
  logic [WDB_ADDR_W-1:0] col_req_wdb_ptr;
  logic [AXI_ID_W-1:0] col_req_axi_id;
  logic col_req_grant;
  logic err_cmdq_overflow;
  logic err_wdb_overflow;
  logic err_ref_deadline_miss;

  // Display phase as ASCII in the waveform viewer.
  logic [8*8-1:0] phase;
  logic act_fire, wr_fire, rd_fire, read_done;
  logic [WDB_ADDR_W-1:0] write_ptr;
  logic [DATA_W-1:0] memory_word;
  logic act_seen, write_seen, read_seen, return_seen;
  int return_delay;
  string vcd_path;

  always #0.5 clk = ~clk;

  // Always accept commands and read completions; no artificial stalls.
  assign row_req_grant = rst_n && row_req_val;
  assign col_req_grant = rst_n && col_req_val;
  assign rdb_ready = rst_n;
  assign act_fire = row_req_grant && (row_req_cmd == ROW_CMD_ACT);
  assign wr_fire = col_req_grant && (col_req_cmd == COL_CMD_WR);
  assign rd_fire = col_req_grant && (col_req_cmd == COL_CMD_RD);
  assign read_done = rdb_valid && rdb_ready;
  assign wdb_raddr = col_req_wdb_ptr;
  assign wdb_pop_val = wr_fire;
  assign wdb_pop_ptr = col_req_wdb_ptr;

  mc_pc_core #(
    .DFI_PC_DATA_W (DATA_W),
    .DFI_PC_MASK_W (MASK_W)
  ) u_core (
    .clk                  (clk),
    .rst_n                (rst_n),
    .cmd_push_val         (cmd_push_val),
    .cmd_push_entry       (cmd_push_entry),
    .cmdq_full            (cmdq_full),
    .wdb_push_val         (wdb_push_val),
    .wdb_push_data        (wdb_push_data),
    .wdb_push_mask        (wdb_push_mask),
    .wdb_alloc_ptr        (wdb_alloc_ptr),
    .wdb_full             (wdb_full),
    .wdb_raddr            (wdb_raddr),
    .wdb_rdata            (wdb_rdata),
    .wdb_rmask            (wdb_rmask),
    .wdb_pop_val          (wdb_pop_val),
    .wdb_pop_ptr          (wdb_pop_ptr),
    .dfi_rddata_valid     (dfi_rddata_valid),
    .dfi_rddata           (dfi_rddata),
    .rdb_valid            (rdb_valid),
    .rdb_ready            (rdb_ready),
    .rdb_data             (rdb_data),
    .rdb_axi_id           (rdb_axi_id),
    .row_req_val          (row_req_val),
    .row_req_is_ref       (row_req_is_ref),
    .row_req_cmd          (row_req_cmd),
    .row_req_addr         (row_req_addr),
    .row_req_bg           (row_req_bg),
    .row_req_bank         (row_req_bank),
    .ch_arb_row_grant     (row_req_grant),
    .col_req_val          (col_req_val),
    .col_req_cmd          (col_req_cmd),
    .col_req_addr         (col_req_addr),
    .col_req_bg           (col_req_bg),
    .col_req_bank         (col_req_bank),
    .col_req_wdb_ptr      (col_req_wdb_ptr),
    .col_req_axi_id       (col_req_axi_id),
    .ch_arb_col_grant     (col_req_grant),
    .err_cmdq_overflow    (err_cmdq_overflow),
    .err_wdb_overflow     (err_wdb_overflow),
    .err_ref_deadline_miss(err_ref_deadline_miss)
  );

  // One-word memory model and basic end-to-end checks.
  always @(posedge clk) begin
    if (!rst_n) begin
      memory_word <= '0;
      act_seen <= 1'b0;
      write_seen <= 1'b0;
      read_seen <= 1'b0;
      return_seen <= 1'b0;
      return_delay <= 0;
      dfi_rddata_valid <= 1'b0;
      dfi_rddata <= '0;
    end else begin
      dfi_rddata_valid <= 1'b0;
      dfi_rddata <= '0;
      if (return_delay > 0) begin
        return_delay <= return_delay - 1;
        if (return_delay == 1) begin
          dfi_rddata_valid <= 1'b1;
          dfi_rddata <= memory_word;
        end
      end

      if (err_cmdq_overflow || err_wdb_overflow || err_ref_deadline_miss)
        $fatal(1, "Unexpected core error");

      if (row_req_grant) begin
        if (!act_fire || act_seen || row_req_is_ref ||
            row_req_addr !== TEST_ROW || row_req_bg !== '0 || row_req_bank !== '0)
          $fatal(1, "Expected one ACT for the test row in bank 0");
        act_seen <= 1'b1;
        $display("%0t ACT row=%h", $time, row_req_addr);
      end

      if (col_req_grant) begin
        if (!act_seen || col_req_bg !== '0 || col_req_bank !== '0 ||
            col_req_addr !== TEST_COL)
          $fatal(1, "Unexpected column address or bank");
        case (col_req_cmd)
          COL_CMD_WR: begin
            if (write_seen || col_req_axi_id !== WRITE_ID ||
                col_req_wdb_ptr !== write_ptr ||
                wdb_rdata !== TEST_DATA || wdb_rmask !== TEST_MASK)
              $fatal(1, "Write payload, mask, ID or WDB pointer mismatch");
            memory_word <= wdb_rdata;
            write_seen <= 1'b1;
            $display("%0t WR  col=%h data=%h", $time, col_req_addr, wdb_rdata);
          end
          COL_CMD_RD: begin
            if (!write_seen || read_seen || col_req_axi_id !== READ_ID)
              $fatal(1, "Unexpected read command");
            return_delay <= READ_LATENCY;
            read_seen <= 1'b1;
            $display("%0t RD  col=%h id=%h", $time, col_req_addr, col_req_axi_id);
          end
          default: $fatal(1, "Unexpected column command");
        endcase
      end

      if (read_done) begin
        if (!read_seen || return_seen || rdb_data !== TEST_DATA || rdb_axi_id !== READ_ID)
          $fatal(1, "Readback data or ID mismatch");
        return_seen <= 1'b1;
        $display("%0t RDB data=%h id=%h", $time, rdb_data, rdb_axi_id);
      end
    end
  end

  task automatic push_write_data;
    @(negedge clk);
    if (wdb_full) $fatal(1, "WDB is full");
    write_ptr = wdb_alloc_ptr;
    wdb_push_data = TEST_DATA;
    wdb_push_mask = TEST_MASK;
    wdb_push_val = 1'b1;
    @(negedge clk);
    wdb_push_val = 1'b0;
    wdb_push_data = '0;
    wdb_push_mask = '0;
  endtask

  task automatic push_command(input logic is_write);
    @(negedge clk);
    if (cmdq_full) $fatal(1, "CMDQ is full");
    cmd_push_entry = {is_write ? WRITE_ID : READ_ID, is_write,
                      TEST_ROW, 2'b00, 2'b00, TEST_COL,
                      is_write ? write_ptr : {WDB_ADDR_W{1'b0}}};
    cmd_push_val = 1'b1;
    @(negedge clk);
    cmd_push_val = 1'b0;
    cmd_push_entry = '0;
  endtask

  initial begin
    if (!$value$plusargs("vcd=%s", vcd_path)) vcd_path = "tb_mc_core.vcd";
    $dumpfile(vcd_path);
    // Keep the default waveform focused on the testbench interfaces.
    $dumpvars(1, tb_mc_core);
  end

  initial begin
    $timeformat(-9, 1, " ns", 0);
    clk = 1'b0;
    rst_n = 1'b0;
    phase = "RESET";
    cmd_push_val = 1'b0;
    cmd_push_entry = '0;
    wdb_push_val = 1'b0;
    wdb_push_data = '0;
    wdb_push_mask = '0;
    write_ptr = '0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    phase = "IDLE";
    repeat (4) @(negedge clk);

    phase = "WRITE";
    push_write_data();
    push_command(1'b1);
    wait (write_seen);
    @(negedge clk);
    if (u_core.wdb_data_rdy !== '0)
      $fatal(1, "Write did not release its WDB slot");

    phase = "IDLE";
    repeat (4) @(negedge clk);
    phase = "READ";
    push_command(1'b0);
    wait (return_seen);
    @(negedge clk);
    phase = "DONE";
    repeat (4) @(negedge clk);
    if (!act_seen || !write_seen || !read_seen || !return_seen ||
        u_core.slot_valid !== '0 || u_core.wdb_data_rdy !== '0 || rdb_valid)
      $fatal(1, "Incomplete transaction or undrained buffers");
    $display("PASS: one ACT, one WR, one RD and matching readback; waveform: %s", vcd_path);
    $finish;
  end

  initial begin
    repeat (200) @(negedge clk);
    $fatal(1, "Core waveform demo timed out");
  end
endmodule : tb_mc_core
