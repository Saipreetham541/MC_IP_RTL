`timescale 1ns/1ps

// =============================================================================
// Module: mc_top
// Description: Top-level Testbench for MC16X2 HBM3 Memory Controller IP (mc_pc_core).
//              Instantiates:
//              1. mc_pc_core DUT
//              2. mc_if Virtual Interface
//              3. Clock (1 GHz) and Reset generators
//              4. Internal signal probes for verification observability
//              5. UVM Config DB registration and test runner
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

module mc_top;
  logic clk, rst_n;

  // ---------------------------------------------------------------------------
  // 1. Clock Generation (1 GHz dfi_clk, 1.0 ns period)
  // ---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #0.5ns clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // 2. Asynchronous / Synchronous Reset Generation
  // ---------------------------------------------------------------------------
  initial begin
    rst_n = 0;
    #5ns;
    @(negedge clk);
    rst_n = 1;
  end

  // ---------------------------------------------------------------------------
  // 3. Virtual Interface Instantiation
  // ---------------------------------------------------------------------------
  mc_if vif (.clk(clk), .rst_n(rst_n));

  // ---------------------------------------------------------------------------
  // 4. Memory Controller Core DUT (mc_pc_core) Instantiation
  // ---------------------------------------------------------------------------
  mc_pc_core #(
    .DFI_PC_DATA_W (32),
    .DFI_PC_MASK_W (4)
  ) dut (
    .clk                   (clk),
    .rst_n                 (rst_n),

    // 1. Upstream Command Push
    .cmd_push_val          (vif.cmd_push_val),
    .cmd_push_entry        (vif.cmd_push_entry),
    .cmdq_full             (vif.cmdq_full),

    // 2. Write Data Buffer (WDB) Interface
    .wdb_push_val          (1'b0),
    .wdb_push_data         ('0),
    .wdb_push_mask         ('0),
    .wdb_alloc_ptr         (),
    .wdb_full              (),
    .wdb_raddr             ('0),
    .wdb_rdata             (),
    .wdb_rmask             (),
    .wdb_pop_val           (1'b0),
    .wdb_pop_ptr           ('0),

    // 3. Read Data Buffer (RDB) Interface
    .dfi_rddata_valid      (1'b0),
    .dfi_rddata            ('0),
    .rdb_valid             (),
    .rdb_ready             (1'b1),
    .rdb_data              (),
    .rdb_axi_id            (),

    // 4. Candidate Command Outputs to Channel Arbiter
    .row_req_val           (vif.row_req_val),
    .row_req_is_ref        (vif.row_req_is_ref),
    .row_req_cmd           (vif.row_req_cmd),
    .row_req_addr          (vif.row_req_addr),
    .row_req_bg            (vif.row_req_bg),
    .row_req_bank          (vif.row_req_bank),
    .ch_arb_row_grant      (vif.ch_arb_row_grant),

    .col_req_val           (vif.col_req_val),
    .col_req_cmd           (vif.col_req_cmd),
    .col_req_addr          (vif.col_req_addr),
    .col_req_bg            (vif.col_req_bg),
    .col_req_bank          (vif.col_req_bank),
    .col_req_wdb_ptr       (vif.col_req_wdb_ptr),
    .col_req_axi_id        (vif.col_req_axi_id),
    .ch_arb_col_grant      (vif.ch_arb_col_grant),

    // 5. Error & Status Flags
    .err_cmdq_overflow     (vif.err_cmdq_overflow),
    .err_wdb_overflow      (),
    .err_ref_deadline_miss ()
  );

  // ---------------------------------------------------------------------------
  // 5. Connect DUT Internal Observability Probes into Interface
  // ---------------------------------------------------------------------------
  assign vif.dbg_bank_is_open = dut.bank_is_open;
  assign vif.dbg_open_row     = dut.open_row;
  assign vif.dbg_cnt_rrd      = dut.u_timing_check.cnt_rrd;
  assign vif.dbg_legal_rd     = dut.u_timing_check.legal_rd;
  assign vif.dbg_legal_act    = dut.u_timing_check.legal_act;
  assign vif.dbg_slot_valid   = dut.slot_valid;
  assign vif.dbg_slot_legal   = dut.slot_legal;
  assign vif.dbg_slot_data    = dut.slot_data;
  assign vif.dbg_grant_idx    = dut.cmdq_grant_idx;
  assign vif.dbg_ref_req      = dut.ref_req;

  generate
    for (genvar b = 0; b < TOTAL_BANKS; b++) begin : gen_cnt_rcd
      assign vif.dbg_cnt_rcd[b] = dut.u_timing_check.cnt_rcd[b];
    end
    for (genvar s = 0; s < CMDQ_DEPTH; s++) begin : gen_wait_ctr
      assign vif.dbg_wait_ctr[s] = dut.u_cmdq_arbiter.wait_ctr[s];
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 6. UVM Config DB Registration & Test Execution
  // ---------------------------------------------------------------------------
  initial begin
    uvm_config_db#(virtual mc_if)::set(null, "*", "mc_vif", vif);

    // Default test: change this string anytime to run a specific test by default
    run_test("t_p1_timing_tRCD_block");
  end

  // ---------------------------------------------------------------------------
  // 7. Waveform Dump
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, mc_top);
  end

endmodule : mc_top
