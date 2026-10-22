`timescale 1ns/1ps

// =============================================================================
// Module: mc_rdb
// Description: Read Data Buffer (16 entries) for MC16X2 HBM3 Memory Controller IP.
// =============================================================================
module mc_rdb
  import mc_pkg::*;
#(
  parameter int DFI_PC_DATA_W = 32
) (
  input  logic                      clk,
  input  logic                      rst_n,

  // Tag push when COL_CMD_RD is issued by Scheduler
  input  logic                      rd_cmd_issue_val,
  input  logic [AXI_ID_W-1:0]       rd_cmd_issue_id,
  output logic                      rdb_full,

  // Returning Read Data from DFI PHY
  input  logic                      dfi_rddata_valid,
  input  logic [DFI_PC_DATA_W-1:0]  dfi_rddata,

  // Read Completion output to R CDC FIFO / AXI Front-End
  output logic                      rdb_valid,
  input  logic                      rdb_ready,
  output logic [DFI_PC_DATA_W-1:0]  rdb_data,
  output logic [AXI_ID_W-1:0]       rdb_axi_id
);

  // 1. In-Flight Read ID FIFO
  logic [AXI_ID_W-1:0] id_fifo     [RDB_DEPTH-1:0];
  logic [RDB_ADDR_W:0] id_wr_ptr, id_rd_ptr;

  // 2. Returning Read Data FIFO
  logic [DFI_PC_DATA_W-1:0] data_fifo [RDB_DEPTH-1:0];
  logic [AXI_ID_W-1:0]      ret_id_fifo [RDB_DEPTH-1:0];
  logic [RDB_ADDR_W:0]      data_wr_ptr, data_rd_ptr;

  wire [RDB_ADDR_W:0] outstanding_cnt = id_wr_ptr - data_rd_ptr;
  assign rdb_full  = (outstanding_cnt == RDB_DEPTH[RDB_ADDR_W:0]);

  wire data_empty  = (data_wr_ptr == data_rd_ptr);
  assign rdb_valid = !data_empty;
  assign rdb_data   = data_fifo[data_rd_ptr[RDB_ADDR_W-1:0]];
  assign rdb_axi_id = ret_id_fifo[data_rd_ptr[RDB_ADDR_W-1:0]];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      id_wr_ptr   <= '0;
      id_rd_ptr   <= '0;
      data_wr_ptr <= '0;
      data_rd_ptr <= '0;
    end else begin
      if (rd_cmd_issue_val && !rdb_full) begin
        id_fifo[id_wr_ptr[RDB_ADDR_W-1:0]] <= rd_cmd_issue_id;
        id_wr_ptr                          <= id_wr_ptr + 1'b1;
      end

      if (dfi_rddata_valid) begin
        data_fifo[data_wr_ptr[RDB_ADDR_W-1:0]]   <= dfi_rddata;
        ret_id_fifo[data_wr_ptr[RDB_ADDR_W-1:0]] <= id_fifo[id_rd_ptr[RDB_ADDR_W-1:0]];
        id_rd_ptr                                <= id_rd_ptr + 1'b1;
        data_wr_ptr                              <= data_wr_ptr + 1'b1;
      end

      if (rdb_valid && rdb_ready) begin
        data_rd_ptr <= data_rd_ptr + 1'b1;
      end
    end
  end

endmodule : mc_rdb
