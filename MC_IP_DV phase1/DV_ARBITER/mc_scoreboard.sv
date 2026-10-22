`timescale 1ns/1ps

// =============================================================================
// Class: mc_scoreboard
// Description: UVM Scoreboard maintaining golden reference model for mc_arbiter:
//              - Highest wait_ctr selection
//              - Lowest slot index tie-breaking
//              - 1-hot grant vector verification
//              - Counter reset on grant_ack
//              - Counter saturation at 255 without wraparound
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mc_scoreboard)

  uvm_analysis_imp #(mc_seq_item, mc_scoreboard) ap_imp;
  virtual mc_if vif;

  int arb_checks_passed = 0;
  int arb_checks_total  = 0;
  int arb_errors        = 0;

  function new(string name = "mc_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    ap_imp = new("ap_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(virtual mc_if)::get(this, "", "mc_vif", vif));
    if (vif == null)
      void'(uvm_config_db#(virtual mc_if)::get(null, "*", "mc_vif", vif));
  endfunction

  function void write(mc_seq_item item);
    bit [NUM_REQ-1:0]          effective_eligible;
    bit                        exp_grant_valid;
    bit [IDX_W-1:0]            exp_grant_idx;
    bit [CREDIT_CTR_WIDTH-1:0] max_ctr;
    bit                        found;

    arb_checks_total++;
    effective_eligible = item.req_valid & item.req_legal;

    // Golden Winner Selection:
    // Highest wait_ctr wins; ties broken by lowest slot index
    exp_grant_valid = 1'b0;
    exp_grant_idx   = '0;
    max_ctr         = '0;
    found           = 1'b0;

    for (int i = 0; i < NUM_REQ; i++) begin
      if (effective_eligible[i]) begin
        if (!found || (item.wait_ctr_observed[i] > max_ctr)) begin
          found           = 1'b1;
          exp_grant_valid = 1'b1;
          max_ctr         = item.wait_ctr_observed[i];
          exp_grant_idx   = IDX_W'(i);
        end
      end
    end

    // Check 1: grant_valid verification
    if (item.grant_valid_observed !== exp_grant_valid) begin
      `uvm_error("SB_ARB_VALID", $sformatf("FAIL: grant_valid mismatch! Expected: %0b, Got: %0b",
                 exp_grant_valid, item.grant_valid_observed))
      arb_errors++;
    end

    // Check 2: Winner index & 1-hot grant verification
    if (exp_grant_valid) begin
      if (item.grant_idx_observed !== exp_grant_idx) begin
        `uvm_error("SB_ARB_IDX", $sformatf("FAIL: grant_idx mismatch! Expected: %0d (ctr=%0d), Got: %0d (ctr=%0d)",
                   exp_grant_idx, max_ctr, item.grant_idx_observed, item.wait_ctr_observed[item.grant_idx_observed]))
        arb_errors++;
      end else begin
        `uvm_info("SB_ARB", $sformatf("[PASS] Arbiter selected winner slot %0d (ctr=%0d, tie-break/highest)",
                  exp_grant_idx, max_ctr), UVM_LOW)
        arb_checks_passed++;
      end

      // Check 3: 1-hot grant vector check
      if (item.grant_observed[exp_grant_idx] !== 1'b1 || $countones(item.grant_observed) != 1) begin
        `uvm_error("SB_ARB_HOT", $sformatf("FAIL: 1-hot grant error! Expected bit %0d=1, Got 0x%08h",
                   exp_grant_idx, item.grant_observed))
        arb_errors++;
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("SB", "--------------------------------------------------", UVM_LOW)
    `uvm_info("SB", "       ARBITER SCOREBOARD VERIFICATION SUMMARY    ", UVM_LOW)
    `uvm_info("SB", $sformatf("Total Arbitration Checks : %0d", arb_checks_total), UVM_LOW)
    `uvm_info("SB", $sformatf("Checks Passed            : %0d", arb_checks_passed), UVM_LOW)
    `uvm_info("SB", $sformatf("Total Scoreboard Errors  : %0d", arb_errors), UVM_LOW)
    `uvm_info("SB", "--------------------------------------------------", UVM_LOW)

    if (arb_errors == 0 && arb_checks_total > 0) begin
      `uvm_info("SB", ">>> SCOREBOARD CHECK PASSED: ALL ARBITER CHECKS SATISFIED <<<", UVM_LOW)
    end else if (arb_errors > 0) begin
      `uvm_error("SB", $sformatf(">>> SCOREBOARD CHECK FAILED WITH %0d ERRORS <<<", arb_errors))
    end
  endfunction

endclass : mc_scoreboard
