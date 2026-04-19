`timescale 1ns/1ps

module axfdi_depacketizer_tb;

  localparam int FDI_FLIT_WIDTH   = 2048;
  localparam int AXI_DATA_W       = 1024;
  localparam int AXI_BURST_LEN_W  = 8;
  localparam int AXI_BURST_TYPE_W = 2;
  localparam int AXI_BURST_SIZE_W = 3;
  localparam int AXI_RESP_W       = 2;
  localparam int AXI_ADDR_W       = 40;
  localparam int AXI_WSTRB_W      = 128;
  localparam int AXI_ID_W         = 8;
  localparam int CREDIT_SIZE      = 6;
  localparam int RTN_VCN_W        = 2;
  localparam int VCN_W            = 3;

  logic                         fdi_clk;
  logic                         fdi_rst_n;
  logic                         por_n;
  logic [FDI_FLIT_WIDTH-1:0]    flit_rx_data;
  logic                         flit_rx_data_valid;
  logic                         fdi_depktr_rx_startofpkt;
  logic                         fdi_depktr_rx_endofpkt;
  logic                         fdi_depktr_rx_trdy;

  logic [RTN_VCN_W-1:0]         depktr_crdtmgr_credit_vcn;
  logic [CREDIT_SIZE-1:0]       depktr_crdtmgr_credit_cnt;
  logic                         depktr_crdtmgr_rtn_valid;
  logic                         depktr_crdtmgr_credit_rx_incr;
  logic [VCN_W-1:0]             depktr_crdtmgr_rx_vcn;

  logic [AXI_DATA_W-1:0]        depktr_portrtr_axi_data;
  logic [AXI_BURST_LEN_W-1:0]   depktr_portrtr_axi_burst_len;
  logic [AXI_BURST_TYPE_W-1:0]  depktr_portrtr_axi_burst_type;
  logic [AXI_BURST_SIZE_W-1:0]  depktr_portrtr_axi_burst_size;
  logic [AXI_RESP_W-1:0]        depktr_portrtr_axi_resp;
  logic [AXI_ADDR_W-1:0]        depktr_portrtr_axi_addr;
  logic [AXI_WSTRB_W-1:0]       depktr_portrtr_axi_wstrb;
  logic                         portrtr_depktr_bakpres;
  logic                         depktr_portrtr_flit_endofpkt;
  logic                         depktr_portrtr_flit_startofpkt;
  logic                         portrtr_depktr_read_done;
  logic                         depktr_portrtr_write_req_valid;
  logic                         depktr_portrtr_read_req_valid;
  logic                         depktr_portrtr_write_resp_valid;
  logic                         depktr_portrtr_read_resp_valid;
  logic                         depktr_portrtr_port_id;
  logic [AXI_ID_W-1:0]          depktr_portrtr_txn_id;
  logic                         depktr_cmpltkr_resp_valid;
  logic                         depktr_cmpltkr_vcn;
  logic [AXI_ID_W-1:0]          depktr_cmpltkr_txn_id;
  logic                         cmpltkr_depktr_port_id;
  logic                         cmpltkr_depktr_port_id_valid;

  axfdi_depacketizer #(
    .fdi_flit_width      (FDI_FLIT_WIDTH),
    .axi_data_w          (AXI_DATA_W),
    .axi_burst_len_w     (AXI_BURST_LEN_W),
    .axi_burst_type_w    (AXI_BURST_TYPE_W),
    .axi_burst_size_w    (AXI_BURST_SIZE_W),
    .axi_resp_w          (AXI_RESP_W),
    .axi_addr_w          (AXI_ADDR_W),
    .axi_wstrb_w         (AXI_WSTRB_W),
    .axi_id_w            (AXI_ID_W),
    .credit_size         (CREDIT_SIZE),
    .rtn_vcn_w           (RTN_VCN_W),
    .vcn_w               (VCN_W)
  ) dut (
    .fdi_clk                     (fdi_clk),
    .fdi_rst_n                   (fdi_rst_n),
    .por_n                       (por_n),
    .flit_rx_data                (flit_rx_data),
    .flit_rx_data_valid          (flit_rx_data_valid),
    .fdi_depktr_rx_startofpkt    (fdi_depktr_rx_startofpkt),
    .fdi_depktr_rx_endofpkt      (fdi_depktr_rx_endofpkt),
    .fdi_depktr_rx_trdy          (fdi_depktr_rx_trdy),
    .depktr_crdtmgr_credit_vcn   (depktr_crdtmgr_credit_vcn),
    .depktr_crdtmgr_credit_cnt   (depktr_crdtmgr_credit_cnt),
    .depktr_crdtmgr_rtn_valid    (depktr_crdtmgr_rtn_valid),
    .depktr_crdtmgr_credit_rx_incr(depktr_crdtmgr_credit_rx_incr),
    .depktr_crdtmgr_rx_vcn       (depktr_crdtmgr_rx_vcn),
    .depktr_portrtr_axi_data     (depktr_portrtr_axi_data),
    .depktr_portrtr_axi_burst_len(depktr_portrtr_axi_burst_len),
    .depktr_portrtr_axi_burst_type(depktr_portrtr_axi_burst_type),
    .depktr_portrtr_axi_burst_size(depktr_portrtr_axi_burst_size),
    .depktr_portrtr_axi_resp     (depktr_portrtr_axi_resp),
    .depktr_portrtr_axi_addr     (depktr_portrtr_axi_addr),
    .depktr_portrtr_axi_wstrb    (depktr_portrtr_axi_wstrb),
    .portrtr_depktr_bakpres      (portrtr_depktr_bakpres),
    .depktr_portrtr_flit_endofpkt(depktr_portrtr_flit_endofpkt),
    .depktr_portrtr_flit_startofpkt(depktr_portrtr_flit_startofpkt),
    .portrtr_depktr_read_done    (portrtr_depktr_read_done),
    .depktr_portrtr_write_req_valid(depktr_portrtr_write_req_valid),
    .depktr_portrtr_read_req_valid(depktr_portrtr_read_req_valid),
    .depktr_portrtr_write_resp_valid(depktr_portrtr_write_resp_valid),
    .depktr_portrtr_read_resp_valid(depktr_portrtr_read_resp_valid),
    .depktr_portrtr_port_id      (depktr_portrtr_port_id),
    .depktr_portrtr_txn_id       (depktr_portrtr_txn_id),
    .depktr_cmpltkr_resp_valid   (depktr_cmpltkr_resp_valid),
    .depktr_cmpltkr_vcn          (depktr_cmpltkr_vcn),
    .depktr_cmpltkr_txn_id       (depktr_cmpltkr_txn_id),
    .cmpltkr_depktr_port_id      (cmpltkr_depktr_port_id),
    .cmpltkr_depktr_port_id_valid(cmpltkr_depktr_port_id_valid)
  );

  initial fdi_clk = 1'b0;
  always #5 fdi_clk = ~fdi_clk;

  task automatic drive_defaults();
    por_n                        = 1'b0;
    fdi_rst_n                    = 1'b0;
    flit_rx_data                 = '0;
    flit_rx_data_valid           = 1'b0;
    fdi_depktr_rx_startofpkt     = 1'b0;
    fdi_depktr_rx_endofpkt       = 1'b0;
    portrtr_depktr_bakpres       = 1'b0;
    portrtr_depktr_read_done     = 1'b0;
    cmpltkr_depktr_port_id       = 1'b0;
    cmpltkr_depktr_port_id_valid = 1'b0;
  endtask

  task automatic apply_reset();
    drive_defaults();
    repeat (3) @(posedge fdi_clk);
    por_n <= 1'b1;
    repeat (2) @(posedge fdi_clk);
    fdi_rst_n <= 1'b1;
    @(posedge fdi_clk);
  endtask

  function automatic [FDI_FLIT_WIDTH-1:0] build_fdi_flit(
    input logic [2:0]               vcn,
    input logic [3:0]               opcode,
    input logic                     port_id,
    input logic [7:0]               txn_id,
    input logic [7:0]               burst_len,
    input logic [1:0]               burst_type,
    input logic [2:0]               burst_size,
    input logic [1:0]               resp,
    input logic [RTN_VCN_W-1:0]     credit_rtn_vcn,
    input logic [CREDIT_SIZE-1:0]   credit_rtn_cnt,
    input logic [AXI_ADDR_W-1:0]    addr,
    input logic [AXI_WSTRB_W-1:0]   wstrb,
    input logic [1727:0]            data_line
  );
    logic [FDI_FLIT_WIDTH-1:0] flit_word;
    begin
      flit_word = '0;
      flit_word[5:3]    = vcn;
      flit_word[6]      = 1'b1;
      flit_word[7]      = 1'b1;
      flit_word[11:8]   = opcode;
      flit_word[12]     = port_id;
      flit_word[20:13]  = txn_id;
      flit_word[28:21]  = burst_len;
      flit_word[30:29]  = burst_type;
      flit_word[33:31]  = burst_size;
      flit_word[35:34]  = resp;
      flit_word[37:36]  = credit_rtn_vcn;
      flit_word[43:38]  = credit_rtn_cnt;
      flit_word[84:45]  = addr;
      flit_word[255:128]= wstrb;
      flit_word[1983:256] = data_line;
      build_fdi_flit = flit_word;
    end
  endfunction

  task automatic send_one_flit(input logic [FDI_FLIT_WIDTH-1:0] flit_word);
    begin
      @(posedge fdi_clk);
      flit_rx_data             <= flit_word;
      flit_rx_data_valid       <= 1'b1;
      fdi_depktr_rx_startofpkt <= 1'b1;
      fdi_depktr_rx_endofpkt   <= 1'b1;
      @(posedge fdi_clk);
      flit_rx_data             <= '0;
      flit_rx_data_valid       <= 1'b0;
      fdi_depktr_rx_startofpkt <= 1'b0;
      fdi_depktr_rx_endofpkt   <= 1'b0;
    end
  endtask

  task automatic show_outputs(input string tag);
    $display("[%0t] %s", $time, tag);
    $display("  FDI      : trdy=%0b valid=%0b sop=%0b eop=%0b",
             fdi_depktr_rx_trdy, flit_rx_data_valid,
             fdi_depktr_rx_startofpkt, fdi_depktr_rx_endofpkt);
    $display("  CREDIT   : rtn_valid=%0b credit_vcn=0x%0h credit_cnt=0x%0h rx_incr=%0b rx_vcn=0x%0h",
             depktr_crdtmgr_rtn_valid, depktr_crdtmgr_credit_vcn,
             depktr_crdtmgr_credit_cnt, depktr_crdtmgr_credit_rx_incr,
             depktr_crdtmgr_rx_vcn);
    $display("  ROUTER   : wr_req=%0b rd_req=%0b wr_rsp=%0b rd_rsp=%0b port_id=%0b txn_id=0x%0h",
             depktr_portrtr_write_req_valid, depktr_portrtr_read_req_valid,
             depktr_portrtr_write_resp_valid, depktr_portrtr_read_resp_valid,
             depktr_portrtr_port_id, depktr_portrtr_txn_id);
    $display("  AXI META : addr=0x%0h len=0x%0h type=0x%0h size=0x%0h resp=0x%0h",
             depktr_portrtr_axi_addr, depktr_portrtr_axi_burst_len,
             depktr_portrtr_axi_burst_type, depktr_portrtr_axi_burst_size,
             depktr_portrtr_axi_resp);
    $display("  AXI DATA : wstrb[31:0]=0x%08h data[31:0]=0x%08h data[1023:992]=0x%08h",
             depktr_portrtr_axi_wstrb[31:0], depktr_portrtr_axi_data[31:0],
             depktr_portrtr_axi_data[1023:992]);
    $display("  CMPLT    : resp_valid=%0b vcn=%0b txn_id=0x%0h",
             depktr_cmpltkr_resp_valid, depktr_cmpltkr_vcn, depktr_cmpltkr_txn_id);
  endtask

  initial begin
    logic [1727:0] payload_line;
    logic [127:0]  wstrb_line;
    logic [FDI_FLIT_WIDTH-1:0] single_flit;

    payload_line = '0;
    payload_line[31:0]      = 32'h1122_3344;
    payload_line[63:32]     = 32'h5566_7788;
    payload_line[1055:1024] = 32'hA5A5_5A5A;
    wstrb_line = 128'hFFFF_0000_AAAA_5555_1234_5678_9ABC_DEF0;

    single_flit = build_fdi_flit(
      3'b101,          // vcn
      4'b0000,         // opcode: write request
      1'b1,            // port_id
      8'hA6,           // txn_id
      8'h10,           // burst_len
      2'b01,           // burst_type
      3'b100,          // burst_size
      2'b00,           // resp
      2'b10,           // credit return vcn
      6'd12,           // credit return count
      40'h12_3456_789A,// address
      wstrb_line,
      payload_line
    );

    apply_reset();

    $display("[%0t] Starting depacketizer stimulus", $time);
    $display("[%0t] Driving router backpressure high for one cycle", $time);
    portrtr_depktr_bakpres <= 1'b1;
    @(posedge fdi_clk);
    show_outputs("While backpressure is asserted");

    portrtr_depktr_bakpres <= 1'b0;
    @(posedge fdi_clk);
    show_outputs("Backpressure released");

    send_one_flit(single_flit);
    @(posedge fdi_clk);
    show_outputs("After one FDI flit is accepted");

    portrtr_depktr_read_done <= 1'b1;
    @(posedge fdi_clk);
    portrtr_depktr_read_done <= 1'b0;
    @(posedge fdi_clk);
    show_outputs("After portrtr_depktr_read_done pulse");

    repeat (4) @(posedge fdi_clk);
    $display("[%0t] End of depacketizer smoke stimulus", $time);
    $finish;
  end

endmodule
