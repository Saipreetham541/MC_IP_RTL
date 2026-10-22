`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

class mc_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mc_scoreboard)

  uvm_analysis_imp #(mc_seq_item, mc_scoreboard) ap_imp;
  virtual mc_if vif;

  // Shadow reference model
  cmd_entry_t shadow_slots [CMDQ_DEPTH-1:0];
  bit [CMDQ_DEPTH-1:0] shadow_valid = '0;

  int push_count       = 0;
  int pop_count        = 0;
  int overflow_events  = 0;
  int empty_pop_events = 0;
  int valid_pop_events = 0;

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
    // -------------------------------------------------------------------------
    // 1. PUSH TRANSACTION HANDLING
    // -------------------------------------------------------------------------
    if (item.push_val) begin
      push_count++;

      if (&shadow_valid) begin
        // Queue was FULL when this push arrived -> Overflow condition
        overflow_events++;
        if (!item.cmdq_overflow_observed) begin
          `uvm_error("SB_OVF", $sformatf("FAIL: Push #%0d on full queue did NOT assert cmdq_overflow!", push_count))
        end else begin
          `uvm_info("SB", $sformatf("[PASS] Push #%0d rejected cleanly: cmdq_full=1, cmdq_overflow=1. Queue size remains 32.", push_count), UVM_LOW)
        end
      end else begin
        // Queue NOT full -> Priority encoder allocates lowest free slot
        int alloc_idx = -1;
        for (int i = 0; i < CMDQ_DEPTH; i++) begin
          if (!shadow_valid[i]) begin
            alloc_idx = i;
            break;
          end
        end

        shadow_valid[alloc_idx] = 1'b1;
        shadow_slots[alloc_idx] = item.push_entry;
        `uvm_info("SB", $sformatf("[PUSH] Stored in slot %0d (axi_id=0x%02h, row=0x%0h). Occupancy: %0d/32",
                  alloc_idx, item.push_entry.axi_id, item.push_entry.row, $countones(shadow_valid)), UVM_MEDIUM)
      end
    end

    // -------------------------------------------------------------------------
    // 2. POP TRANSACTION HANDLING
    // -------------------------------------------------------------------------
    if (item.pop_val) begin
      pop_count++;

      if (!shadow_valid[item.pop_idx]) begin
        // Popping an already empty/invalid slot (e.g. empty queue test)
        empty_pop_events++;
        `uvm_info("SB", $sformatf("[PASS] Empty pop on slot %0d: handled safely, slot remains invalid (valid=0).", item.pop_idx), UVM_LOW)
      end else begin
        // Valid pop: Verify data integrity of this slot before invalidating
        if (vif.slot_data[item.pop_idx] !== shadow_slots[item.pop_idx]) begin
          `uvm_error("SB_DATA_CORRUPT", $sformatf("FAIL: Data mismatch on popping slot %0d! Expected %p, Got %p",
                     item.pop_idx, shadow_slots[item.pop_idx], vif.slot_data[item.pop_idx]))
        end else begin
          `uvm_info("SB", $sformatf("[PASS] Popped slot %0d: slot_data matches pushed command exactly!", item.pop_idx), UVM_MEDIUM)
        end

        shadow_valid[item.pop_idx] = 1'b0;
        valid_pop_events++;
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    int errors = 0;

    `uvm_info("SB", "--------------------------------------------------", UVM_LOW)
    `uvm_info("SB", "         SCOREBOARD FINAL VERIFICATION SUMMARY    ", UVM_LOW)
    `uvm_info("SB", $sformatf("Total Push Attempts : %0d", push_count), UVM_LOW)
    `uvm_info("SB", $sformatf("Total Pop Attempts  : %0d", pop_count), UVM_LOW)
    `uvm_info("SB", $sformatf("Valid Pops Checked  : %0d", valid_pop_events), UVM_LOW)
    `uvm_info("SB", $sformatf("Empty Pops Handled  : %0d", empty_pop_events), UVM_LOW)
    `uvm_info("SB", $sformatf("Overflow Rejections : %0d", overflow_events), UVM_LOW)
    `uvm_info("SB", $sformatf("DUT valid slots cnt : %0d", $countones(vif.slot_valid)), UVM_LOW)
    `uvm_info("SB", $sformatf("DUT cmdq_full state : %0b", vif.cmdq_full), UVM_LOW)
    `uvm_info("SB", "--------------------------------------------------", UVM_LOW)

    // 1. Verify slot_valid bits match shadow_valid
    if (vif.slot_valid !== shadow_valid) begin
      `uvm_error("SB", $sformatf("FAIL: slot_valid mismatch! Expected: 0x%08h, Got: 0x%08h", shadow_valid, vif.slot_valid))
      errors++;
    end

    // 2. Verify cmdq_full indication
    if (vif.cmdq_full !== (&shadow_valid)) begin
      `uvm_error("SB", $sformatf("FAIL: cmdq_full mismatch! Expected: %0b, Got: %0b", (&shadow_valid), vif.cmdq_full))
      errors++;
    end

    // 3. Verify all remaining valid slots have uncorrupted data
    for (int i = 0; i < CMDQ_DEPTH; i++) begin
      if (shadow_valid[i]) begin
        if (vif.slot_data[i] !== shadow_slots[i]) begin
          `uvm_error("SB", $sformatf("FAIL: Remaining slot %0d data mismatch!", i))
          errors++;
        end
      end
    end

    if (errors == 0) begin
      `uvm_info("SB", ">>> SCOREBOARD CHECK PASSED: ALL CHECKS SATISFIED <<<", UVM_LOW)
    end else begin
      `uvm_error("SB", $sformatf(">>> SCOREBOARD CHECK FAILED WITH %0d ERRORS <<<", errors))
    end
  endfunction

endclass : mc_scoreboard
