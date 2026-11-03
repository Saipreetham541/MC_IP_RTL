`default_nettype none
`timescale 1ns/1ps

module mc_apb_if (
  input logic pclk, presetn,
  input logic [19:0] paddr,
  input logic psel, penable, pwrite,
  input logic [31:0] pwdata,
  input logic [3:0] pstrb,
  output logic pready,
  output logic [31:0] prdata,
  output logic pslverr,
  output logic request_valid,
  input logic request_ready,
  output logic [19:0] request_addr,
  output logic request_write,
  output logic [31:0] request_data,
  output logic [3:0] request_strb,
  input logic response_valid,
  input logic [31:0] response_data,
  input logic response_error,
  output logic timeout_toggle
);
  typedef enum logic [1:0] {IDLE, SEND, WAIT_RESPONSE, RESPOND} state_t;
  state_t state;
  logic [4:0] wait_count;
  assign request_valid = state == SEND && psel && penable;
  assign pready = state == RESPOND && psel && penable;
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      state <= IDLE; wait_count <= 0; prdata <= 0; pslverr <= 0;
      request_addr <= 0; request_write <= 0; request_data <= 0;
      request_strb <= 0; timeout_toggle <= 0;
    end else begin
      case (state)
        IDLE: begin
          wait_count <= 0; pslverr <= 0;
          if (psel && !penable) begin
            request_addr <= paddr; request_write <= pwrite;
            request_data <= pwdata; request_strb <= pstrb; state <= SEND;
          end
        end
        SEND, WAIT_RESPONSE: begin
          if (!psel) state <= IDLE;
          else if (response_valid && state == WAIT_RESPONSE) begin
            prdata <= response_data; pslverr <= response_error; state <= RESPOND;
          end else if (penable) begin
            if (wait_count == 15) begin
              prdata <= 0; pslverr <= 1; state <= RESPOND;
              timeout_toggle <= ~timeout_toggle;
            end else begin
              wait_count <= wait_count+1'b1;
              if (state == SEND && request_ready) state <= WAIT_RESPONSE;
            end
          end
        end
        RESPOND: if (!psel || penable) state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
