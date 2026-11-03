`default_nettype none
`timescale 1ns/1ps

// CDC_MODULE: bundled request/response data stays stable until a synchronized
// toggle acknowledgement. Multibit fields never use independent bit sampling.
module mc_sync_dfi (
  input logic pclk, presetn, dfi_clk,
  input logic request_valid,
  output logic request_ready,
  input logic [19:0] request_addr,
  input logic request_write,
  input logic [31:0] request_data,
  input logic [3:0] request_strb,
  output logic response_valid,
  output logic [31:0] response_data,
  output logic response_error,
  input logic timeout_toggle,
  output logic timeout_event,
  output logic d_valid,
  output logic [19:0] d_addr,
  output logic d_write,
  output logic [31:0] d_data,
  output logic [3:0] d_strb,
  input logic [31:0] d_response,
  input logic d_error
);
  logic req_toggle, ack_toggle, busy;
  logic [19:0] held_addr;
  logic held_write;
  logic [31:0] held_data, held_response;
  logic [3:0] held_strb;
  logic held_error, req_seen, timeout_seen;
  (* ASYNC_REG = "TRUE" *) logic [1:0] req_sync, ack_sync, timeout_sync;
  assign request_ready = !busy && !response_valid;
  assign d_valid = req_sync[1] != req_seen;
  assign d_addr = held_addr;
  assign d_write = held_write;
  assign d_data = held_data;
  assign d_strb = held_strb;
  assign timeout_event = timeout_sync[1] != timeout_seen;
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      req_toggle <= 0; busy <= 0; ack_sync <= 0;
      held_addr <= 0; held_write <= 0; held_data <= 0; held_strb <= 0;
      response_valid <= 0; response_data <= 0; response_error <= 0;
    end else begin
      ack_sync <= {ack_sync[0],ack_toggle};
      response_valid <= 0;
      if (request_valid && request_ready) begin
        held_addr <= request_addr; held_write <= request_write;
        held_data <= request_data; held_strb <= request_strb;
        req_toggle <= ~req_toggle; busy <= 1;
      end
      if (busy && ack_sync[1] == req_toggle) begin
        response_data <= held_response; response_error <= held_error;
        response_valid <= 1; busy <= 0;
      end
    end
  end
  always_ff @(posedge dfi_clk or negedge presetn) begin
    if (!presetn) begin
      req_sync <= 0; req_seen <= 0; ack_toggle <= 0;
      held_response <= 0; held_error <= 0; timeout_sync <= 0; timeout_seen <= 0;
    end else begin
      req_sync <= {req_sync[0],req_toggle};
      timeout_sync <= {timeout_sync[0],timeout_toggle};
      timeout_seen <= timeout_sync[1];
      if (d_valid) begin
        held_response <= d_response; held_error <= d_error;
        req_seen <= req_sync[1]; ack_toggle <= req_sync[1];
      end
    end
  end
endmodule
`default_nettype wire
