`timescale 1ns/1ps

// =============================================================================
// Package: mc_pkg
// Description: Global parameters, data structures, and command encodings for
//              the MC16X2 HBM3 Memory Controller IP (Phase 1 / mc_pc_core).
// =============================================================================
package mc_pkg;

  // ---------------------------------------------------------------------------
  // Sizing & Addressing Parameters (Section 13.2)
  // ---------------------------------------------------------------------------
  parameter int AXI_DATA_W          = 256;
  parameter int AXI_ADDR_W          = 40;
  parameter int AXI_ID_W            = 8;
  parameter int NUM_CH              = 16;
  parameter int NUM_PC_PER_CH       = 2;

  parameter int CMDQ_DEPTH          = 32;
  parameter int CMDQ_ADDR_W         = 5;                   // $clog2(CMDQ_DEPTH)
  parameter int WDB_DEPTH           = 16;
  parameter int WDB_ADDR_W          = 4;                   // $clog2(WDB_DEPTH)
  parameter int RDB_DEPTH           = 16;
  parameter int RDB_ADDR_W          = 4;                   // $clog2(RDB_DEPTH)
  parameter int CREDIT_CTR_WIDTH    = 8;                   // Wait counter saturates at 255

  parameter int NUM_BANKGROUPS      = 4;
  parameter int NUM_BANKS_PER_GROUP = 4;
  parameter int TOTAL_BANKS         = NUM_BANKGROUPS * NUM_BANKS_PER_GROUP; // 16 banks
  parameter int BG_ADDR_W           = 2;
  parameter int BANK_ADDR_W         = 2;
  parameter int ROW_ADDR_W          = 14;
  parameter int COL_ADDR_W          = 5;

  // ---------------------------------------------------------------------------
  // HBM3 DRAM Timing Parameters in dfi_clk cycles @ 1 GHz (Section 7.3.2)
  // ---------------------------------------------------------------------------
  parameter logic [7:0]  T_RCD  = 8'd18;   // ACT to RD/WR delay (18 cycles)
  parameter logic [7:0]  T_RAS  = 8'd34;   // ACT to PRE minimum open time
  parameter logic [7:0]  T_RP   = 8'd14;   // PRE to next ACT delay
  parameter logic [7:0]  T_RC   = 8'd50;   // ACT to next ACT (same bank)
  parameter logic [7:0]  T_RRD  = 8'd6;    // ACT to ACT (different banks)
  parameter logic [7:0]  T_FAW  = 8'd32;   // 4-Activation sliding window
  parameter logic [7:0]  T_CCD  = 8'd4;    // RD/WR to RD/WR column spacing
  parameter logic [7:0]  T_WTR  = 8'd8;    // WR to RD turnaround delay
  parameter logic [7:0]  T_WR   = 8'd18;   // WR data to PRE delay
  parameter logic [7:0]  T_RTP  = 8'd8;    // RD to PRE delay
  parameter logic [12:0] T_REFI = 13'd3900;// Refresh interval (3.9 us)
  parameter logic [9:0]  T_RFC  = 10'd350; // Refresh cycle lock duration

  // ---------------------------------------------------------------------------
  // DFI Row Command Encodings (Section 3.3.2a)
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    ROW_CMD_NOP    = 3'b000,
    ROW_CMD_ACT    = 3'b001,
    ROW_CMD_PRE    = 3'b010,
    ROW_CMD_PREALL = 3'b011,
    ROW_CMD_REF    = 3'b100,
    ROW_CMD_MRW    = 3'b101
  } row_cmd_e;

  // ---------------------------------------------------------------------------
  // DFI Column Command Encodings (Section 3.3.2a)
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    COL_CMD_NOP = 2'b00,
    COL_CMD_RD  = 2'b01,
    COL_CMD_WR  = 2'b10,
    COL_CMD_RDA = 2'b11
  } col_cmd_e;

  // ---------------------------------------------------------------------------
  // Command Queue (CMDQ) Entry Structure
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic [AXI_ID_W-1:0]    axi_id;
    logic                   is_write;
    logic [ROW_ADDR_W-1:0]  row;
    logic [BG_ADDR_W-1:0]   bankgroup;
    logic [BANK_ADDR_W-1:0] bank;
    logic [COL_ADDR_W-1:0]  col;
    logic [WDB_ADDR_W-1:0]  wdb_ptr;
  } cmd_entry_t;

endpackage : mc_pkg
