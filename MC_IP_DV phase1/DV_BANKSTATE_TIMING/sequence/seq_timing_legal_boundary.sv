`timescale 1ns/1ps

// =============================================================================
// Sequence: seq_timing_legal_boundary
// Feature : Feature 3 - Bank State and Timing Legality Verification
// Test    : t_p1_timing_legal_boundary
// Priority: P0 (Directed)
// Goal    : Enqueue a Read command to Bank 0 to verify command release at the
//           exact cycle boundary when cnt_rcd transitions from 1 -> 0.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class seq_timing_legal_boundary extends uvm_sequence #(mc_seq_item);
  `uvm_object_utils(seq_timing_legal_boundary)

  function new(string name = "seq_timing_legal_boundary");
    super.new(name);
  endfunction

  // Helper task: Enqueue a command entry into CMDQ
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
    `uvm_info("SEQ_F3", "Enqueuing Read command to Bank 0, Row 0x0DEF (col 0x08) for exact boundary measurement...", UVM_LOW)
    push_cmd(.is_wr(1'b0), .axi_id(8'h52), .bg(2'b00), .bank(2'b00), .row(14'h0DEF), .col(5'h08), .delay(0));
  endtask

endclass : seq_timing_legal_boundary
