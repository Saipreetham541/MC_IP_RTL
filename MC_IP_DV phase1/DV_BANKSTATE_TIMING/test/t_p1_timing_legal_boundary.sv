`timescale 1ns/1ps

// =============================================================================
// Test   : t_p1_timing_legal_boundary
// Feature: Feature 3 - Bank State and Timing Legality Verification
// Priority: P0 (Directed)
// Goal   : Exact Cycle Boundary Release (cnt_rcd: 1 -> 0):
//          1. Following ROW_CMD_ACT on Bank 0 (cnt_rcd[0] loaded with 18), monitor
//             the exact transition from the last blocked cycle (cnt_rcd[0] == 1)
//             to the first legal cycle (cnt_rcd[0] == 0).
// Pass Criteria:
//          - 1 cycle before expiry (cnt_rcd[0] == 1): legal_rd[0] == 0 and col_req_val == 0.
//          - Exact expiry cycle (cnt_rcd[0] == 0): legal_rd[0] asserts 1,
//            slot_legal[0] asserts 1, and col_req_val asserts 1 with
//            col_req_cmd == COL_CMD_RD on that exact cycle.
// =============================================================================
`ifndef T_P1_TIMING_LEGAL_BOUNDARY_SV
`define T_P1_TIMING_LEGAL_BOUNDARY_SV

class t_p1_timing_legal_boundary extends mc_base_test;
  `uvm_component_utils(t_p1_timing_legal_boundary)

  function new(string name = "t_p1_timing_legal_boundary", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    seq_timing_legal_boundary seq;
    bit pre_expiry_ok;
    bit expiry_ok;

    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " STARTING TEST: t_p1_timing_legal_boundary (Feature 3, 2)  ", UVM_LOW)
    `uvm_info("TEST", " GOAL: Exact cycle boundary release (cnt_rcd: 1 -> 0)     ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    // Hold channel grants low at time 0 to stage ACT deterministically
    vif.ch_arb_row_grant = 1'b0;
    vif.ch_arb_col_grant = 1'b0;

    // Wait for reset to complete
    wait_reset();

    // -------------------------------------------------------------------------
    // STEP 1: Enqueue Read command to Bank 0, Row 0x0DEF
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 1] Enqueuing Read command to Bank 0 with grants held low...", UVM_LOW)
    seq = seq_timing_legal_boundary::type_id::create("seq");
    seq.start(env.agt.seqr);

    @(posedge vif.clk);
    #1ps;

    // Verify Row ACT request is generated for Bank 0
    if (vif.row_req_val && (vif.row_req_cmd == ROW_CMD_ACT)) begin
      `uvm_info("TEST", "[PASS] Step 1: ROW_CMD_ACT staged for Bank 0.", UVM_LOW)
    end

    // -------------------------------------------------------------------------
    // STEP 2: Issue ROW_CMD_ACT to Bank 0 (loads cnt_rcd[0] = 18)
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 2] Firing ACT to Bank 0 and loading cnt_rcd[0]=18...", UVM_LOW)
    vif.ch_arb_row_grant = 1'b1;
    @(posedge vif.clk);
    #1ps;
    vif.ch_arb_row_grant = 1'b0;

    `uvm_info("TEST", $sformatf("[PASS] ACT issued to Bank 0. Initial cnt_rcd[0] = %0d cycles.", vif.dbg_cnt_rcd[0]), UVM_LOW)

    // Enable column grant so command will issue immediately once legal
    vif.ch_arb_col_grant = 1'b1;

    // -------------------------------------------------------------------------
    // STEP 3: Monitor until 1 cycle before expiry (cnt_rcd[0] == 1)
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 3] Stepping until 1 cycle before expiry (cnt_rcd[0] == 1)...", UVM_LOW)
    while (vif.dbg_cnt_rcd[0] > 1) begin
      @(posedge vif.clk);
      #1ps;
    end

    // We are now at the last blocked cycle: cnt_rcd[0] == 1
    pre_expiry_ok = 1'b1;
    `uvm_info("TEST", $sformatf("[CHECK] Last blocked cycle: cnt_rcd[0]=%0d | legal_rd[0]=%0b slot_legal[0]=%0b col_req_val=%0b",
              vif.dbg_cnt_rcd[0], vif.dbg_legal_rd[0], vif.dbg_slot_legal[0], vif.col_req_val), UVM_LOW)

    if ((vif.dbg_legal_rd[0] === 1'b0) && (vif.col_req_val === 1'b0)) begin
      `uvm_info("TEST", "[PASS] PASS CRITERIA 1 MET: 1 cycle before expiry (cnt_rcd[0] == 1): legal_rd[0] == 0 and col_req_val == 0.", UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Pre-expiry check failed! legal_rd[0]=%0b col_req_val=%0b (expected both 0)",
                 vif.dbg_legal_rd[0], vif.col_req_val))
      pre_expiry_ok = 1'b0;
    end

    // -------------------------------------------------------------------------
    // STEP 4: Step to Exact Expiry Cycle (cnt_rcd: 1 -> 0)
    // -------------------------------------------------------------------------
    @(posedge vif.clk);
    #1ps;

    expiry_ok = 1'b1;
    `uvm_info("TEST", $sformatf("[CHECK] Exact expiry cycle: cnt_rcd[0]=%0d | legal_rd[0]=%0b slot_legal[0]=%0b col_req_val=%0b cmd=%s",
              vif.dbg_cnt_rcd[0], vif.dbg_legal_rd[0], vif.dbg_slot_legal[0], vif.col_req_val, vif.col_req_cmd.name()), UVM_LOW)

    if (vif.dbg_cnt_rcd[0] !== 8'd0) begin
      `uvm_error("TEST", $sformatf("[FAIL] cnt_rcd[0] is %0d (expected 0)!", vif.dbg_cnt_rcd[0]))
      expiry_ok = 1'b0;
    end

    if (vif.dbg_legal_rd[0] !== 1'b1) begin
      `uvm_error("TEST", "[FAIL] legal_rd[0] is not 1 at expiry cycle!")
      expiry_ok = 1'b0;
    end

    if (vif.dbg_slot_legal[0] !== 1'b1) begin
      `uvm_error("TEST", "[FAIL] slot_legal[0] is not 1 at expiry cycle!")
      expiry_ok = 1'b0;
    end

    if (!vif.col_req_val || (vif.col_req_cmd != COL_CMD_RD)) begin
      `uvm_error("TEST", $sformatf("[FAIL] col_req_val=%0b cmd=%s (expected val=1, COL_CMD_RD)!",
                 vif.col_req_val, vif.col_req_cmd.name()))
      expiry_ok = 1'b0;
    end

    if (expiry_ok && pre_expiry_ok) begin
      `uvm_info("TEST", "[PASS] PASS CRITERIA 2 MET: Exact expiry cycle (cnt_rcd[0] == 0): legal_rd[0]=1, slot_legal[0]=1, and col_req_val=1 with COL_CMD_RD on that exact cycle!", UVM_LOW)
    end

    #50ns;
    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " TEST RESULT: t_p1_timing_legal_boundary PASSED             ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass : t_p1_timing_legal_boundary

// Type alias to allow running via either naming convention
class test_timing_legal_boundary extends t_p1_timing_legal_boundary;
  `uvm_component_utils(test_timing_legal_boundary)
  function new(string name = "test_timing_legal_boundary", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : test_timing_legal_boundary

`endif
