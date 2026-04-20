`timescale 1ns/1ps

module axfdi_credit_mgr_tb;

  localparam int CREDIT_SIZE = 6;
  localparam int RTN_VCN_W   = 2;
  localparam int VCN_W       = 3;
  localparam int RX_THRSHLD  = 16;

  logic                    fdi_clk;
  logic                    fdi_rst_n;
  logic                    por_n;

  logic [RTN_VCN_W-1:0]    tx_credit_rtn_vcn;
  logic [CREDIT_SIZE-1:0]  tx_credit_rtn_cnt;
  logic                    tx_credit_rtn_valid;

  logic                    rx_credit_cnsmd_incr_flag;
  logic [VCN_W-1:0]        rx_credit_cnsmd_incr_vcn;

  logic [VCN_W-1:0]        tx_credit_vcn;
  logic                    tx_credit_decr_flag;

  logic                    tx_vc_cpl_credit_ind;
  logic                    tx_vc_np_credit_ind;
  logic                    credit_rtn_opcode_en;
  logic [CREDIT_SIZE-1:0]  rx_credit_rtn_cnt;
  logic [RTN_VCN_W-1:0]    rx_credit_rtn_vcn;
  logic                    credit_rtn_piggy_en;

  logic                    pending_tx_available;
  logic                    credit_rtn_done;
  logic                    credit_init_req;
  logic                    credit_init_done;

  int unsigned             checks_run;
  int unsigned             checks_failed;

  axfdi_credit_mgr #(
    .credit_size (CREDIT_SIZE),
    .rtn_vcn_w   (RTN_VCN_W),
    .vcn_w       (VCN_W)
  ) dut (
    .fdi_clk                   (fdi_clk),
    .fdi_rst_n                 (fdi_rst_n),
    .por_n                     (por_n),
    .tx_credit_rtn_vcn         (tx_credit_rtn_vcn),
    .tx_credit_rtn_cnt         (tx_credit_rtn_cnt),
    .tx_credit_rtn_valid       (tx_credit_rtn_valid),
    .rx_credit_cnsmd_incr_flag (rx_credit_cnsmd_incr_flag),
    .rx_credit_cnsmd_incr_vcn  (rx_credit_cnsmd_incr_vcn),
    .tx_credit_vcn             (tx_credit_vcn),
    .tx_credit_decr_flag       (tx_credit_decr_flag),
    .tx_vc_cpl_credit_ind      (tx_vc_cpl_credit_ind),
    .tx_vc_np_credit_ind       (tx_vc_np_credit_ind),
    .credit_rtn_opcode_en      (credit_rtn_opcode_en),
    .rx_credit_rtn_cnt         (rx_credit_rtn_cnt),
    .rx_credit_rtn_vcn         (rx_credit_rtn_vcn),
    .credit_rtn_piggy_en       (credit_rtn_piggy_en),
    .pending_tx_available      (pending_tx_available),
    .credit_rtn_done           (credit_rtn_done),
    .credit_init_req           (credit_init_req),
    .credit_init_done          (credit_init_done)
  );

  initial fdi_clk = 1'b0;
  always #5 fdi_clk = ~fdi_clk;

  task automatic drive_defaults();
    por_n                     = 1'b0;
    fdi_rst_n                 = 1'b0;
    tx_credit_rtn_vcn         = '0;
    tx_credit_rtn_cnt         = '0;
    tx_credit_rtn_valid       = 1'b0;
    rx_credit_cnsmd_incr_flag = 1'b0;
    rx_credit_cnsmd_incr_vcn  = '0;
    tx_credit_vcn             = '0;
    tx_credit_decr_flag       = 1'b0;
    pending_tx_available      = 1'b0;
    credit_rtn_done           = 1'b0;
    credit_init_req           = 1'b0;
  endtask

  task automatic apply_reset();
    drive_defaults();
    repeat (3) @(posedge fdi_clk);
    por_n = 1'b1;
    repeat (2) @(posedge fdi_clk);
    fdi_rst_n = 1'b1;
    @(posedge fdi_clk);
  endtask

  task automatic sanitize_internal_state();
    // The current RTL leaves several internal credit-tracking registers without reset.
    // Seed them here so directed tests can observe deterministic behavior.
    dut.rx_cpl_credit_cnsmd            = '0;
    dut.rx_np_credit_cnsmd             = '0;
    dut.r_rx_cpl_credit_init           = '0;
    dut.r_rx_np_credit_init            = '0;
    dut.r_rx_cpl_credit_init_en        = 1'b0;
    dut.r_rx_np_credit_init_en         = 1'b0;
    dut.r_rx_cpl_credit_init_done      = 1'b0;
    dut.r_rx_np_credit_init_done       = 1'b0;
    dut.r_rx_credit_rtn_cnt            = '0;
    dut.r_rx_credit_rtn_vcn            = '0;
    dut.r_rx_cpl_credit_cnsmd_rtn_done = 1'b0;
    dut.r_rx_np_credit_cnsmd_rtn_done  = 1'b0;
    dut.r_rx_cpl_credit_cnsmd_rtn_flag = 1'b0;
    dut.r_rx_np_credit_cnsmd_rtn_flag  = 1'b0;
    @(posedge fdi_clk);
  endtask

  task automatic expect_bit(input logic actual,
                            input logic expected,
                            input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=%0b actual=%0b", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_vec(input logic [CREDIT_SIZE-1:0] actual,
                            input logic [CREDIT_SIZE-1:0] expected,
                            input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
    end
  endtask

  task automatic expect_vcn(input logic [VCN_W-1:0] actual,
                            input logic [VCN_W-1:0] expected,
                            input string msg);
    begin
      checks_run++;
      if (actual !== expected) begin
        checks_failed++;
        $error("%s expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
    end
  endtask

  task automatic pulse_tx_credit_return(input logic [RTN_VCN_W-1:0] vcn,
                                        input logic [CREDIT_SIZE-1:0] cnt);
    begin
      tx_credit_rtn_vcn   = vcn;
      tx_credit_rtn_cnt   = cnt;
      tx_credit_rtn_valid = 1'b1;
      @(posedge fdi_clk);
      tx_credit_rtn_valid = 1'b0;
      tx_credit_rtn_vcn   = '0;
      tx_credit_rtn_cnt   = '0;
      @(posedge fdi_clk);
    end
  endtask

  task automatic pulse_tx_credit_use(input logic [VCN_W-1:0] vcn);
    begin
      tx_credit_vcn       = vcn;
      tx_credit_decr_flag = 1'b1;
      @(posedge fdi_clk);
      tx_credit_decr_flag = 1'b0;
      tx_credit_vcn       = '0;
      @(posedge fdi_clk);
    end
  endtask

  task automatic pulse_rx_credit_consume(input logic [VCN_W-1:0] vcn,
                                         input int unsigned count);
    int unsigned idx;
    begin
      for (idx = 0; idx < count; idx++) begin
        rx_credit_cnsmd_incr_vcn  = vcn;
        rx_credit_cnsmd_incr_flag = 1'b1;
        @(posedge fdi_clk);
        rx_credit_cnsmd_incr_flag = 1'b0;
        rx_credit_cnsmd_incr_vcn  = '0;
        @(posedge fdi_clk);
      end
    end
  endtask

  task automatic pulse_credit_rtn_done();
    begin
      credit_rtn_done = 1'b1;
      @(posedge fdi_clk);
      credit_rtn_done = 1'b0;
      @(posedge fdi_clk);
    end
  endtask

  task automatic test_tx_credit_accounting();
    begin
      $display("[%0t] TEST 1: TX credit grant/use accounting", $time);
      apply_reset();
      sanitize_internal_state();

      expect_bit(tx_vc_np_credit_ind, 1'b1, "NP credit indicator should show empty after reset");
      expect_bit(tx_vc_cpl_credit_ind, 1'b1, "CPL credit indicator should show empty after reset");

      pulse_tx_credit_return(2'h0, 6'd5);
      pulse_tx_credit_return(2'h1, 6'd3);

      expect_vec(dut.r_tx_vc_np_credit_cnt, 6'd5, "NP TX credit count after remote grant");
      expect_vec(dut.r_tx_vc_cpl_credit_cnt, 6'd3, "CPL TX credit count after remote grant");
      expect_bit(tx_vc_np_credit_ind, 1'b0, "NP credit indicator should clear after grant");
      expect_bit(tx_vc_cpl_credit_ind, 1'b0, "CPL credit indicator should clear after grant");

      pulse_tx_credit_use(3'h0);
      pulse_tx_credit_use(3'h1);

      expect_vec(dut.r_tx_vc_np_credit_cnt, 6'd4, "NP TX credit count should decrement on transmit");
      expect_vec(dut.r_tx_vc_cpl_credit_cnt, 6'd2, "CPL TX credit count should decrement on transmit");
    end
  endtask

  task automatic test_credit_init_sequence();
    begin
      $display("[%0t] TEST 2: credit initialization should emit CPL then NP grants", $time);
      apply_reset();
      sanitize_internal_state();

      pulse_tx_credit_return(2'h0, 6'd8);
      pulse_tx_credit_return(2'h1, 6'd8);

      credit_init_req = 1'b1;
      @(posedge fdi_clk);
      credit_init_req = 1'b0;
      @(posedge fdi_clk);

      expect_bit(credit_rtn_opcode_en, 1'b1, "Credit init should request standalone credit return");
      expect_vec(rx_credit_rtn_cnt, 6'd32, "First init credit grant count");
      expect_vcn({1'b0, rx_credit_rtn_vcn}, 3'h1, "First init credit grant VCN should be CPL");

      pulse_credit_rtn_done();

      expect_bit(credit_rtn_opcode_en, 1'b1, "Credit init should continue to second VCN");
      expect_vec(rx_credit_rtn_cnt, 6'd32, "Second init credit grant count");
      expect_vcn({1'b0, rx_credit_rtn_vcn}, 3'h0, "Second init credit grant VCN should be NP");

      pulse_credit_rtn_done();
      expect_bit(credit_init_done, 1'b1, "Credit init should complete after both grants and remote credits");
    end
  endtask

  task automatic test_standalone_credit_return();
    begin
      $display("[%0t] TEST 3: standalone credit return threshold/clear path", $time);
      apply_reset();
      sanitize_internal_state();

      expect_bit(credit_rtn_opcode_en, 1'b0, "Credit return opcode should stay low below threshold");
      expect_bit(credit_rtn_piggy_en, 1'b0, "Piggyback should stay low below threshold");

      pulse_rx_credit_consume(3'h0, RX_THRSHLD-1);

      expect_bit(credit_rtn_opcode_en, 1'b0, "Standalone credit return should not trigger before threshold");
      expect_bit(credit_rtn_piggy_en, 1'b0, "Piggyback should stay low before threshold");

      pulse_rx_credit_consume(3'h0, 1);

      expect_bit(credit_rtn_opcode_en, 1'b1, "Standalone credit return should trigger at threshold");
      expect_bit(credit_rtn_piggy_en, 1'b0, "Standalone path should be selected when no TX is pending");
      expect_vec(rx_credit_rtn_cnt, RX_THRSHLD[5:0], "Returned credit count should match consumed NP credits");
      expect_vcn({1'b0, rx_credit_rtn_vcn}, 3'h0, "Returned credit VCN should be NP");

      pulse_credit_rtn_done();
      expect_vec(dut.rx_np_credit_cnsmd, '0, "NP consumed-credit counter should clear after credit return ack");
    end
  endtask

  task automatic test_piggyback_credit_return();
    begin
      $display("[%0t] TEST 4: piggyback gating when TX traffic is pending", $time);
      apply_reset();
      sanitize_internal_state();

      pending_tx_available   = 1'b1;
      dut.rx_cpl_credit_cnsmd = RX_THRSHLD[CREDIT_SIZE-1:0];
      @(posedge fdi_clk);

      expect_bit(credit_rtn_piggy_en, 1'b1, "Piggyback enable should assert when TX is pending");
      expect_bit(credit_rtn_opcode_en, 1'b0, "Standalone opcode should stay low when piggybacking");
      expect_vec(rx_credit_rtn_cnt, RX_THRSHLD[5:0], "Piggyback credit count should reflect CPL credits");
      expect_vcn({1'b0, rx_credit_rtn_vcn}, 3'h1, "Piggyback credit VCN should be CPL");

      pending_tx_available   = 1'b0;
      dut.rx_cpl_credit_cnsmd = '0;
      @(posedge fdi_clk);
    end
  endtask

  initial begin
    checks_run    = 0;
    checks_failed = 0;

    test_tx_credit_accounting();
    test_credit_init_sequence();
    test_standalone_credit_return();
    test_piggyback_credit_return();

    repeat (4) @(posedge fdi_clk);
    $display("[%0t] Credit manager TB completed: checks_run=%0d checks_failed=%0d",
             $time, checks_run, checks_failed);
    if (checks_failed != 0) begin
      $fatal(1, "axfdi_credit_mgr_tb detected %0d failing checks", checks_failed);
    end
    $finish;
  end

endmodule
