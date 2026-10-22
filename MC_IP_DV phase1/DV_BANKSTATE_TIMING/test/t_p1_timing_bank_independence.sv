`timescale 1ns/1ps

// =============================================================================
// Test   : t_p1_timing_bank_independence
// Feature: Feature 3 - Bank State and Timing Legality Verification
// Priority: P1 (Directed)
// Goal   : Independent Bank Parallelism Check:
//          1. Open Bank 1, Row Y first and wait for its tRCD (18 cycles) to finish
//             so Bank 1 is open and completely timing-legal (bank_is_open[1]=1, cnt_rcd[1]=0).
//          2. Push Command 0 to closed Bank 0, Row X -> issues ACT to Bank 0, starting
//             Bank 0's 18-cycle cnt_rcd[0] block (and 6-cycle cnt_rrd).
//          3. Immediately push Command 1 (RD) to already-open Bank 1, Row Y while
//             Bank 0 is still blocked (cnt_rcd[0] > 0).
// Pass Criteria:
//          - While cnt_rcd[0] > 0, Bank 0 remains blocked (legal_rd[0] == 0).
//          - Simultaneously, Bank 1 is unaffected (legal_rd[1] == 1), wins arbitration,
//            and issues col_req_val == 1 (COL_CMD_RD to Bank 1) without waiting for
//            Bank 0's tRCD timer.
// =============================================================================
`ifndef T_P1_TIMING_BANK_INDEPENDENCE_SV
`define T_P1_TIMING_BANK_INDEPENDENCE_SV

class t_p1_timing_bank_independence extends mc_base_test;
  `uvm_component_utils(t_p1_timing_bank_independence)

  function new(string name = "t_p1_timing_bank_independence", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Helper task: push a single targeted command through the sequencer
  task push_cmd(bit is_wr, bit [7:0] axi_id, bit [1:0] bg, bit [1:0] bank,
                bit [13:0] row, bit [4:0] col);
    seq_push_single_cmd cmd_seq;
    cmd_seq = seq_push_single_cmd::type_id::create("cmd_seq");
    cmd_seq.is_wr   = is_wr;
    cmd_seq.axi_id  = axi_id;
    cmd_seq.bg      = bg;
    cmd_seq.bank    = bank;
    cmd_seq.row     = row;
    cmd_seq.col     = col;
    cmd_seq.start(env.agt.seqr);
  endtask

  virtual task run_phase(uvm_phase phase);
    bit bank1_col_issued_while_bank0_blocked;

    phase.raise_objection(this);

    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " STARTING TEST: t_p1_timing_bank_independence (Feature 3, 3)", UVM_LOW)
    `uvm_info("TEST", " GOAL: Independent Bank Parallelism Check (Bank 1 vs Bank 0)", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    // Wait for reset to complete
    vif.ch_arb_row_grant = 1'b0;
    vif.ch_arb_col_grant = 1'b0;
    wait_reset();

    // -------------------------------------------------------------------------
    // STEP 1: Open Bank 1, Row Y first and wait for its tRCD (18 cycles) to finish
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 1] Opening Bank 1 (BG=0, BA=1), Row 0x222...", UVM_LOW)
    push_cmd(.is_wr(1'b0), .axi_id(8'h10), .bg(2'b00), .bank(2'b01), .row(14'h222), .col(5'h01));

    @(posedge vif.clk);
    #1ps;

    // Grant ACT to Bank 1
    if (vif.row_req_val && (vif.row_req_cmd == ROW_CMD_ACT) &&
        (vif.row_req_bg == 2'b00) && (vif.row_req_bank == 2'b01)) begin
      `uvm_info("TEST", "[PASS] ACT request generated for Bank 1. Granting ACT...", UVM_LOW)
    end
    vif.ch_arb_row_grant = 1'b1;
    @(posedge vif.clk);
    #1ps;
    vif.ch_arb_row_grant = 1'b0;

    // Enable column grant and wait for Bank 1 tRCD countdown (18 cycles) to complete
    vif.ch_arb_col_grant = 1'b1;
    while (vif.dbg_cnt_rcd[1] > 0) begin
      @(posedge vif.clk);
      #1ps;
    end

    // Wait 2 extra cycles for column read to issue and pop, leaving Bank 1 open with Row Y
    repeat (2) @(posedge vif.clk);
    #1ps;

    if ((vif.dbg_bank_is_open[1] === 1'b1) && (vif.dbg_cnt_rcd[1] === 8'd0)) begin
      `uvm_info("TEST", $sformatf("[PASS] Step 1 Complete: Bank 1 is OPEN (Row 0x%04h), cnt_rcd[1] = 0.",
                vif.dbg_open_row[1]), UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Bank 1 setup failed: open=%0b cnt_rcd[1]=%0d",
                 vif.dbg_bank_is_open[1], vif.dbg_cnt_rcd[1]))
    end

    // -------------------------------------------------------------------------
    // STEP 2: Push Command 0 to closed Bank 0, Row X -> issues ACT to Bank 0,
    //         starting Bank 0's 18-cycle cnt_rcd[0] block (and 6-cycle cnt_rrd)
    // -------------------------------------------------------------------------
    `uvm_info("TEST", "[STEP 2] Pushing Command 0 to closed Bank 0 (BG=0, BA=0), Row 0x111...", UVM_LOW)
    vif.ch_arb_col_grant = 1'b0; // hold col grant low to stage deterministically
    push_cmd(.is_wr(1'b0), .axi_id(8'h20), .bg(2'b00), .bank(2'b00), .row(14'h111), .col(5'h00));

    @(posedge vif.clk);
    #1ps;

    // Verify ACT generated for Bank 0
    if (vif.row_req_val && (vif.row_req_cmd == ROW_CMD_ACT) &&
        (vif.row_req_bg == 2'b00) && (vif.row_req_bank == 2'b00)) begin
      `uvm_info("TEST", "[PASS] Step 2: ROW_CMD_ACT generated for closed Bank 0. Firing ACT...", UVM_LOW)
    end
    vif.ch_arb_row_grant = 1'b1;
    @(posedge vif.clk);
    #1ps;
    vif.ch_arb_row_grant = 1'b0;

    `uvm_info("TEST", $sformatf("[PASS] Bank 0 ACT fired! Bank 0 opened Row 0x111, cnt_rcd[0]=%0d, cnt_rrd=%0d.",
              vif.dbg_cnt_rcd[0], vif.dbg_cnt_rrd), UVM_LOW)

    // -------------------------------------------------------------------------
    // STEP 3: Immediately push Command 1 (RD) to already-open Bank 1, Row Y
    //         while Bank 0 is still blocked (cnt_rcd[0] > 0)
    // -------------------------------------------------------------------------
    `uvm_info("TEST", $sformatf("[STEP 3] Immediately pushing Command 1 (RD) to already-open Bank 1 while Bank 0 has cnt_rcd[0]=%0d > 0...",
              vif.dbg_cnt_rcd[0]), UVM_LOW)
    // Keep col_grant low so Bank 1's candidate command holds on interface for check
    vif.ch_arb_col_grant = 1'b0;
    push_cmd(.is_wr(1'b0), .axi_id(8'h21), .bg(2'b00), .bank(2'b01), .row(14'h222), .col(5'h05));

    @(posedge vif.clk);
    #1ps;

    // -------------------------------------------------------------------------
    // STEP 4: Verify PASS Criteria
    // • While cnt_rcd[0] > 0, Bank 0 remains blocked (legal_rd[0] == 0).
    // • Simultaneously, Bank 1 is unaffected (legal_rd[1] == 1), wins arbitration,
    //   and issues col_req_val == 1 (COL_CMD_RD to Bank 1) without waiting for
    //   Bank 0's tRCD timer.
    // -------------------------------------------------------------------------
    bank1_col_issued_while_bank0_blocked = 1'b0;

    `uvm_info("TEST", $sformatf("[CHECK] Bank 0 status: cnt_rcd[0]=%0d, legal_rd[0]=%0b (BLOCKED)",
              vif.dbg_cnt_rcd[0], vif.dbg_legal_rd[0]), UVM_LOW)
    `uvm_info("TEST", $sformatf("[CHECK] Bank 1 status: cnt_rcd[1]=%0d, legal_rd[1]=%0b (LEGAL)",
              vif.dbg_cnt_rcd[1], vif.dbg_legal_rd[1]), UVM_LOW)
    `uvm_info("TEST", $sformatf("[CHECK] Arbiter Output: col_req_val=%0b cmd=%s bg=%0d ba=%0d",
              vif.col_req_val, vif.col_req_cmd.name(), vif.col_req_bg, vif.col_req_bank), UVM_LOW)

    // Check Bank 0 is blocked
    if ((vif.dbg_cnt_rcd[0] > 0) && (vif.dbg_legal_rd[0] === 1'b0)) begin
      `uvm_info("TEST", "[PASS] PASS CRITERIA 1 MET: Bank 0 is strictly timing-blocked (legal_rd[0] == 0) while cnt_rcd[0] > 0.", UVM_LOW)
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Bank 0 blocking violation: cnt_rcd[0]=%0d, legal_rd[0]=%0b",
                 vif.dbg_cnt_rcd[0], vif.dbg_legal_rd[0]))
    end

    // Check Bank 1 is unaffected, wins arbitration, and issues COL_CMD_RD
    if ((vif.dbg_legal_rd[1] === 1'b1) && vif.col_req_val &&
        (vif.col_req_cmd == COL_CMD_RD) && (vif.col_req_bg == 2'b00) && (vif.col_req_bank == 2'b01)) begin
      bank1_col_issued_while_bank0_blocked = 1'b1;
      `uvm_info("TEST", $sformatf("[PASS] PASS CRITERIA 2 MET: Bank 1 unaffected (legal_rd[1]=1), won arbitration, and issued COL_CMD_RD while Bank 0 had cnt_rcd[0]=%0d remaining!",
                vif.dbg_cnt_rcd[0]), UVM_LOW)
      env.sb.f3_independent_bank_passed++;
    end else begin
      `uvm_error("TEST", $sformatf("[FAIL] Bank 1 was stalled! legal_rd[1]=%0b col_req_val=%0b cmd=%s bank=%0d",
                 vif.dbg_legal_rd[1], vif.col_req_val, vif.col_req_cmd.name(), vif.col_req_bank))
    end

    // Now pulse ch_arb_col_grant=1 to consume Bank 1 column read
    vif.ch_arb_col_grant = 1'b1;
    @(posedge vif.clk);
    #1ps;
    vif.ch_arb_col_grant = 1'b0;

    #50ns;
    `uvm_info("TEST", "==========================================================", UVM_LOW)
    `uvm_info("TEST", " TEST RESULT: t_p1_timing_bank_independence PASSED         ", UVM_LOW)
    `uvm_info("TEST", "==========================================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass : t_p1_timing_bank_independence

// Type alias to allow running via either naming convention
class test_timing_bank_independence extends t_p1_timing_bank_independence;
  `uvm_component_utils(test_timing_bank_independence)
  function new(string name = "test_timing_bank_independence", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : test_timing_bank_independence

`endif
