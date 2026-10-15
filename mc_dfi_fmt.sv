`timescale 1ns/1ps
module mc_dfi_fmt
  import mc_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,

  // Scheduler outputs (from mc_pc_core) — 2 PCs per channel
  input  logic [1:0]                row_req_val,
  input  row_cmd_e                  row_req_cmd [2],
  input  logic [ROW_ADDR_W-1:0]     row_req_addr [2],
  input  logic [BG_ADDR_W-1:0]      row_req_bg [2],
  input  logic [BANK_ADDR_W-1:0]    row_req_bank [2],

  input  logic [1:0]                col_req_val,
  input  col_cmd_e                  col_req_cmd [2],
  input  logic [COL_ADDR_W-1:0]     col_req_addr [2],
  input  logic [BG_ADDR_W-1:0]      col_req_bg [2],
  input  logic [BANK_ADDR_W-1:0]    col_req_bank [2],
  input  logic [WDB_ADDR_W-1:0]     col_req_wdb_ptr [2],
  input  logic [AXI_ID_W-1:0]       col_req_axi_id [2],

  // Per-PC WDB read ports (64-bit each)
  input  logic [63:0]               wdb_rdata_ch0,
  input  logic [63:0]               wdb_rdata_ch1,
  output logic [WDB_ADDR_W-1:0]     wdb_raddr_ch0,
  output logic [WDB_ADDR_W-1:0]     wdb_raddr_ch1,

  // CSR-programmed write latency
  input  logic [3:0]                csr_tphy_wrlat,

  // DFI Output Buses (per channel)
  output logic [21:0]               dfi_row_ch0,
  output logic [21:0]               dfi_row_ch1,
  output logic [11:0]               dfi_col_ch0,
  output logic [11:0]               dfi_col_ch1,
  output logic [63:0]               dfi_wrdata_ch0,
  output logic [63:0]               dfi_wrdata_ch1,
  output logic [1:0]                dfi_wrdata_en_ch0,  // [0]=PC0, [1]=PC1
  output logic [1:0]                dfi_wrdata_en_ch1
);

  // --------------------------------------------------------------------------
  // PC Select Logic (Combinational)
  // HBM3 mapping: PC0 gets BG=0,2 (bg[0]=0), PC1 gets BG=1,3 (bg[0]=1)
  // --------------------------------------------------------------------------
  logic [1:0] row_pc_sel;
  logic [1:0] col_pc_sel;

  assign row_pc_sel[0] = row_req_bg[0][0];
  assign row_pc_sel[1] = row_req_bg[1][0];
  assign col_pc_sel[0] = col_req_bg[0][0];
  assign col_pc_sel[1] = col_req_bg[1][0];

  // --------------------------------------------------------------------------
  // Row Bus Packer (Combinational)
  // 22-bit format: [21]=pc_sel, [20:7]=row_addr(14), [6:5]=bank(2), [4:3]=bg(2), [2:0]=cmd(3)
  // --------------------------------------------------------------------------
  function automatic logic [21:0] pack_row_bus(
    input logic        valid,
    input row_cmd_e    cmd,
    input logic [13:0] addr,
    input logic [1:0]  bg,
    input logic [1:0]  bank,
    input logic        pc_sel
  );
    logic [21:0] bus;
    bus[2:0]   = valid ? cmd : ROW_CMD_NOP;
    bus[4:3]   = bg;
    bus[6:5]   = bank;
    bus[20:7]  = addr;
    bus[21]    = pc_sel;
    return bus;
  endfunction

  logic [21:0] row_bus_next [2];
  always_comb begin
    for (int pc = 0; pc < 2; pc++) begin
      row_bus_next[pc] = pack_row_bus(
        row_req_val[pc],
        row_req_cmd[pc],
        row_req_addr[pc],
        row_req_bg[pc],
        row_req_bank[pc],
        row_pc_sel[pc]
      );
    end
  end

  // --------------------------------------------------------------------------
  // Column Bus Packer (Combinational)
  // 12-bit format: [11]=pc_sel, [10:6]=col_addr(5), [5:4]=bank(2), [3:2]=bg(2), [1:0]=cmd(2)
  // --------------------------------------------------------------------------
  function automatic logic [11:0] pack_col_bus(
    input logic       valid,
    input col_cmd_e   cmd,
    input logic [4:0] addr,
    input logic [1:0] bg,
    input logic [1:0] bank,
    input logic       pc_sel
  );
    logic [11:0] bus;
    bus[1:0]   = valid ? cmd : COL_CMD_NOP;
    bus[3:2]   = bg;
    bus[5:4]   = bank;
    bus[10:6]  = addr;
    bus[11]    = pc_sel;
    return bus;
  endfunction

  logic [11:0] col_bus_next [2];
  always_comb begin
    for (int pc = 0; pc < 2; pc++) begin
      col_bus_next[pc] = pack_col_bus(
        col_req_val[pc],
        col_req_cmd[pc],
        col_req_addr[pc],
        col_req_bg[pc],
        col_req_bank[pc],
        col_pc_sel[pc]
      );
    end
  end

  // --------------------------------------------------------------------------
  // Registered DFI Outputs (1-cycle latency for 1 GHz timing closure)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dfi_row_ch0 <= '0;
      dfi_row_ch1 <= '0;
      dfi_col_ch0 <= '0;
      dfi_col_ch1 <= '0;
    end else begin
      dfi_row_ch0 <= row_bus_next[0];
      dfi_row_ch1 <= row_bus_next[1];
      dfi_col_ch0 <= col_bus_next[0];
      dfi_col_ch1 <= col_bus_next[1];
    end
  end

  // --------------------------------------------------------------------------
  // WDB Read Address Generation
  // Drive read address when WR command issues for that PC
  // --------------------------------------------------------------------------
  assign wdb_raddr_ch0 = (col_req_val[0] && (col_req_cmd[0] == COL_CMD_WR)) ? col_req_wdb_ptr[0] : '0;
  assign wdb_raddr_ch1 = (col_req_val[1] && (col_req_cmd[1] == COL_CMD_WR)) ? col_req_wdb_ptr[1] : '0;

  // --------------------------------------------------------------------------
  // Write Data Enable Shift Registers (per channel, per PC)
  // Tracks tphy_wrlat cycles after WR column command
  // Max latency 15 cycles (4-bit CSR), implement as 16-deep shift register
  // --------------------------------------------------------------------------
  logic [1:0] wr_en_shift_ch0 [0:15];
  logic [1:0] wr_en_shift_ch1 [0:15];

  // WR command detection per PC
  logic [1:0] wr_cmd_ch0;
  logic [1:0] wr_cmd_ch1;

  always_comb begin
    wr_cmd_ch0 = '0;
    wr_cmd_ch1 = '0;
    // PC0 commands targeting PC0 (col_pc_sel[pc] == 0)
    if (col_req_val[0] && (col_req_cmd[0] == COL_CMD_WR) && (col_pc_sel[0] == 1'b0)) wr_cmd_ch0[0] = 1'b1;
    if (col_req_val[1] && (col_req_cmd[1] == COL_CMD_WR) && (col_pc_sel[1] == 1'b0)) wr_cmd_ch0[1] = 1'b1;
    // PC1 commands targeting PC1 (col_pc_sel[pc] == 1)
    if (col_req_val[0] && (col_req_cmd[0] == COL_CMD_WR) && (col_pc_sel[0] == 1'b1)) wr_cmd_ch1[0] = 1'b1;
    if (col_req_val[1] && (col_req_cmd[1] == COL_CMD_WR) && (col_pc_sel[1] == 1'b1)) wr_cmd_ch1[1] = 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 16; i++) begin
        wr_en_shift_ch0[i] <= '0;
        wr_en_shift_ch1[i] <= '0;
      end
    end else begin
      // Shift registers
      for (int i = 15; i > 0; i--) begin
        wr_en_shift_ch0[i] <= wr_en_shift_ch0[i-1];
        wr_en_shift_ch1[i] <= wr_en_shift_ch1[i-1];
      end
      // Inject new WR commands at position 0
      wr_en_shift_ch0[0] <= wr_cmd_ch0;
      wr_en_shift_ch1[0] <= wr_cmd_ch1;
    end
  end

  // Output enable = tap at csr_tphy_wrlat
  assign dfi_wrdata_en_ch0 = wr_en_shift_ch0[csr_tphy_wrlat];
  assign dfi_wrdata_en_ch1 = wr_en_shift_ch1[csr_tphy_wrlat];

  // --------------------------------------------------------------------------
  // Write Data Mux (Combinational)
  // 64-bit per PC from its local WDB
  // --------------------------------------------------------------------------
  assign dfi_wrdata_ch0 = wdb_rdata_ch0;
  assign dfi_wrdata_ch1 = wdb_rdata_ch1;

endmodule
