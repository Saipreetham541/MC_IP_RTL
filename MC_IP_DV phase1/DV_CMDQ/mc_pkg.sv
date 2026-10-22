`timescale 1ns/1ps

package mc_pkg;
  parameter int CMDQ_DEPTH   = 32;
  parameter int CMDQ_ADDR_W  = 5; // $clog2(32)
  parameter int ROW_ADDR_W   = 14;
  parameter int COL_ADDR_W   = 5;
  parameter int BG_ADDR_W    = 2;
  parameter int BANK_ADDR_W  = 2;
  parameter int WDB_ADDR_W   = 4;
  parameter int AXI_ID_W     = 8;

  // Exact match to RTL's cmd_entry_t
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
