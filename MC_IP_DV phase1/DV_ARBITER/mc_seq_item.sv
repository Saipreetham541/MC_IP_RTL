`timescale 1ns/1ps

// =============================================================================
// Class: mc_seq_item
// Description: UVM Sequence Item for Credit-Counter Arbiter verification.
//              Holds stimulus (req_valid, req_legal, grant_ack) and observed
//              responses (grant, grant_idx, grant_valid, wait_ctr).
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_seq_item extends uvm_sequence_item;
  `uvm_object_utils(mc_seq_item)

  // ---------------------------------------------------------------------------
  // Stimulus Fields driven by Sequences
  // ---------------------------------------------------------------------------
  rand bit [NUM_REQ-1:0]   req_valid;    // Slot occupied mask
  rand bit [NUM_REQ-1:0]   req_legal;    // Slot timing-legal mask
  rand bit                 grant_ack;    // Downstream grant acknowledge (issue)

  // ---------------------------------------------------------------------------
  // Observed Response Fields sampled from DUT
  // ---------------------------------------------------------------------------
  bit [NUM_REQ-1:0]        grant_observed;
  bit [IDX_W-1:0]          grant_idx_observed;
  bit                      grant_valid_observed;
  bit [NUM_REQ-1:0][CREDIT_CTR_WIDTH-1:0] wait_ctr_observed;

  function new(string name = "mc_seq_item");
    super.new(name);
    req_valid = '0;
    req_legal = '0;
    grant_ack = 1'b0;
  endfunction

  virtual function string convert2string();
    return $sformatf("req_valid=0x%08h req_legal=0x%08h ack=%0b | grant_valid=%0b grant_idx=%0d",
      req_valid, req_legal, grant_ack, grant_valid_observed, grant_idx_observed);
  endfunction

endclass : mc_seq_item
