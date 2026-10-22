`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mc_pkg::*;

module mc_top;
  logic clk, rst_n;

  // 1. Clock Generation (100MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // 2. Reset Generation
  initial begin
    rst_n = 0;
    #25;
    @(posedge clk);
    rst_n = 1;
  end

  // 3. Interface & DUT
  mc_if vif (.clk(clk), .rst_n(rst_n));

  mc_cmdq dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .push_val      (vif.push_val),
    .push_entry    (vif.push_entry),
    .cmdq_full     (vif.cmdq_full),
    .cmdq_overflow (vif.cmdq_overflow),
    .pop_val       (vif.pop_val),
    .pop_idx       (vif.pop_idx),
    .slot_valid    (vif.slot_valid),
    .slot_data     (vif.slot_data)
  );

  // 4. Pass Interface to UVM via Config DB
  initial begin
    uvm_config_db#(virtual mc_if)::set(null, "*", "mc_vif", vif);

    // Test to run: change this string anytime to run a different test!
    run_test("test_cmdq_boundary_empty_full");
  end

  // 5. Waveform Dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, mc_top);
  end
endmodule : mc_top
