`timescale 1ns/1ps

interface mc_if (input logic clk, input logic rst_n);
  import mc_pkg::*;

  logic                     push_val;
  cmd_entry_t               push_entry;
  logic                     cmdq_full;
  logic                     cmdq_overflow;
  logic                     pop_val;
  logic [CMDQ_ADDR_W-1:0]   pop_idx;
  logic [CMDQ_DEPTH-1:0]    slot_valid;
  cmd_entry_t               slot_data [CMDQ_DEPTH-1:0];

  // Driver clocking block
  clocking drv_cb @(posedge clk);
    default input #1step output #100ps;
    output push_val, push_entry, pop_val, pop_idx;
    input  cmdq_full, cmdq_overflow, slot_valid;
  endclocking
  modport DRV (clocking drv_cb, input clk, input rst_n);

  // Monitor clocking block
  clocking mon_cb @(posedge clk);
    default input #1step output #100ps;
    input  push_val, push_entry, cmdq_full, cmdq_overflow, pop_val, pop_idx, slot_valid;
  endclocking
  modport MON (clocking mon_cb, input clk, input rst_n, input slot_data);

endinterface : mc_if
