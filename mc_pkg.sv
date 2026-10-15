`timescale 1ns/1ps

package mc_pkg;

  // --------------------------------------------------------------------------
  // Sizing & Addressing Parameters (Section 13.2)
  // --------------------------------------------------------------------------
  localparam int AXI_DATA_W          = 256;
  localparam int AXI_ADDR_W          = 40;
  localparam int AXI_ID_W            = 8;
  localparam int CMDQ_DEPTH          = 32;
  localparam int CMDQ_ADDR_W         = $clog2(CMDQ_DEPTH); // 5
  localparam int WDB_DEPTH           = 16;
  localparam int WDB_ADDR_W          = $clog2(WDB_DEPTH);  // 4
  localparam int RDB_DEPTH           = 16;
  localparam int RDB_ADDR_W          = $clog2(RDB_DEPTH);  // 4
  localparam int CREDIT_CTR_WIDTH    = 8;                  // Saturates at 255

  // DFI PHY timing parameters
  localparam int T_PHY_WRLAT_MAX     = 15;  // Max programmable write latency (4-bit CSR)

  localparam int NUM_BANKGROUPS      = 4;
  localparam int NUM_BANKS_PER_GROUP = 4;
  localparam int TOTAL_BANKS         = NUM_BANKGROUPS * NUM_BANKS_PER_GROUP; // 16
  localparam int BANK_ADDR_W         = 2;
  localparam int BG_ADDR_W           = 2;
  localparam int ROW_ADDR_W          = 14;
  localparam int COL_ADDR_W          = 5;

  // --------------------------------------------------------------------------
  // HBM3 DRAM Timing Parameters @ 1 GHz (1 cycle = 1 ns) (Section 7.3.2)
  // --------------------------------------------------------------------------
  localparam logic [7:0]  T_RCD  = 8'd18;
  localparam logic [7:0]  T_RAS  = 8'd34;
  localparam logic [7:0]  T_RP   = 8'd14;
  localparam logic [7:0]  T_RC   = 8'd50;
  localparam logic [7:0]  T_RRD  = 8'd6;
  localparam logic [7:0]  T_FAW  = 8'd32;
  localparam logic [7:0]  T_CCD  = 8'd4;
  localparam logic [7:0]  T_WTR  = 8'd8;
  localparam logic [7:0]  T_WR   = 8'd18;
  localparam logic [7:0]  T_RTP  = 8'd8;
  localparam logic [12:0] T_REFI = 13'd3900;
  localparam logic [9:0]  T_RFC  = 10'd350;

  // --------------------------------------------------------------------------
  // DFI Command Encodings (Section 3.3.2a & Section 12)
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    ROW_CMD_NOP    = 3'b000,
    ROW_CMD_ACT    = 3'b001,
    ROW_CMD_PRE    = 3'b010,
    ROW_CMD_PREALL = 3'b011,
    ROW_CMD_REF    = 3'b100,
    ROW_CMD_MRW    = 3'b101
  } row_cmd_e;

  typedef enum logic [1:0] {
    COL_CMD_NOP = 2'b00,
    COL_CMD_RD  = 2'b01,
    COL_CMD_WR  = 2'b10
  } col_cmd_e;

  // Decoded transaction pushed to CMDQ
  typedef struct packed {
    logic [AXI_ID_W-1:0]       axi_id;
    logic                      is_write;
    logic [ROW_ADDR_W-1:0]     row;
    logic [BG_ADDR_W-1:0]      bankgroup;
    logic [BANK_ADDR_W-1:0]    bank;
    logic [COL_ADDR_W-1:0]     col;
    logic [WDB_ADDR_W-1:0]     wdb_ptr;
  } cmd_entry_t;

endpackage: mc_pkg
