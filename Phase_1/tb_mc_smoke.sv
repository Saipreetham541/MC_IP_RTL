`timescale 1ns/1ps

module tb_mc_smoke;
  import mc_pkg::*;

  localparam int DATA_W = 32;
  localparam int MASK_W = DATA_W / 8;

  logic clk;
  logic rst_n;

  logic       cmd_push_val;
  cmd_entry_t cmd_push_entry;
  logic       cmdq_full;

  logic                    wdb_push_val;
  logic [DATA_W-1:0]       wdb_push_data;
  logic [MASK_W-1:0]       wdb_push_mask;
  logic [WDB_ADDR_W-1:0]   wdb_alloc_ptr;
  logic                    wdb_full;
  logic [WDB_ADDR_W-1:0]   wdb_raddr;
  logic [DATA_W-1:0]       wdb_rdata;
  logic [MASK_W-1:0]       wdb_rmask;
  logic                    wdb_pop_val;
  logic [WDB_ADDR_W-1:0]   wdb_pop_ptr;

  logic                    dfi_rddata_valid;
  logic [DATA_W-1:0]       dfi_rddata;
  logic                    rdb_valid;
  logic [DATA_W-1:0]       rdb_data;
  logic [AXI_ID_W-1:0]     rdb_axi_id;

  logic                    row_req_val_0;
  logic                    row_req_is_ref_0;
  row_cmd_e                row_req_cmd_0;
  logic [ROW_ADDR_W-1:0]   row_req_addr_0;
  logic [BG_ADDR_W-1:0]    row_req_bg_0;
  logic [BANK_ADDR_W-1:0]  row_req_bank_0;
  logic                    col_req_val_0;
  col_cmd_e                col_req_cmd_0;
  logic [COL_ADDR_W-1:0]   col_req_addr_0;
  logic [BG_ADDR_W-1:0]    col_req_bg_0;
  logic [BANK_ADDR_W-1:0]  col_req_bank_0;
  logic [WDB_ADDR_W-1:0]   col_req_wdb_ptr_0;
  logic [AXI_ID_W-1:0]     col_req_axi_id_0;

  logic [DFI_NUM_PORTS-1:0] row_req_val;
  logic [DFI_NUM_PORTS-1:0] row_req_grant;
  row_cmd_e                 row_req_cmd [DFI_NUM_PORTS];
  logic [ROW_ADDR_W-1:0]    row_req_addr [DFI_NUM_PORTS];
  logic [BG_ADDR_W-1:0]     row_req_bg [DFI_NUM_PORTS];
  logic [BANK_ADDR_W-1:0]   row_req_bank [DFI_NUM_PORTS];

  logic [DFI_NUM_PORTS-1:0] col_req_val;
  logic [DFI_NUM_PORTS-1:0] col_req_grant;
  col_cmd_e                 col_req_cmd [DFI_NUM_PORTS];
  logic [COL_ADDR_W-1:0]    col_req_addr [DFI_NUM_PORTS];
  logic [BG_ADDR_W-1:0]     col_req_bg [DFI_NUM_PORTS];
  logic [BANK_ADDR_W-1:0]   col_req_bank [DFI_NUM_PORTS];
  logic [WDB_ADDR_W-1:0]    col_req_wdb_ptr [DFI_NUM_PORTS];

  logic [DFI_ROW_W-1:0] dfi_row_ch0;
  logic [DFI_ROW_W-1:0] dfi_row_ch1;
  logic [DFI_COL_W-1:0] dfi_col_ch0;
  logic [DFI_COL_W-1:0] dfi_col_ch1;
  logic [DATA_W-1:0] dfi_wrdata_ch0;
  logic [DATA_W-1:0] dfi_wrdata_ch1;
  logic [MASK_W-1:0] dfi_wrmask_ch0;
  logic [MASK_W-1:0] dfi_wrmask_ch1;
  logic [DFI_NUM_PORTS-1:0] dfi_wrdata_en_ch0;
  logic [DFI_NUM_PORTS-1:0] dfi_wrdata_en_ch1;
  logic [WDB_ADDR_W-1:0] wdb_raddr_unused;

  logic err_cmdq_overflow;
  logic err_wdb_overflow;
  logic err_ref_deadline_miss;
  logic [WDB_ADDR_W-1:0] write_ptr;
  logic [3:0] rd_return_pipe;

  always #0.5 clk <= ~clk;

  assign row_req_val       = {1'b0, row_req_val_0};
  assign row_req_grant     = row_req_val;
  assign row_req_cmd[0]    = row_req_cmd_0;
  assign row_req_cmd[1]    = ROW_CMD_NOP;
  assign row_req_addr[0]   = row_req_addr_0;
  assign row_req_addr[1]   = '0;
  assign row_req_bg[0]     = row_req_bg_0;
  assign row_req_bg[1]     = '0;
  assign row_req_bank[0]   = row_req_bank_0;
  assign row_req_bank[1]   = '0;

  assign col_req_val       = {1'b0, col_req_val_0};
  assign col_req_grant     = col_req_val;
  assign col_req_cmd[0]    = col_req_cmd_0;
  assign col_req_cmd[1]    = COL_CMD_NOP;
  assign col_req_addr[0]   = col_req_addr_0;
  assign col_req_addr[1]   = '0;
  assign col_req_bg[0]     = col_req_bg_0;
  assign col_req_bg[1]     = '0;
  assign col_req_bank[0]   = col_req_bank_0;
  assign col_req_bank[1]   = '0;
  assign col_req_wdb_ptr[0] = col_req_wdb_ptr_0;
  assign col_req_wdb_ptr[1] = '0;

  assign wdb_pop_val = |dfi_wrdata_en_ch0;
  assign wdb_pop_ptr = write_ptr;

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
    .rdb_ready            (1'b1),
    .rdb_data             (rdb_data),
    .rdb_axi_id           (rdb_axi_id),
    .row_req_val          (row_req_val_0),
    .row_req_is_ref       (row_req_is_ref_0),
    .row_req_cmd          (row_req_cmd_0),
    .row_req_addr         (row_req_addr_0),
    .row_req_bg           (row_req_bg_0),
    .row_req_bank         (row_req_bank_0),
    .ch_arb_row_grant     (row_req_grant[0]),
    .col_req_val          (col_req_val_0),
    .col_req_cmd          (col_req_cmd_0),
    .col_req_addr         (col_req_addr_0),
    .col_req_bg           (col_req_bg_0),
    .col_req_bank         (col_req_bank_0),
    .col_req_wdb_ptr      (col_req_wdb_ptr_0),
    .col_req_axi_id       (col_req_axi_id_0),
    .ch_arb_col_grant     (col_req_grant[0]),
    .err_cmdq_overflow    (err_cmdq_overflow),
    .err_wdb_overflow     (err_wdb_overflow),
    .err_ref_deadline_miss(err_ref_deadline_miss)
  );

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rd_return_pipe  <= '0;
      dfi_rddata_valid <= 1'b0;
      dfi_rddata       <= '0;
    end else begin
      rd_return_pipe   <= {rd_return_pipe[2:0],
                           col_req_val_0 && col_req_grant[0] &&
                           (col_req_cmd_0 == COL_CMD_RD)};
      dfi_rddata_valid <= rd_return_pipe[3];
      dfi_rddata       <= 32'hCAFE_1234;
    end
  end

  always @(posedge clk) begin
    if (rst_n && row_req_val_0 && row_req_grant[0]) begin
      $display("%0t row candidate=%0d bg=%0d bank=%0d row=%0h refresh_service=%0b",
               $time, row_req_cmd_0, row_req_bg_0, row_req_bank_0,
               row_req_addr_0, row_req_is_ref_0);
    end
    if (rst_n && col_req_val_0 && col_req_grant[0]) begin
      $display("%0t column candidate=%0d bg=%0d bank=%0d col=%0h id=%0h",
               $time, col_req_cmd_0, col_req_bg_0, col_req_bank_0,
               col_req_addr_0, col_req_axi_id_0);
    end
    if (rst_n && (|dfi_wrdata_en_ch0)) begin
      $display("%0t DFI write data=%0h mask=%0h enable=%0b",
               $time, dfi_wrdata_ch0, dfi_wrmask_ch0, dfi_wrdata_en_ch0);
    end
    if (rst_n && rdb_valid) begin
      $display("%0t read completion id=%0h data=%0h",
               $time, rdb_axi_id, rdb_data);
    end
  end

  always @(negedge clk) begin
    if (rst_n && ((dfi_row_ch0[2:0] != ROW_CMD_NOP) ||
                  (dfi_row_ch1[2:0] != ROW_CMD_NOP))) begin
      $display("%0t registered DFI row buses=%0h/%0h",
               $time, dfi_row_ch0, dfi_row_ch1);
    end
    if (rst_n && ((dfi_col_ch0[1:0] != COL_CMD_NOP) ||
                  (dfi_col_ch1[1:0] != COL_CMD_NOP))) begin
      $display("%0t registered DFI column buses=%0h/%0h",
               $time, dfi_col_ch0, dfi_col_ch1);
    end
  end

  task automatic push_command(
    input logic                  is_write,
    input logic [AXI_ID_W-1:0]   axi_id,
    input logic [ROW_ADDR_W-1:0] row,
    input logic [COL_ADDR_W-1:0] col,
    input logic [WDB_ADDR_W-1:0] wdb_ptr
  );
    @(negedge clk);
    cmd_push_entry.axi_id    = axi_id;
    cmd_push_entry.is_write  = is_write;
    cmd_push_entry.row       = row;
    cmd_push_entry.bankgroup = '0;
    cmd_push_entry.bank      = '0;
    cmd_push_entry.col       = col;
    cmd_push_entry.wdb_ptr   = wdb_ptr;
    cmd_push_val             = 1'b1;
    @(negedge clk);
    cmd_push_val             = 1'b0;
  endtask

  initial begin
    clk            = 1'b0;
    rst_n          = 1'b0;
    cmd_push_val   = 1'b0;
    cmd_push_entry = '0;
    wdb_push_val   = 1'b0;
    wdb_push_data  = '0;
    wdb_push_mask  = '0;
    write_ptr      = '0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    write_ptr     = wdb_alloc_ptr;
    wdb_push_data = 32'h1234_ABCD;
    wdb_push_mask = 4'b1111;
    wdb_push_val  = 1'b1;
    @(negedge clk);
    wdb_push_val  = 1'b0;

    push_command(1'b1, 8'h11, 14'h0123, 5'h04, write_ptr);
    repeat (48) @(negedge clk);
    push_command(1'b0, 8'h22, 14'h0123, 5'h08, '0);

    repeat (int'(T_REFI) + int'(T_RFC) + 100) @(negedge clk);
    $display("%0t smoke simulation complete full=%0b/%0b errors=%0b/%0b/%0b ch1=%0h/%0h/%0b unused_addr=%0h",
             $time, cmdq_full, wdb_full, err_cmdq_overflow, err_wdb_overflow,
             err_ref_deadline_miss, dfi_wrdata_ch1, dfi_wrmask_ch1,
             dfi_wrdata_en_ch1, wdb_raddr_unused);
    $finish;
  end

endmodule : tb_mc_smoke
