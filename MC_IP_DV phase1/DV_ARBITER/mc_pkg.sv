`timescale 1ns/1ps

// =============================================================================
// Package: mc_pkg
// Description: Global parameters for Credit-Counter Arbiter (mc_arbiter).
// =============================================================================
package mc_pkg;
  parameter int NUM_REQ          = 32; // Total number of request slots (CMDQ depth)
  parameter int IDX_W            = 5;  // Binary index width ($clog2(32) = 5)
  parameter int CREDIT_CTR_WIDTH = 8;  // 8-bit wait counter saturating at 255
endpackage : mc_pkg
