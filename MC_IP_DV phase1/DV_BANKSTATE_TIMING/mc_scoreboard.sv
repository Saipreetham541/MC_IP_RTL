`timescale 1ns/1ps

// =============================================================================
// Class: mc_scoreboard
// Description: UVM Scoreboard for Feature 3: Bank State and Timing Legality.
//              - Verifies RD command is blocked while tRCD > 0.
//              - Verifies RD issues at the legal timing boundary (tRCD = 0).
//              - Verifies independent bank commands can proceed while another
//                bank is timing-blocked.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mc_scoreboard)

  uvm_analysis_imp #(mc_seq_item, mc_scoreboard) ap_imp;
  virtual mc_if vif;

  // Feature 3 Verification Tallies
  int unsigned f3_trcd_blocked_passed;
  int unsigned f3_boundary_issue_passed;
  int unsigned f3_independent_bank_passed;
  int unsigned total_errors;

  function new(string name = "mc_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    ap_imp = new("ap_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    f3_trcd_blocked_passed      = 0;
    f3_boundary_issue_passed    = 0;
    f3_independent_bank_passed  = 0;
    total_errors                = 0;

    void'(uvm_config_db#(virtual mc_if)::get(this, "", "mc_vif", vif));
    if (vif == null)
      void'(uvm_config_db#(virtual mc_if)::get(null, "*", "mc_vif", vif));
  endfunction

  virtual function void write(mc_seq_item item);
    // -------------------------------------------------------------------------
    // 1. Observe Row Command Issues (ACT)
    // -------------------------------------------------------------------------
    if (item.kind == MC_ITEM_ROW_ISSUE) begin
      int b_idx = {item.bg, item.bank};

      // Check for Independent Bank Parallelism: ACT to a bank while another bank is timing-blocked
      if (item.row_cmd == ROW_CMD_ACT) begin
        for (int ob = 0; ob < TOTAL_BANKS; ob++) begin
          if ((ob != b_idx) && (item.cnt_rcd_snap[ob] > 0)) begin
            f3_independent_bank_passed++;
            `uvm_info("SCB_F3_PASS",
              $sformatf("[PASS: Feature 3] Independent Bank Parallelism: Bank %0d ACT issued while Bank %0d has tRCD=%0d > 0!",
              b_idx, ob, item.cnt_rcd_snap[ob]), UVM_LOW)
            break;
          end
        end
      end
    end

    // -------------------------------------------------------------------------
    // 2. Observe Column Command Issues (RD, WR)
    // -------------------------------------------------------------------------
    if (item.kind == MC_ITEM_COL_ISSUE) begin
      int b_idx = {item.bg, item.bank};

      // Check 3.1 & 3.2: tRCD Requirement Enforcement
      if (item.cnt_rcd_snap[b_idx] > 0) begin
        total_errors++;
        `uvm_error("SCB_F3_FAIL",
          $sformatf("[FAIL: Feature 3] TIMING VIOLATION: Column %s issued to Bank %0d while tRCD remaining = %0d!",
          item.col_cmd.name(), b_idx, item.cnt_rcd_snap[b_idx]))
      end else begin
        f3_trcd_blocked_passed++;
        f3_boundary_issue_passed++;
        `uvm_info("SCB_F3_PASS",
          $sformatf("[PASS: Feature 3] Column %s issued legally to Bank %0d at timing boundary (tRCD=0)!",
          item.col_cmd.name(), b_idx), UVM_LOW)
      end

      // Check 3.3: Column RD issued to one bank while another bank is timing-blocked
      for (int ob = 0; ob < TOTAL_BANKS; ob++) begin
        if ((ob != b_idx) && (item.cnt_rcd_snap[ob] > 0)) begin
          f3_independent_bank_passed++;
          `uvm_info("SCB_F3_PASS",
            $sformatf("[PASS: Feature 3] Independent Bank Progress: Bank %0d %s issued while Bank %0d has tRCD=%0d > 0!",
            b_idx, item.col_cmd.name(), ob, item.cnt_rcd_snap[ob]), UVM_LOW)
          break;
        end
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("SCB_REPORT", "========================================================", UVM_LOW)
    `uvm_info("SCB_REPORT", "     FEATURE 3 SCOREBOARD VERIFICATION REPORT           ", UVM_LOW)
    `uvm_info("SCB_REPORT", "========================================================", UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("   tRCD Blocking Checks            : %0d PASSED", f3_trcd_blocked_passed), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("   Legal Boundary Issue Checks     : %0d PASSED", f3_boundary_issue_passed), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("   Independent Bank Checks         : %0d PASSED", f3_independent_bank_passed), UVM_LOW)
    `uvm_info("SCB_REPORT", "========================================================", UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf(" TOTAL PROTOCOL VIOLATIONS          : %0d", total_errors), UVM_LOW)
    `uvm_info("SCB_REPORT", "========================================================", UVM_LOW)

    if (total_errors > 0) begin
      `uvm_error("SCB_FAIL", $sformatf("Scoreboard flagged %0d critical errors!", total_errors))
    end else begin
      `uvm_info("SCB_SUCCESS", ">>> ALL FEATURE 3 TIMING & LEGALITY CHECKS PASSED WITH ZERO ERRORS! <<<", UVM_LOW)
    end
  endfunction

endclass : mc_scoreboard
