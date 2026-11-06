`timescale 1ns/1ps

// Minimal AXI -> subordinate -> CDC -> backend/core -> DFI memory round trip.
// One 32-byte beat becomes eight 32-bit memory word commands.
// No UVM, hierarchical forces, PHY initialization or vendor DDR model.
module tb_mc_axi_smoke;
  localparam logic [39:0] TEST_ADDR = 40'h0000000800;
  localparam logic [255:0] TEST_DATA = {
    32'h76543210, 32'hFEDCBA98, 32'h55AA55AA, 32'hA5A55A5A,
    32'hCAFEBABE, 32'hDEADBEEF, 32'h89ABCDEF, 32'h01234567
  };
  logic aclk=0, aresetn=0, dfi_clk=0, ctl_reset_n=0;
  logic [7:0] s_axi_awid;
  logic [39:0] s_axi_awaddr;
  logic [7:0] s_axi_awlen;
  logic [2:0] s_axi_awsize;
  logic [1:0] s_axi_awburst;
  logic  s_axi_awlock;
  logic [3:0] s_axi_awqos;
  logic [3:0] s_axi_awcache;
  logic [2:0] s_axi_awprot;
  logic  s_axi_awvalid;
  logic  s_axi_awready;
  logic [255:0] s_axi_wdata;
  logic [31:0] s_axi_wstrb;
  logic  s_axi_wlast;
  logic  s_axi_wvalid;
  logic  s_axi_wready;
  logic [7:0] s_axi_bid;
  logic [1:0] s_axi_bresp;
  logic  s_axi_bvalid;
  logic  s_axi_bready;
  logic [7:0] s_axi_arid;
  logic [39:0] s_axi_araddr;
  logic [7:0] s_axi_arlen;
  logic [2:0] s_axi_arsize;
  logic [1:0] s_axi_arburst;
  logic  s_axi_arlock;
  logic [3:0] s_axi_arqos;
  logic [3:0] s_axi_arcache;
  logic [2:0] s_axi_arprot;
  logic  s_axi_arvalid;
  logic  s_axi_arready;
  logic [7:0] s_axi_rid;
  logic [255:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic  s_axi_rlast;
  logic  s_axi_rvalid;
  logic  s_axi_rready;
  logic [15:0] dfi_row_val;
  logic [15:0][21:0] dfi_row;
  logic [15:0] dfi_col_val;
  logic [15:0][11:0] dfi_col;
  logic [15:0][63:0] dfi_wrdata;
  logic [15:0][7:0] dfi_wrdata_mask;
  logic [15:0][1:0] dfi_wrdata_en;
  logic [15:0][1:0] dfi_rddata_en;
  logic [15:0][63:0] dfi_rddata;
  logic [15:0][1:0] dfi_rddata_valid;
  logic [31:0] err_cmdq_overflow;
  logic [31:0] err_wdb_overflow;
  logic [31:0] err_ref_deadline_miss;
  mc16x2 dut (.*);
  // The updated top inserts u_axi_sub ahead of the five CDC FIFOs.
  // Check all forwarded fields and reverse-direction READY/response signals.
  always @(posedge aclk) begin : check_subordinate_path
    if (aresetn) begin
      if ({s_axi_awid, s_axi_awaddr, s_axi_awlen, s_axi_awsize, s_axi_awburst, s_axi_awlock, s_axi_awqos, s_axi_awcache, s_axi_awprot, s_axi_awvalid, s_axi_awready} !==
          {dut.sub_awid, dut.sub_awaddr, dut.sub_awlen, dut.sub_awsize, dut.sub_awburst, dut.sub_awlock, dut.sub_awqos, dut.sub_awcache, dut.sub_awprot, dut.sub_awvalid, dut.sub_awready})
        $fatal(1, "AXI AW fields changed across u_axi_sub");
      if ({s_axi_wdata, s_axi_wstrb, s_axi_wlast, s_axi_wvalid, s_axi_wready} !==
          {dut.sub_wdata, dut.sub_wstrb, dut.sub_wlast, dut.sub_wvalid, dut.sub_wready})
        $fatal(1, "AXI W fields changed across u_axi_sub");
      if ({s_axi_bid, s_axi_bresp, s_axi_bvalid, s_axi_bready} !==
          {dut.sub_bid, dut.sub_bresp, dut.sub_bvalid, dut.sub_bready})
        $fatal(1, "AXI B fields changed across u_axi_sub");
      if ({s_axi_arid, s_axi_araddr, s_axi_arlen, s_axi_arsize, s_axi_arburst, s_axi_arlock, s_axi_arqos, s_axi_arcache, s_axi_arprot, s_axi_arvalid, s_axi_arready} !==
          {dut.sub_arid, dut.sub_araddr, dut.sub_arlen, dut.sub_arsize, dut.sub_arburst, dut.sub_arlock, dut.sub_arqos, dut.sub_arcache, dut.sub_arprot, dut.sub_arvalid, dut.sub_arready})
        $fatal(1, "AXI AR fields changed across u_axi_sub");
      if ({s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast, s_axi_rvalid, s_axi_rready} !==
          {dut.sub_rid, dut.sub_rdata, dut.sub_rresp, dut.sub_rlast, dut.sub_rvalid, dut.sub_rready})
        $fatal(1, "AXI R fields changed across u_axi_sub");
    end
  end

  // The former field-decoder module has been folded into the CDC/backend.
  // Check the CDC's public decoded fields whenever an address is consumed.
  always @(posedge dfi_clk) begin : check_cdc_address_fields
    if (ctl_reset_n) begin
      // These attributes stay constant throughout this test. Check that the
      // updated subordinate and FIFO packing preserve their nonzero values.
      if (dut.m_awvalid && dut.m_awready &&
          {dut.m_awqos, dut.m_awcache, dut.m_awprot} !== {4'hA, 4'h6, 3'h5})
        $fatal(1, "Write attributes changed across subordinate/CDC");
      if (dut.m_arvalid && dut.m_arready &&
          {dut.m_arqos, dut.m_arcache, dut.m_arprot} !== {4'h5, 4'h9, 3'h3})
        $fatal(1, "Read attributes changed across subordinate/CDC");
      if (dut.m_awvalid && dut.m_awready &&
          {dut.u_axi_cdc.m_aw_ch_sel, dut.u_axi_cdc.m_aw_pc_sel,
           dut.u_axi_cdc.m_aw_row_addr, dut.u_axi_cdc.m_aw_bank_group,
           dut.u_axi_cdc.m_aw_bank_addr, dut.u_axi_cdc.m_aw_col_addr} !==
          {dut.m_awaddr[29:26], dut.m_awaddr[25], dut.m_awaddr[24:11],
           dut.m_awaddr[10:9], dut.m_awaddr[8:7], dut.m_awaddr[6:2]})
        $fatal(1, "CDC write address field decode mismatch");
      if (dut.m_arvalid && dut.m_arready &&
          {dut.u_axi_cdc.m_ar_ch_sel, dut.u_axi_cdc.m_ar_pc_sel,
           dut.u_axi_cdc.m_ar_row_addr, dut.u_axi_cdc.m_ar_bank_group,
           dut.u_axi_cdc.m_ar_bank_addr, dut.u_axi_cdc.m_ar_col_addr} !==
          {dut.m_araddr[29:26], dut.m_araddr[25], dut.m_araddr[24:11],
           dut.m_araddr[10:9], dut.m_araddr[8:7], dut.m_araddr[6:2]})
        $fatal(1, "CDC read address field decode mismatch");
    end
  end

  // Unrelated clocks exercise the real AXI CDC path.
  always #1.7 aclk = ~aclk;
  always #0.5 dfi_clk = ~dfi_clk;

  typedef enum logic [2:0] {RESET, WRITE, WRITE_RESPONSE, READ, READ_RESPONSE, DONE} phase_t;
  phase_t phase = RESET;
  logic [31:0] memory [0:7];
  logic [13:0] open_row;
  logic bank_open;
  logic [31:0] pending_data;
  int return_delay, writes_seen, reads_seen, acts_seen;

  // Tiny behavioral memory: channel 0 / PC0 / bank 0 / row 1, columns 0..7.
  // Store ONLY data observed on DFI. Read returns come ONLY from this memory.
  // The expected AXI pattern is never used to manufacture read data.
  // Registered DFI outputs are sampled at the falling edge to avoid races.
  always @(negedge dfi_clk) begin
    if (!ctl_reset_n) begin
      dfi_rddata = '0;
      dfi_rddata_valid = '0;
      bank_open = 0;
      open_row = '0;
      pending_data = '0;
      return_delay = 0;
      writes_seen = 0;
      reads_seen = 0;
      acts_seen = 0;
      for (int i=0; i<8; i++) memory[i] = '0;
    end else begin
      dfi_rddata_valid = '0;
      if ({err_cmdq_overflow, err_wdb_overflow, err_ref_deadline_miss} !== '0)
        $fatal(1, "Controller reported an error");
      if (dfi_row_val[15:1] !== '0 || dfi_col_val[15:1] !== '0 ||
          dfi_wrdata_en[15:1] !== '0 || dfi_rddata_en[15:1] !== '0)
        $fatal(1, "Unexpected traffic outside channel 0");

      // Return a requested word after five DFI clocks.
      if (return_delay > 0) begin
        return_delay--;
        if (return_delay == 0) begin
          dfi_rddata[0][31:0] = pending_data;
          dfi_rddata_valid[0] = 2'b01;
        end
      end

      if (dfi_row_val[0]) begin
        // {PC, opcode, bank-group, bank, row}; 001 means ACT.
        if (dfi_row[0] !== {1'b0, 3'b001, 2'b00, 2'b00, 14'h0001})
          $fatal(1, "Unexpected row command: %h", dfi_row[0]);
        open_row = dfi_row[0][13:0];
        bank_open = 1;
        acts_seen++;
        $display("[%0t] DDR model: ACT row=%h", $time, open_row);
      end

      if (dfi_col_val[0]) begin
        // {PC, opcode, bank-group, bank, column}; 10=WR, 01=RD.
        if (!bank_open || open_row !== 14'h0001 ||
            dfi_col[0][11] !== 1'b0 || dfi_col[0][8:5] !== 4'b0000 ||
            $isunknown(dfi_col[0][4:0]) || dfi_col[0][4:0] > 7)
          $fatal(1, "Unexpected memory address: %h", dfi_col[0]);
        case (dfi_col[0][10:9])
          2'b10: begin
            if (writes_seen >= 8 || int'(dfi_col[0][4:0]) != writes_seen ||
                dfi_wrdata_en[0] !== 2'b01 || dfi_rddata_en[0] !== 2'b00 ||
                dfi_wrdata_mask[0][3:0] !== 4'b0000)
              $fatal(1, "Unexpected write column, lane or byte mask");
            memory[dfi_col[0][2:0]] = dfi_wrdata[0][31:0];
            $display("[%0t] AXI -> DDR: column=%0d data=%08h", $time,
                     dfi_col[0][4:0], dfi_wrdata[0][31:0]);
            writes_seen++;
          end
          2'b01: begin
            if (reads_seen >= 8 || int'(dfi_col[0][4:0]) != reads_seen ||
                dfi_rddata_en[0] !== 2'b01 || dfi_wrdata_en[0] !== 2'b00 ||
                return_delay != 0 || writes_seen != 8)
              $fatal(1, "Unexpected read column, lane or outstanding request");
            pending_data = memory[dfi_col[0][2:0]];
            return_delay = 5;
            reads_seen++;
            $display("[%0t] DDR -> AXI: column=%0d data=%08h", $time,
                     dfi_col[0][4:0], pending_data);
          end
          default: $fatal(1, "Unexpected column opcode");
        endcase
      end else if (dfi_wrdata_en[0] !== '0 || dfi_rddata_en[0] !== '0)
        $fatal(1, "DFI data enable without column command");
    end
  end

  initial begin
    $timeformat(-9, 1, " ns", 10);
    $dumpfile("mc_axi_smoke.vcd");
    // Include DUT-level sub_* / m_* / decoded-core buses for the updated path.
    $dumpvars(2, tb_mc_axi_smoke);
    s_axi_awid=8'h11; s_axi_awaddr=TEST_ADDR;
    s_axi_awlen=0; s_axi_awsize=5; s_axi_awburst=1;
    s_axi_awlock=0; s_axi_awqos=4'hA; s_axi_awcache=4'h6; s_axi_awprot=3'h5;
    s_axi_awvalid=0;
    s_axi_wdata=TEST_DATA; s_axi_wstrb='1; s_axi_wlast=1; s_axi_wvalid=0;
    s_axi_bready=0;
    s_axi_arid=8'h22; s_axi_araddr=TEST_ADDR;
    s_axi_arlen=0; s_axi_arsize=5; s_axi_arburst=1;
    s_axi_arlock=0; s_axi_arqos=4'h5; s_axi_arcache=4'h9; s_axi_arprot=3'h3;
    s_axi_arvalid=0; s_axi_rready=0;

    // Both resets start asserted. Release away from sampling edges in each domain.
    repeat (8) @(negedge aclk);
    @(negedge dfi_clk); #0.001; ctl_reset_n = 1;
    @(negedge aclk); aresetn = 1;

    phase = WRITE;
    $display("Write one AXI beat: address=%010h data=%064h", TEST_ADDR, TEST_DATA);
    // AW and W handshake independently, as required by AXI.
    fork
      begin
        @(negedge aclk); s_axi_awvalid=1;
        do @(posedge aclk); while (s_axi_awready !== 1'b1);
        @(negedge aclk); s_axi_awvalid=0;
      end
      begin
        @(negedge aclk); s_axi_wvalid=1;
        do @(posedge aclk); while (s_axi_wready !== 1'b1);
        @(negedge aclk); s_axi_wvalid=0;
      end
    join

    phase = WRITE_RESPONSE;
    @(negedge aclk); s_axi_bready=1;
    do @(posedge aclk); while (s_axi_bvalid !== 1'b1);
    if (s_axi_bid !== 8'h11 || s_axi_bresp !== 2'b00 || writes_seen != 8)
      $fatal(1, "Write failed: BID=%h BRESP=%h memory writes=%0d",
             s_axi_bid, s_axi_bresp, writes_seen);
    for (int i=0; i<8; i++)
      if (memory[i] !== TEST_DATA[i*32 +: 32])
        $fatal(1, "DDR memory word %0d mismatch", i);
    $display("[%0t] AXI write response OK; all eight DDR words checked", $time);
    @(negedge aclk); s_axi_bready=0;

    phase = READ;
    @(negedge aclk); s_axi_arvalid=1;
    do @(posedge aclk); while (s_axi_arready !== 1'b1);
    @(negedge aclk); s_axi_arvalid=0;
    phase = READ_RESPONSE;
    s_axi_rready=1;
    do @(posedge aclk); while (s_axi_rvalid !== 1'b1);
    if (s_axi_rid !== 8'h22 || s_axi_rresp !== 2'b00 || s_axi_rlast !== 1'b1)
      $fatal(1, "Read response failed: RID=%h RRESP=%h RLAST=%b",
             s_axi_rid, s_axi_rresp, s_axi_rlast);
    if (s_axi_rdata !== TEST_DATA)
      $fatal(1, "Readback mismatch: got=%064h expected=%064h", s_axi_rdata, TEST_DATA);
    if (acts_seen != 1 || reads_seen != 8 || return_delay != 0)
      $fatal(1, "Missing or extra memory commands/returns");
    $display("[%0t] AXI readback=%064h", $time, s_axi_rdata);
    @(negedge aclk); s_axi_rready=0;
    // Allow a short quiet window to catch extra responses or commands.
    repeat (8) begin
      @(posedge aclk);
      if (s_axi_bvalid !== 1'b0 || s_axi_rvalid !== 1'b0)
        $fatal(1, "Unexpected extra AXI response");
    end
    phase = DONE;
    $display("PASS: one AXI write and one AXI read; eight DDR writes and reads; data matches.");
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "Timeout waiting for AXI/DDR transaction in phase %0d", phase);
  end
endmodule
