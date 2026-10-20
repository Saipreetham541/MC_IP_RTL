`timescale 1ns/1ps

package mc_pkg;

  // System geometry and interface widths. Central definitions keep queue,
  // scheduler, and formatter indexing consistent.
  localparam int AXI_DATA_W          = 256;
  localparam int AXI_ADDR_W          = 40;
  localparam int AXI_ID_W            = 8;
  localparam int NUM_CH              = 16;
  localparam int NUM_PC_PER_CH       = 2;

  localparam int CMDQ_DEPTH          = 32;
  localparam int CMDQ_ADDR_W         = $clog2(CMDQ_DEPTH); // 5 bits
  localparam int WDB_DEPTH           = 16;
  localparam int WDB_ADDR_W          = $clog2(WDB_DEPTH);  // 4 bits
  localparam int RDB_DEPTH           = 16;
  localparam int RDB_ADDR_W          = $clog2(RDB_DEPTH);  // 4 bits
  localparam int CREDIT_CTR_WIDTH    = 8;                  // Saturates at 255

  localparam int NUM_BANKGROUPS      = 4;
  localparam int NUM_BANKS_PER_GROUP = 4;
  localparam int TOTAL_BANKS         = NUM_BANKGROUPS * NUM_BANKS_PER_GROUP; // 16 banks
  localparam int BG_ADDR_W           = 2;
  localparam int BANK_ADDR_W         = 2;
  localparam int BANK_IDX_W          = BG_ADDR_W + BANK_ADDR_W;
  localparam int ROW_ADDR_W          = 14;
  localparam int COL_ADDR_W          = 5;

  localparam int DFI_NUM_PORTS       = NUM_PC_PER_CH;
  localparam int DFI_ROW_W           = 1 + ROW_ADDR_W + BANK_ADDR_W + BG_ADDR_W + 3;
  localparam int DFI_COL_W           = 1 + COL_ADDR_W + BANK_ADDR_W + BG_ADDR_W + 2;
  localparam int WRLAT_W             = 4;
  localparam int WRLAT_DEPTH         = 1 << WRLAT_W;

  // HBM3 timing values expressed in dfi_clk cycles at 1 GHz. Timing counters
  // load these constants when the corresponding command is actually issued.
  localparam logic [7:0]  T_RCD  = 8'd18;   // ACT to RD/WR delay
  localparam logic [7:0]  T_RAS  = 8'd34;   // ACT to PRE minimum open time
  localparam logic [7:0]  T_RP   = 8'd14;   // PRE to next ACT delay
  localparam logic [7:0]  T_RC   = 8'd50;   // ACT to next ACT (same bank)
  localparam logic [7:0]  T_RRD  = 8'd6;    // ACT to ACT (different banks)
  localparam logic [7:0]  T_FAW  = 8'd32;   // 4-Activation sliding window
  localparam logic [7:0]  T_CCD  = 8'd4;    // RD/WR to RD/WR column spacing
  localparam logic [7:0]  T_WTR  = 8'd8;    // WR to RD turnaround delay
  localparam logic [7:0]  T_WR   = 8'd18;   // WR data to PRE delay
  localparam logic [7:0]  T_RTP  = 8'd8;    // RD to PRE delay
  localparam logic [12:0] T_REFI = 13'd3900;// Refresh interval (3.9 us)
  localparam logic [9:0]  T_RFC  = 10'd350; // Refresh cycle lock duration

  // Typed DFI encodings prevent row and column command values being mixed.
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
    COL_CMD_WR  = 2'b10,
    COL_CMD_RDA = 2'b11 // Read/Write with auto-precharge (if used)
  } col_cmd_e;

  // One decoded transaction. wdb_ptr is meaningful for writes; axi_id is kept
  // for reads so returning PHY data can be associated with its AXI transaction.
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
