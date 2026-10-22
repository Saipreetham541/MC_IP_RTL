`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_timing_bank_independence
// Feature : Feature 3 - Bank State and Timing Legality Verification
// Test    : t_p1_timing_bank_independence
// Priority: P1 (Directed)
// Goal    : Enqueue commands targeting independent banks (Bank 0 and Bank 1)
//           to verify Bank 1 can proceed while Bank 0 is blocked on tRCD.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

// Helper sequence to push a single targeted command through sequencer
class seq_push_single_cmd extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_push_single_cmd)

  bit        is_wr;
  bit [7:0]  axi_id;
  bit [1:0]  bg;
  bit [1:0]  bank;
  bit [13:0] row;
  bit [4:0]  col;

  function new(string name = "seq_push_single_cmd");
    super.new(name);
  endfunction

  virtual task body();
    mc_seq_item req;
    req = mc_seq_item::type_id::create("req");
    start_item(req);
    req.kind            = MC_ITEM_PUSH;
    req.entry.axi_id    = axi_id;
    req.entry.is_write  = is_wr;
    req.entry.bankgroup = bg;
    req.entry.bank      = bank;
    req.entry.row       = row;
    req.entry.col       = col;
    req.entry.wdb_ptr   = 4'h0;
    req.delay_cycles    = 0;
    finish_item(req);
  endtask
endclass : seq_push_single_cmd

// Main sequence for bank independence
class seq_timing_bank_independence extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_timing_bank_independence)

  function new(string name = "seq_timing_bank_independence");
    super.new(name);
  endfunction

  task push_cmd(bit is_wr, bit [7:0] axi_id, bit [1:0] bg, bit [1:0] bank,
                bit [13:0] row, bit [4:0] col, int delay = 0);
    mc_seq_item req;
    req = mc_seq_item::type_id::create("req");
    start_item(req);
    req.kind            = MC_ITEM_PUSH;
    req.entry.axi_id    = axi_id;
    req.entry.is_write  = is_wr;
    req.entry.bankgroup = bg;
    req.entry.bank      = bank;
    req.entry.row       = row;
    req.entry.col       = col;
    req.entry.wdb_ptr   = 4'h0;
    req.delay_cycles    = delay;
    finish_item(req);
  endtask

  virtual task body();
    `uvm_info("SEQ_F3", "Enqueuing commands for Bank 0 and Bank 1 independent parallelism check...", UVM_LOW)
    // Command 0: targeting Bank 0, Row 0x111
    push_cmd(.is_wr(1'b0), .axi_id(8'h61), .bg(2'b00), .bank(2'b00), .row(14'h111), .col(5'h00), .delay(0));
    // Command 1: targeting Bank 1, Row 0x222
    push_cmd(.is_wr(1'b0), .axi_id(8'h62), .bg(2'b00), .bank(2'b01), .row(14'h222), .col(5'h01), .delay(0));
  endtask

endclass : seq_timing_bank_independence
