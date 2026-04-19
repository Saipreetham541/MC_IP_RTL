`timescale 1ns/1ps

module axfdi_fdi_if_tb;

  localparam int FDI_FLIT_WIDTH = 2048;

  logic                       fdi_clk;
  logic                       por_n;
  logic                       fdi_rst_n;

  logic [FDI_FLIT_WIDTH-1:0]  fdi_lp_data;
  logic                       fdi_lp_valid;
  logic                       fdi_lp_irdy;
  logic                       fdi_lp_startofpkt;
  logic                       fdi_lp_endofpkt;
  logic                       fdi_pl_trdy;
  logic [2:0]                 fdi_lp_state_req;
  logic                       fdi_lp_linkerror;

  logic [FDI_FLIT_WIDTH-1:0]  fdi_pl_data;
  logic                       fdi_pl_valid;
  logic                       fdi_pl_irdy;
  logic                       fdi_pl_startofpkt;
  logic                       fdi_pl_endofpkt;
  logic                       fdi_lp_trdy;
  logic [2:0]                 fdi_pl_state_sts;
  logic                       fdi_pl_inband_pres;

  logic [FDI_FLIT_WIDTH-1:0]  flit_tx_data;
  logic                       flit_tx_data_valid;
  logic                       fdi_pktr_tx_sop;
  logic                       fdi_pktr_tx_eop;
  logic                       fdi_tx_ready;

  logic [FDI_FLIT_WIDTH-1:0]  flit_rx_data;
  logic                       flit_rx_data_valid;
  logic                       fdi_depktr_rx_trdy;
  logic                       fdi_depktr_rx_startofpkt;
  logic                       fdi_depktr_rx_endofpkt;

  logic                       credit_init_req;
  logic                       credit_init_done;

  axfdi_fdi_if #(
    .fdi_flit_width(FDI_FLIT_WIDTH)
  ) dut (
    .fdi_clk                  (fdi_clk),
    .por_n                    (por_n),
    .fdi_rst_n                (fdi_rst_n),
    .fdi_lp_data              (fdi_lp_data),
    .fdi_lp_valid             (fdi_lp_valid),
    .fdi_lp_irdy              (fdi_lp_irdy),
    .fdi_lp_startofpkt        (fdi_lp_startofpkt),
    .fdi_lp_endofpkt          (fdi_lp_endofpkt),
    .fdi_pl_trdy              (fdi_pl_trdy),
    .fdi_lp_state_req         (fdi_lp_state_req),
    .fdi_lp_linkerror         (fdi_lp_linkerror),
    .fdi_pl_data              (fdi_pl_data),
    .fdi_pl_valid             (fdi_pl_valid),
    .fdi_pl_irdy              (fdi_pl_irdy),
    .fdi_pl_startofpkt        (fdi_pl_startofpkt),
    .fdi_pl_endofpkt          (fdi_pl_endofpkt),
    .fdi_lp_trdy              (fdi_lp_trdy),
    .fdi_pl_state_sts         (fdi_pl_state_sts),
    .fdi_pl_inband_pres       (fdi_pl_inband_pres),
    .flit_tx_data             (flit_tx_data),
    .flit_tx_data_valid       (flit_tx_data_valid),
    .fdi_pktr_tx_sop          (fdi_pktr_tx_sop),
    .fdi_pktr_tx_eop          (fdi_pktr_tx_eop),
    .fdi_tx_ready             (fdi_tx_ready),
    .flit_rx_data             (flit_rx_data),
    .flit_rx_data_valid       (flit_rx_data_valid),
    .fdi_depktr_rx_trdy       (fdi_depktr_rx_trdy),
    .fdi_depktr_rx_startofpkt (fdi_depktr_rx_startofpkt),
    .fdi_depktr_rx_endofpkt   (fdi_depktr_rx_endofpkt),
    .credit_init_req          (credit_init_req),
    .credit_init_done         (credit_init_done)
  );

  initial fdi_clk = 1'b0;
  always #5 fdi_clk = ~fdi_clk;

  task automatic drive_defaults();
    por_n              = 1'b0;
    fdi_rst_n          = 1'b0;
    fdi_pl_trdy        = 1'b0;
    fdi_pl_data        = '0;
    fdi_pl_valid       = 1'b0;
    fdi_pl_irdy        = 1'b0;
    fdi_pl_startofpkt  = 1'b0;
    fdi_pl_endofpkt    = 1'b0;
    fdi_pl_state_sts   = 3'h0;
    fdi_pl_inband_pres = 1'b0;
    flit_tx_data       = '0;
    flit_tx_data_valid = 1'b0;
    fdi_pktr_tx_sop    = 1'b0;
    fdi_pktr_tx_eop    = 1'b0;
    fdi_depktr_rx_trdy = 1'b0;
    credit_init_done   = 1'b0;
  endtask

  task automatic apply_reset();
    drive_defaults();
    repeat (3) @(posedge fdi_clk);
    por_n <= 1'b1;
    repeat (2) @(posedge fdi_clk);
    fdi_rst_n <= 1'b1;
    @(posedge fdi_clk);
  endtask

  task automatic bring_link_up();
    fdi_pl_inband_pres <= 1'b1;
    @(posedge fdi_clk);
    wait (fdi_lp_state_req == 3'h2);
    fdi_pl_state_sts <= 3'h2;
    @(posedge fdi_clk);
    wait (credit_init_req == 1'b1);
    credit_init_done <= 1'b1;
    @(posedge fdi_clk);
    credit_init_done <= 1'b0;
    fdi_pl_trdy        <= 1'b1;
    fdi_depktr_rx_trdy <= 1'b1;
    repeat (2) @(posedge fdi_clk);
  endtask

  task automatic send_tx_flit(input logic [FDI_FLIT_WIDTH-1:0] data,
                              input logic sop,
                              input logic eop);
    flit_tx_data       <= data;
    flit_tx_data_valid <= 1'b1;
    fdi_pktr_tx_sop    <= sop;
    fdi_pktr_tx_eop    <= eop;
    @(posedge fdi_clk);
    flit_tx_data_valid <= 1'b0;
    fdi_pktr_tx_sop    <= 1'b0;
    fdi_pktr_tx_eop    <= 1'b0;
  endtask

  task automatic send_rx_flit(input logic [FDI_FLIT_WIDTH-1:0] data,
                              input logic sop,
                              input logic eop);
    fdi_pl_data       <= data;
    fdi_pl_valid      <= 1'b1;
    fdi_pl_irdy       <= 1'b1;
    fdi_pl_startofpkt <= sop;
    fdi_pl_endofpkt   <= eop;
    @(posedge fdi_clk);
    fdi_pl_valid      <= 1'b0;
    fdi_pl_irdy       <= 1'b0;
    fdi_pl_startofpkt <= 1'b0;
    fdi_pl_endofpkt   <= 1'b0;
  endtask

  initial begin
    logic [FDI_FLIT_WIDTH-1:0] tx_payload;
    logic [FDI_FLIT_WIDTH-1:0] rx_payload;

    tx_payload = '0;
    rx_payload = '0;
    tx_payload[31:0] = 32'hCAFE_BABE;
    rx_payload[31:0] = 32'h1234_5678;

    apply_reset();

    $display("[%0t] Reset released", $time);
    if (fdi_lp_state_req !== 3'h1) begin
      $error("Expected INIT request after reset, got %0h", fdi_lp_state_req);
    end

    bring_link_up();
    $display("[%0t] Link brought to ACTIVE / TX_RX", $time);

    if (fdi_tx_ready !== 1'b1) begin
      $error("Expected TX ready after link up");
    end

    send_tx_flit(tx_payload, 1'b1, 1'b1);
    @(posedge fdi_clk);
    if (fdi_lp_data[31:0] !== tx_payload[31:0]) begin
      $error("TX data mismatch. Expected %h got %h", tx_payload[31:0], fdi_lp_data[31:0]);
    end
    if ((fdi_lp_valid !== 1'b1) || (fdi_lp_irdy !== 1'b1)) begin
      $error("Expected TX valid and irdy to assert during transfer");
    end
    $display("[%0t] Observed TX transfer: data=%h sop=%0b eop=%0b",
             $time, fdi_lp_data[31:0], fdi_lp_startofpkt, fdi_lp_endofpkt);

    send_rx_flit(rx_payload, 1'b1, 1'b1);
    @(posedge fdi_clk);
    if (flit_rx_data[31:0] !== rx_payload[31:0]) begin
      $error("RX data mismatch. Expected %h got %h", rx_payload[31:0], flit_rx_data[31:0]);
    end
    if (flit_rx_data_valid !== 1'b1) begin
      $error("Expected RX data valid to assert after incoming flit");
    end
    $display("[%0t] Observed RX transfer: data=%h sop=%0b eop=%0b",
             $time, flit_rx_data[31:0], fdi_depktr_rx_startofpkt, fdi_depktr_rx_endofpkt);

    repeat (4) @(posedge fdi_clk);
    $display("[%0t] End of smoke test", $time);
    $finish;
  end

endmodule
