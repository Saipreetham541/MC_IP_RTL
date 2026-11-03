`default_nettype none
`timescale 1ns/1ps

// Initial project-defined register map. Exact vendor/RDL map is not supplied by
// the architecture PDF. CSR storage resets only on presetn; AXI/core reset does
// not erase configuration. All status/config accesses are coherent in dfi_clk.
module mc_csr (
  input logic pclk, presetn, dfi_clk,
  input logic [19:0] paddr,
  input logic psel, penable, pwrite,
  input logic [31:0] pwdata,
  input logic [3:0] pstrb,
  output logic pready,
  output logic [31:0] prdata,
  output logic pslverr, irq,
  output logic enable,
  output logic [15:0] channel_enable,
  output logic [31:0] wdata_timeout,
  input logic error_timeout, error_protocol,
  input logic [31:0] err_cmdq_overflow, err_wdb_overflow, err_ref_deadline_miss,
  input logic [31:0] cmdq_full, wdb_full, rdb_valid,
  input logic busy, write_faulted, write_complete, read_complete
);
  logic request_valid, request_ready, request_write, response_valid, response_error;
  logic [19:0] request_addr;
  logic [31:0] request_data, response_data;
  logic [3:0] request_strb;
  logic timeout_toggle, timeout_event, d_valid, d_write, d_error;
  logic [19:0] d_addr;
  logic [31:0] d_data, d_response, byte_mask;
  logic [3:0] d_strb;
  logic [5:0] error_status, irq_mask, events;
  logic [31:0] writes, reads;
  mc_apb_if u_apb_if (.*);
  mc_sync_dfi u_sync_dfi (.*);
  assign irq = |(error_status & irq_mask);
  assign events = {timeout_event | (d_valid && d_error), |err_ref_deadline_miss, |err_wdb_overflow,
                   |err_cmdq_overflow, error_protocol, error_timeout};
  always_comb begin
    for (int b = 0; b < 4; b++) byte_mask[b*8 +: 8] = {8{d_strb[b]}};
    d_response = 0; d_error = 0;
    case (d_addr)
      20'h00000: begin d_response = 32'h4D43_1602; d_error = d_write; end
      20'h00004: d_response = {31'b0,enable};
      20'h00008: d_response = {16'b0,channel_enable};
      20'h0000C: d_response = wdata_timeout;
      20'h00010: d_response = {26'b0,error_status};
      20'h00014: d_response = {26'b0,irq_mask};
      20'h00018: begin d_response = cmdq_full; d_error = d_write; end
      20'h0001C: begin d_response = wdb_full; d_error = d_write; end
      20'h00020: begin d_response = rdb_valid; d_error = d_write; end
      20'h00024: begin d_response = writes; d_error = d_write; end
      20'h00028: begin d_response = reads; d_error = d_write; end
      20'h0002C: begin d_response = {30'b0,write_faulted,busy}; d_error = d_write; end
      default: d_error = 1;
    endcase
  end
  always_ff @(posedge dfi_clk or negedge presetn) begin
    if (!presetn) begin
      enable <= 1; channel_enable <= 16'hFFFF; wdata_timeout <= 1024;
      error_status <= 0; irq_mask <= 6'h3F; writes <= 0; reads <= 0;
    end else begin
      error_status <= error_status | events;
      if (write_complete) writes <= writes+1'b1;
      if (read_complete) reads <= reads+1'b1;
      if (d_valid && d_write && !d_error) begin
        case (d_addr)
          20'h00004: if (d_strb[0]) enable <= d_data[0];
          20'h00008: channel_enable <= (channel_enable & ~byte_mask[15:0]) | (d_data[15:0] & byte_mask[15:0]);
          20'h0000C: wdata_timeout <= (wdata_timeout & ~byte_mask) | (d_data & byte_mask);
          20'h00010: error_status <= (error_status & ~(d_data[5:0] & byte_mask[5:0])) | events;
          20'h00014: irq_mask <= (irq_mask & ~byte_mask[5:0]) | (d_data[5:0] & byte_mask[5:0]);
          default: ;
        endcase
      end
    end
  end
endmodule
`default_nettype wire
