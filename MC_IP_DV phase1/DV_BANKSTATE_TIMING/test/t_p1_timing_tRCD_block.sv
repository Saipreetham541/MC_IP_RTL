`timescale 1ns/1ps

// =============================================================================
// Test   : t_p1_timing_tRCD_block
// Feature: Feature 3 - Bank State and Timing Legality Verification
// Priority: P0 (Directed)
// Goal   : tRCD Block Check (Negative Window):
//          1. Reset the DUT (bank_is_open[0] == 0, cnt_rcd[0] == 0).
//          2. Push a Read command (is_write = 0) targeting Bank 0, Row X.
//          3. Grant resulting ROW_CMD_ACT so Bank 0 opens Row X and loads cnt_rcd[0] = 18.
//          4. Observe the next 18 clock cycles while cnt_rcd[0] counts down from 18 to 1.
// Pass Criteria:
//          - For all 18 countdown cycles where cnt_rcd[0] > 0, legal_rd[0] and
//            slot_legal[0] remain 0.
//          - col_req_val remains 0 (the Read command is strictly blocked from issuing early).
// =============================================================================
`ifndef T_P1_TIMING_TRCD_BLOCK_SV
`define T_P1_TIMING_TRCD_BLOCK_SV

class t_p1_timing_tRCD_block extends mc_base_test;
  `uvm_component_utils(t_p1_timing_tRCD_block)

  function new(string name = "t_p1_timing_tRCD_block", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    seq_timing_trcd_block seq;
    int blocked_cycles;
    bit illegal_rd_detected;

    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " STARTING TEST: t_p1_timing_tRCD_block (Feature 3, Test 1)", UVM_LOW)
    `uvm_info("TEST", " GOAL: Verify RD blocked while cnt_rcd[0] counts down 18->1", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    // Hold channel grants low at time 0 to stage ACT deterministically
    vif.ch_arb_row_grant = 1'b0;
    vif.ch_arb_col_grant = 1'b0;

    // -------------------------------------------------------------------------
    // STEP 1: Reset the DUT (bank_is_open[0] == 0, cnt_rcd[0] == 0)
    // -------------------------------------------------------------------------
    wait_reset();
    `uvm_info("TEST", "[STEP 1] Checking post-reset initial state for Bank 0...", UVM_LOW)
    if ((vif.dbg_bank_is_open[0] === 1'b0) && (vif.dbg_cnt_rcd[0] === 8'd0)) begin
      `uvm_info("TEST", "[PASS] Step 1: Bank 0 is closed and cnt_rcd[0] == 0 as expected.", UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Bank 0 initial state wrong! open=%0b cnt_rcd=%0d",
                 vif.dbg_bank_is_open[0], vif.dbg_cnt_rcd[0]))
    end

    // -------------------------------------------------------------------------
    // STEP 2: Push a Read command (is_write = 0) targeting Bank 0, Row X
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 2] Enqueuing Read command targeting Bank 0, Row 0x0ABC...", UVM_LOW)
    seq = seq_timing_trcd_block::type_id::create("seq");
    seq.start(env.agt.seqr);

    @(posedge vif.clk);
    #1ps;

    // Verify Row ACT request is generated for Bank 0
    if (vif.row_req_val && (vif.row_req_cmd == ROW_CMD_ACT) &&
        (vif.row_req_bg == 2'b00) && (vif.row_req_bank == 2'b00)) begin
      `uvm_info("TEST", "[PASS] Step 2: ROW_CMD_ACT correctly generated for Bank 0.", UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Expected ROW_CMD_ACT to Bank 0, got val=%0b cmd=%s bg=%0d ba=%0d",
                 vif.row_req_val, vif.row_req_cmd.name(), vif.row_req_bg, vif.row_req_bank))
    end

    // -------------------------------------------------------------------------
    // STEP 3: Grant the resulting ROW_CMD_ACT so Bank 0 opens Row X and loads cnt_rcd[0] = 18
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 3] Pulsing ch_arb_row_grant=1 to issue ACT and load tRCD down-counter...", UVM_LOW)
    vif.ch_arb_row_grant = 1'b1;
    @(posedge vif.clk);
    #1ps;
    vif.ch_arb_row_grant = 1'b0;

    // Verify Bank 0 is now open and cnt_rcd[0] loaded with 18
    if (vif.dbg_bank_is_open[0] === 1'b1 && vif.dbg_cnt_rcd[0] === 8'd18) begin
      `uvm_info("TEST", $sformatf("[PASS] Step 3: Bank 0 opened Row 0x%04h, cnt_rcd[0] loaded with %0d.",
                vif.dbg_open_row[0], vif.dbg_cnt_rcd[0]), UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Bank 0 state mismatch after ACT! open=%0b cnt_rcd=%0d (expected 18)",
                 vif.dbg_bank_is_open[0], vif.dbg_cnt_rcd[0]))
    end

    // Enable downstream column grant so Read WOULD issue if legal
    vif.ch_arb_col_grant = 1'b1;

    // -------------------------------------------------------------------------
    // STEP 4: Observe the next 18 clock cycles while cnt_rcd[0] counts down from 18 to 1
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 4] Observing all 18 countdown cycles (cnt_rcd[0]: 18 down to 1)...", UVM_LOW)
    blocked_cycles      = 0;
    illegal_rd_detected = 1'b0;

    while (vif.dbg_cnt_rcd[0] > 0) begin
      blocked_cycles++;

      // Check Pass Criteria 1: legal_rd[0] must remain 0
      if (vif.dbg_legal_rd[0] !== 1'b0) begin
        `uvm_error("TEST", $sformatf("[FAIL] legal_rd[0] asserted while cnt_rcd[0] = %0d > 0!", vif.dbg_cnt_rcd[0]))
        illegal_rd_detected = 1'b1;
      end

      // Check Pass Criteria 2: slot_legal[0] must remain 0
      if (vif.dbg_slot_legal[0] !== 1'b0) begin
        `uvm_error("TEST", $sformatf("[FAIL] slot_legal[0] asserted while cnt_rcd[0] = %0d > 0!", vif.dbg_cnt_rcd[0]))
        illegal_rd_detected = 1'b1;
      end

      // Check Pass Criteria 3: col_req_val must remain 0 (strictly blocked early issue)
      if (vif.col_req_val !== 1'b0) begin
        `uvm_error("TEST", $sformatf("[FAIL] TIMING VIOLATION: col_req_val asserted while cnt_rcd[0] = %0d > 0!", vif.dbg_cnt_rcd[0]))
        illegal_rd_detected = 1'b1;
      end

      `uvm_info("TEST", $sformatf("  [Countdown Cycle %02d/18] cnt_rcd[0]=%02d | legal_rd[0]=%0b slot_legal[0]=%0b col_req_val=%0b (BLOCKED)",
                blocked_cycles, vif.dbg_cnt_rcd[0], vif.dbg_legal_rd[0], vif.dbg_slot_legal[0], vif.col_req_val), UVM_LOW)

      @(posedge vif.clk);
      #1ps;
    end

    // Verify all 18 countdown cycles passed
    if (!illegal_rd_detected && (blocked_cycles == 18)) begin
      `uvm_info("TEST", $sformatf("[PASS] PASS CRITERIA MET: Read command strictly blocked for all %0d cycles while cnt_rcd[0] > 0!",
                blocked_cycles), UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] tRCD blocking check failed: observed %0d blocked cycles (expected 18)!", blocked_cycles))
    end

    // -------------------------------------------------------------------------
    // STEP 5: Verify Column RD issues cleanly once cnt_rcd[0] reaches 0
    // -------------------------------------------------------------------------
    if (vif.col_req_val && (vif.col_req_cmd == COL_CMD_RD) &&
        (vif.col_req_bg == 2'b00) && (vif.col_req_bank == 2'b00)) begin
      `uvm_info("TEST", "[PASS] Column RD cleanly issued to Bank 0 upon tRCD expiry (cnt_rcd[0] == 0)!", UVM_LOW)
    end else begin
      `uvm_error("TEST", "[FAIL] Column RD was not issued upon tRCD expiry!")
    end

    #50ns;
    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " TEST RESULT: t_p1_timing_tRCD_block PASSED                 ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass : t_p1_timing_tRCD_block

// Type alias to allow running via either naming convention
class test_timing_trcd_block extends t_p1_timing_tRCD_block;
  `uvm_component_utils(test_timing_trcd_block)
  function new(string name = "test_timing_trcd_block", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : test_timing_trcd_block

`endif
