`timescale 1ns/1ps

module mc_wdb
  import mc_pkg::*;
#(
  parameter int DFI_PC_DATA_W = 32, // 32-bit data lane per PC on DFI (Section 3.3.2a)
  parameter int DFI_PC_MASK_W = 4   // 4-bit byte mask per PC on DFI (Section 3.3.2a)
) (
  input  logic                      clk,
  input  logic                      rst_n,

  // Allocation & Write Data push from Front-End
  input  logic                      wdb_push_val,
  input  logic [DFI_PC_DATA_W-1:0]  wdb_push_data,
  input  logic [DFI_PC_MASK_W-1:0]  wdb_push_mask,
  output logic [WDB_ADDR_W-1:0]     wdb_alloc_ptr, // Pointer attached to CMDQ entry
  output logic                      wdb_full,
  output logic                      wdb_overflow,  // Error flag for Section 10

  // Readiness mask to Scheduler (Section 5.1: write waits for WDATA arrival)
  output logic [WDB_DEPTH-1:0]      wdb_data_rdy,

  // Read & Release interface to DFI Formatter
  input  logic [WDB_ADDR_W-1:0]     wdb_raddr,
  output logic [DFI_PC_DATA_W-1:0]  wdb_rdata,
  output logic [DFI_PC_MASK_W-1:0]  wdb_rmask,
  input  logic                      wdb_pop_val,
  input  logic [WDB_ADDR_W-1:0]     wdb_pop_ptr
);

  logic [DFI_PC_DATA_W-1:0] data_mem [WDB_DEPTH-1:0];
  logic [DFI_PC_MASK_W-1:0] mask_mem [WDB_DEPTH-1:0];
  logic [WDB_DEPTH-1:0]     valid_reg;

  assign wdb_data_rdy = valid_reg;
  assign wdb_full     = &valid_reg;
  assign wdb_overflow = wdb_push_val && wdb_full;

  // Priority encoder: find lowest free WDB slot
  logic free_found;
  always_comb begin
    wdb_alloc_ptr = '0;
    free_found    = 1'b0;
    for (int i = 0; i < WDB_DEPTH; i++) begin
      if (!valid_reg[i] && !free_found) begin
        wdb_alloc_ptr = WDB_ADDR_W'(i);
        free_found    = 1'b1;
      end
    end
  end

  // Combinational read port for DFI Formatter
  assign wdb_rdata = data_mem[wdb_raddr];
  assign wdb_rmask = mask_mem[wdb_raddr];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_reg <= '0;
      for (int i = 0; i < WDB_DEPTH; i++) begin
        data_mem[i] <= '0;
        mask_mem[i] <= '0;
      end
    end else begin
      if (wdb_pop_val) begin
        valid_reg[wdb_pop_ptr] <= 1'b0;
      end

      if (wdb_push_val && !wdb_full) begin
        valid_reg[wdb_alloc_ptr] <= 1'b1;
        data_mem[wdb_alloc_ptr]  <= wdb_push_data;
        mask_mem[wdb_alloc_ptr]  <= wdb_push_mask;
      end
    end
  end

endmodule : mc_wdb