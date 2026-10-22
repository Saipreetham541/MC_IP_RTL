`timescale 1ns/1ps

// =============================================================================
// Module: mc_top
// Description: Top-level verification testbench for Credit-Counter Arbiter (mc_arbiter).
//              Instantiates:
//              1. mc_arbiter DUT
//              2. mc_if Virtual Interface
//              3. Clock and Reset generation
//              4. UVM Configuration DB and starts test execution.
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

module mc_top;
  logic clk, rst_n;

  // ---------------------------------------------------------------------------
  // 1. Clock Generation (100MHz, 10ns period)
  // ---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // 2. Synchronous Reset Generation
  // ---------------------------------------------------------------------------
  initial begin
    rst_n = 0;
    #25;
    @(posedge clk);
    rst_n = 1;
  end

  // ---------------------------------------------------------------------------
  // 3. Virtual Interface Instantiation
  // ---------------------------------------------------------------------------
  mc_if vif (.clk(clk), .rst_n(rst_n));

  // ---------------------------------------------------------------------------
  // 4. Credit-Counter Arbiter DUT (mc_arbiter) Instantiation
  // ---------------------------------------------------------------------------
  mc_arbiter #(
    .NUM_REQ (NUM_REQ)
  ) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .req_valid   (vif.req_valid),
    .req_legal   (vif.req_legal),
    .grant_ack   (vif.grant_ack),
    .grant       (vif.grant),
    .grant_idx   (vif.grant_idx),
    .grant_valid (vif.grant_valid)
  );

  // Probe arbiter internal wait_ctr into interface for verification visibility
  generate
    for (genvar gi = 0; gi < NUM_REQ; gi++) begin : gen_wait_ctr_probe
      assign vif.wait_ctr[gi] = dut.wait_ctr[gi];
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 5. Pass Interface to UVM Config DB & Start Test
  // ---------------------------------------------------------------------------
  initial begin
    uvm_config_db#(virtual mc_if)::set(null, "*", "mc_vif", vif);

    // Default test: change this string anytime to run a specific test by default
    run_test("test_arbiter_highest_ctr_wins");
  end

  // ---------------------------------------------------------------------------
  // 6. Waveform Dump
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, mc_top);
  end

endmodule : mc_top
