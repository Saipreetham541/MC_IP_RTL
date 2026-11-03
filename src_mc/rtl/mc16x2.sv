`default_nettype none
`timescale 1ns/1ps

// AXI/APB-facing 16x2 integration. AXI_ENABLE=0 retains decoded diagnostic
// operation for the independent core regression. In AXI mode each column is
// 32 bytes: one 256-bit buffered beat is eight consecutive 32-bit lane words.
// Both AXI/core resets flush the transaction path; presetn resets only CSRs.
module mc16x2 #(parameter bit AXI_ENABLE = 1'b1) (
  // Common controller clock/reset.
  input  logic                dfi_clk,
  input  logic                ctl_reset_n,
  // Decoded diagnostic inputs are ignored when AXI_ENABLE=1.
  input  logic [31:0]           cmd_push_val,
  input  logic [31:0][35:0]     cmd_push_entry,
  output logic [31:0]           cmdq_full,
  input  logic [31:0]           wdb_push_val,
  input  logic [31:0][31:0]     wdb_push_data,
  input  logic [31:0][3:0]      wdb_push_mask,
  output logic [31:0][3:0]      wdb_alloc_ptr,
  output logic [31:0]           wdb_full,
  output logic [31:0]           rdb_valid,
  input  logic [31:0]           rdb_ready,
  output logic [31:0][31:0]     rdb_data,
  output logic [31:0][7:0]      rdb_axi_id,
  // Common per-channel DFI interface.
  output logic [15:0]           dfi_row_val,
  output logic [15:0][21:0]     dfi_row,
  output logic [15:0]           dfi_col_val,
  output logic [15:0][11:0]     dfi_col,
  output logic [15:0][63:0]     dfi_wrdata,
  output logic [15:0][7:0]      dfi_wrdata_mask,
  output logic [15:0][1:0]      dfi_wrdata_en,
  output logic [15:0][1:0]      dfi_rddata_en,
  input  logic [15:0][63:0]     dfi_rddata,
  input  logic [15:0][1:0]      dfi_rddata_valid,
  output logic [31:0]           err_cmdq_overflow,
  output logic [31:0]           err_wdb_overflow,
  output logic [31:0]           err_ref_deadline_miss,
  // Single AXI4 port and APB4 control/status interface.
  input logic aclk,
  input logic aresetn,
  input logic [7:0] awid,
  input logic [39:0] awaddr,
  input logic [7:0] awlen,
  input logic [2:0] awsize,
  input logic [1:0] awburst,
  input logic [3:0] awqos,
  input logic [3:0] awcache,
  input logic [2:0] awprot,
  input logic awlock,
  input logic awvalid,
  output logic awready,
  input logic [255:0] wdata,
  input logic [31:0] wstrb,
  input logic wlast,
  input logic wvalid,
  output logic wready,
  output logic [7:0] bid,
  output logic [1:0] bresp,
  output logic bvalid,
  input logic bready,
  input logic [7:0] arid,
  input logic [39:0] araddr,
  input logic [7:0] arlen,
  input logic [2:0] arsize,
  input logic [1:0] arburst,
  input logic [3:0] arqos,
  input logic [3:0] arcache,
  input logic [2:0] arprot,
  input logic arlock,
  input logic arvalid,
  output logic arready,
  output logic [7:0] rid,
  output logic [255:0] rdata,
  output logic [1:0] rresp,
  output logic rlast,
  output logic rvalid,
  input logic rready,
  input logic pclk,
  input logic presetn,
  input logic [19:0] paddr,
  input logic psel,
  input logic penable,
  input logic pwrite,
  input logic [31:0] pwdata,
  input logic [3:0] pstrb,
  output logic pready,
  output logic [31:0] prdata,
  output logic pslverr,
  output logic irq
);

  localparam int CORE_DATA_W = AXI_ENABLE ? 256 : 32;
  localparam int CORE_MASK_W = CORE_DATA_W/8;
  localparam int BURST_WORDS = AXI_ENABLE ? 8 : 1;
  logic core_reset_n;
  logic [31:0] core_cmd_push_val, core_wdb_push_val, core_rdb_ready, core_write_done;
  logic [31:0][35:0] core_cmd_push_entry;
  logic [31:0][CORE_DATA_W-1:0] core_wdb_push_data, core_rdb_data;
  logic [31:0][CORE_MASK_W-1:0] core_wdb_push_mask;
  logic [31:0][31:0] formatter_return;
  logic [31:0] formatter_return_valid, lane_busy, return_error;
  localparam logic [1:0] COL_RD = 2'b01;
  localparam logic [1:0] COL_WR = 2'b10;
  logic [31:0] row_req_valid, row_req_refresh, col_req_valid;
  logic [31:0][2:0] row_cmd;
  logic [31:0][13:0] row_addr;
  logic [31:0][1:0] row_bg, row_bank;
  logic [31:0][1:0] col_cmd;
  logic [31:0][4:0] col_addr;
  logic [31:0][1:0] col_bg, col_bank;
  logic [31:0][3:0] col_wdb_ptr;
  logic [31:0][7:0] col_axi_id;
  logic [31:0] row_grant, col_grant;
  logic [31:0][CORE_DATA_W-1:0] wdb_data, returned_data;
  logic [31:0][CORE_MASK_W-1:0] wdb_mask;
  logic [31:0] returned_valid;

  for (genvar ch = 0; ch < 16; ch++) begin : g_channel
    logic [1:0][21:0] row_candidates;
    logic [1:0][11:0] col_candidates;
    logic row_valid, col_valid, row_pc, col_pc;
    logic [21:0] selected_row;
    logic [11:0] selected_col;
    logic [63:0] lane_data;
    logic [7:0] lane_mask;
    logic [1:0] write_enable, read_enable;

    for (genvar pc = 0; pc < 2; pc++) begin : g_pc
      localparam int P = 2*ch + pc;
      logic write_issue;
      logic [3:0] release_ptr;
      assign write_issue = col_grant[P] && (col_cmd[P] == COL_WR);
      assign row_candidates[pc] = {1'b0, row_cmd[P], row_bg[P], row_bank[P], row_addr[P]};
      assign col_candidates[pc] = {1'b0, col_cmd[P], col_bg[P], col_bank[P], col_addr[P]};
      assign rdb_data[P] = core_rdb_data[P][31:0];
      assign read_enable[pc] = col_grant[P] && (col_cmd[P] == COL_RD);
      if (AXI_ENABLE) begin : g_burst
        logic [255:0] write_shift, read_assembly;
        logic [31:0] mask_shift;
        logic [3:0] words_left, read_left;
        logic [2:0] read_word;
        logic [3:0] saved_ptr;
        assign lane_busy[P] = (words_left != 0) || (read_left != 0);
        assign release_ptr = saved_ptr;
        assign core_write_done[P] = (words_left == 1) && core_reset_n;
        assign write_enable[pc] = write_issue || (words_left != 0);
        assign lane_data[pc*32 +: 32] = write_issue ? wdb_data[P][31:0] :
                                            (words_left != 0 ? write_shift[31:0] : 32'b0);
        assign lane_mask[pc*4 +: 4] = write_issue ? wdb_mask[P][3:0] :
                                            (words_left != 0 ? mask_shift[3:0] : 4'b0);
        always_ff @(posedge dfi_clk or negedge core_reset_n) begin
          if (!core_reset_n) begin
            write_shift <= 0; mask_shift <= 0; words_left <= 0; saved_ptr <= 0;
            read_assembly <= 0; read_left <= 0; read_word <= 0;
            returned_valid[P] <= 0; returned_data[P] <= 0; return_error[P] <= 0;
          end else begin
            returned_valid[P] <= 0; return_error[P] <= 0;
            if (write_issue) begin
              write_shift <= wdb_data[P] >> 32; mask_shift <= wdb_mask[P] >> 4;
              words_left <= 7; saved_ptr <= col_wdb_ptr[P];
            end else if (words_left != 0) begin
              write_shift <= write_shift >> 32; mask_shift <= mask_shift >> 4;
              words_left <= words_left-1'b1;
            end
            if (read_enable[pc]) begin read_left <= 8; read_word <= 0; end
            if (formatter_return_valid[P]) begin
              if (read_left == 0) return_error[P] <= 1;
              else begin
                read_assembly[read_word*32 +: 32] <= formatter_return[P];
                read_left <= read_left-1'b1; read_word <= read_word+1'b1;
                if (read_left == 1) begin
                  returned_data[P] <= {formatter_return[P],read_assembly[223:0]};
                  returned_valid[P] <= 1;
                end
              end
            end
          end
        end
      end else begin : g_word
        assign lane_busy[P] = 0;
        assign release_ptr = col_wdb_ptr[P];
        assign core_write_done[P] = write_issue;
        assign lane_data[pc*32 +: 32] = write_issue ? wdb_data[P] : 32'b0;
        assign lane_mask[pc*4 +: 4] = write_issue ? wdb_mask[P] : 4'b0;
        assign write_enable[pc] = write_issue;
        assign returned_data[P] = formatter_return[P];
        assign returned_valid[P] = formatter_return_valid[P];
        assign return_error[P] = 0;
      end
      mc_pc_core #(
        .DFI_PC_DATA_W(CORE_DATA_W), .DFI_PC_MASK_W(CORE_MASK_W),
        .DATA_BURST_WORDS(BURST_WORDS)
      ) u_pc_core (
        .clk(dfi_clk), .rst_n(core_reset_n),
        .cmd_push_val(core_cmd_push_val[P]), .cmd_push_entry(core_cmd_push_entry[P]), .cmdq_full(cmdq_full[P]),
        .wdb_push_val(core_wdb_push_val[P]), .wdb_push_data(core_wdb_push_data[P]),
        .wdb_push_mask(core_wdb_push_mask[P]), .wdb_alloc_ptr(wdb_alloc_ptr[P]), .wdb_full(wdb_full[P]),
        .wdb_raddr(col_wdb_ptr[P]), .wdb_rdata(wdb_data[P]), .wdb_rmask(wdb_mask[P]),
        .wdb_pop_val(core_write_done[P]), .wdb_pop_ptr(release_ptr),
        .dfi_rddata_valid(returned_valid[P]), .dfi_rddata(returned_data[P]),
        .rdb_valid(rdb_valid[P]), .rdb_ready(core_rdb_ready[P]), .rdb_data(core_rdb_data[P]), .rdb_axi_id(rdb_axi_id[P]),
        .row_req_val(row_req_valid[P]), .row_req_is_ref(row_req_refresh[P]),
        .row_req_cmd(row_cmd[P]), .row_req_addr(row_addr[P]), .row_req_bg(row_bg[P]), .row_req_bank(row_bank[P]),
        .ch_arb_row_grant(row_grant[P]), .col_req_val(col_req_valid[P]), .col_req_cmd(col_cmd[P]),
        .col_req_addr(col_addr[P]), .col_req_bg(col_bg[P]), .col_req_bank(col_bank[P]),
        .col_req_wdb_ptr(col_wdb_ptr[P]), .col_req_axi_id(col_axi_id[P]), .ch_arb_col_grant(col_grant[P]),
        .err_cmdq_overflow(err_cmdq_overflow[P]), .err_wdb_overflow(err_wdb_overflow[P]),
        .err_ref_deadline_miss(err_ref_deadline_miss[P])
      );
    end
    mc_ch_arb u_ch_arb (
      .clk(dfi_clk), .rst_n(core_reset_n),
      .row_req_valid(row_req_valid[2*ch +: 2] & {2{core_reset_n}}),
      .row_req_legal(2'b11), .row_req_refresh(row_req_refresh[2*ch +: 2]),
      .row_grant_ack(2'b11), .row_cmd(row_candidates), .row_grant(row_grant[2*ch +: 2]),
      .row_valid(row_valid), .row_pc_sel(row_pc), .row_cmd_out(selected_row),
      .col_req_valid(col_req_valid[2*ch +: 2] & {2{core_reset_n}}),
      .col_req_legal(~lane_busy[2*ch +: 2]), .col_req_refresh(2'b00), .col_grant_ack(2'b11), .col_cmd(col_candidates),
      .col_grant(col_grant[2*ch +: 2]), .col_valid(col_valid), .col_pc_sel(col_pc), .col_cmd_out(selected_col)
    );
    mc_dfi_fmt u_dfi_fmt (
      .dfi_clk(dfi_clk), .dfi_reset_n(core_reset_n),
      .row_valid(row_valid), .row_pc_sel(row_pc), .row_cmd(selected_row[20:18]),
      .row_bg(selected_row[17:16]), .row_ba(selected_row[15:14]), .row_addr(selected_row[13:0]),
      .dfi_row_val(dfi_row_val[ch]), .dfi_row(dfi_row[ch]),
      .col_valid(col_valid), .col_pc_sel(col_pc), .col_cmd(selected_col[10:9]),
      .col_bg(selected_col[8:7]), .col_ba(selected_col[6:5]), .col_addr(selected_col[4:0]),
      .dfi_col_val(dfi_col_val[ch]), .dfi_col(dfi_col[ch]),
      .wrdata(lane_data), .wrdata_mask(lane_mask), .wrdata_en(write_enable),
      .dfi_wrdata(dfi_wrdata[ch]), .dfi_wrdata_mask(dfi_wrdata_mask[ch]), .dfi_wrdata_en(dfi_wrdata_en[ch]),
      .rddata_en(read_enable), .dfi_rddata_en(dfi_rddata_en[ch]),
      .dfi_rddata(dfi_rddata[ch]), .dfi_rddata_valid(dfi_rddata_valid[ch]),
      .rddata_pc0(formatter_return[2*ch]), .rddata_pc1(formatter_return[2*ch+1]),
      .rddata_valid(formatter_return_valid[2*ch +: 2])
    );
  end
  if (AXI_ENABLE) begin : g_axi
    logic unused_axi_reset_ready_n;
    logic cfg_enable;
    logic [15:0] cfg_channels;
    logic [31:0] cfg_timeout;
    logic backend_busy, write_faulted, protocol_event, timeout_event, wr_complete, rd_complete;
    logic [7:0] m_awid;
    logic [7:0] m_awlen;
    logic [2:0] m_awsize;
    logic [1:0] m_awburst;
    logic [39:0] m_awaddr;
    logic [3:0] m_awqos;
    logic [3:0] m_awcache;
    logic [2:0] m_awprot;
    logic m_awvalid;
    logic m_awready;
    logic [255:0] m_wdata;
    logic [31:0] m_wstrb;
    logic m_wlast;
    logic m_wvalid;
    logic m_wready;
    logic [7:0] m_arid;
    logic [7:0] m_arlen;
    logic [2:0] m_arsize;
    logic [1:0] m_arburst;
    logic [39:0] m_araddr;
    logic [3:0] m_arqos;
    logic [3:0] m_arcache;
    logic [2:0] m_arprot;
    logic m_arvalid;
    logic m_arready;
    logic [7:0] m_bid;
    logic [1:0] m_bresp;
    logic m_bvalid;
    logic m_bready;
    logic [7:0] m_rid;
    logic [255:0] m_rdata;
    logic [1:0] m_rresp;
    logic m_rlast;
    logic m_rvalid;
    logic m_rready;
    mc_axi_cdc u_axi_cdc (
      .axi_reset_ready_n(unused_axi_reset_ready_n),
      .dfi_reset_ready_n(core_reset_n),
      .aclk(aclk),
      .aresetn(aresetn),
      .dfi_clk(dfi_clk),
      .ctl_reset_n(ctl_reset_n),
      .s_awid(awid),
      .s_awlen(awlen),
      .s_awsize(awsize),
      .s_awburst(awlock ? 2'b00 : awburst),
      .s_awaddr(awaddr),
      .s_awqos(awqos),
      .s_awcache(awcache),
      .s_awprot(awprot),
      .s_awvalid(awvalid),
      .s_awready(awready),
      .m_awid(m_awid),
      .m_awlen(m_awlen),
      .m_awsize(m_awsize),
      .m_awburst(m_awburst),
      .m_awaddr(m_awaddr),
      .m_awqos(m_awqos),
      .m_awcache(m_awcache),
      .m_awprot(m_awprot),
      .m_awvalid(m_awvalid),
      .m_awready(m_awready),
      .s_wdata(wdata),
      .s_wstrb(wstrb),
      .s_wlast(wlast),
      .s_wvalid(wvalid),
      .s_wready(wready),
      .m_wdata(m_wdata),
      .m_wstrb(m_wstrb),
      .m_wlast(m_wlast),
      .m_wvalid(m_wvalid),
      .m_wready(m_wready),
      .s_arid(arid),
      .s_arlen(arlen),
      .s_arsize(arsize),
      .s_arburst(arlock ? 2'b00 : arburst),
      .s_araddr(araddr),
      .s_arqos(arqos),
      .s_arcache(arcache),
      .s_arprot(arprot),
      .s_arvalid(arvalid),
      .s_arready(arready),
      .m_arid(m_arid),
      .m_arlen(m_arlen),
      .m_arsize(m_arsize),
      .m_arburst(m_arburst),
      .m_araddr(m_araddr),
      .m_arqos(m_arqos),
      .m_arcache(m_arcache),
      .m_arprot(m_arprot),
      .m_arvalid(m_arvalid),
      .m_arready(m_arready),
      .m_bid(m_bid),
      .m_bresp(m_bresp),
      .m_bvalid(m_bvalid),
      .m_bready(m_bready),
      .s_bid(bid),
      .s_bresp(bresp),
      .s_bvalid(bvalid),
      .s_bready(bready),
      .m_rid(m_rid),
      .m_rdata(m_rdata),
      .m_rresp(m_rresp),
      .m_rlast(m_rlast),
      .m_rvalid(m_rvalid),
      .m_rready(m_rready),
      .s_rid(rid),
      .s_rdata(rdata),
      .s_rresp(rresp),
      .s_rlast(rlast),
      .s_rvalid(rvalid),
      .s_rready(rready)
    );
    mc_axi_sub u_axi_sub (
      .clk(dfi_clk), .rst_n(core_reset_n), .enable(cfg_enable),
      .channel_enable(cfg_channels), .wdata_timeout(cfg_timeout),
      .awid(m_awid),
      .awaddr(m_awaddr),
      .awlen(m_awlen),
      .awsize(m_awsize),
      .awburst(m_awburst),
      .awvalid(m_awvalid),
      .awready(m_awready),
      .wdata(m_wdata),
      .wstrb(m_wstrb),
      .wlast(m_wlast),
      .wvalid(m_wvalid),
      .wready(m_wready),
      .bid(m_bid),
      .bresp(m_bresp),
      .bvalid(m_bvalid),
      .bready(m_bready),
      .arid(m_arid),
      .araddr(m_araddr),
      .arlen(m_arlen),
      .arsize(m_arsize),
      .arburst(m_arburst),
      .arvalid(m_arvalid),
      .arready(m_arready),
      .rid(m_rid),
      .rdata(m_rdata),
      .rresp(m_rresp),
      .rlast(m_rlast),
      .rvalid(m_rvalid),
      .rready(m_rready),
      .cmd_push_val(core_cmd_push_val), .cmd_push_entry(core_cmd_push_entry), .cmdq_full(cmdq_full),
      .wdb_push_val(core_wdb_push_val), .wdb_push_data(core_wdb_push_data), .wdb_push_mask(core_wdb_push_mask),
      .wdb_alloc_ptr(wdb_alloc_ptr), .wdb_full(wdb_full), .write_done(core_write_done),
      .rdb_valid(rdb_valid), .rdb_data(core_rdb_data), .rdb_axi_id(rdb_axi_id), .rdb_ready(core_rdb_ready),
      .busy(backend_busy), .write_faulted(write_faulted), .error_protocol(protocol_event),
      .error_timeout(timeout_event), .write_complete(wr_complete), .read_complete(rd_complete)
    );
    mc_csr u_csr (
      .pclk(pclk), .presetn(presetn), .dfi_clk(dfi_clk), .paddr(paddr), .psel(psel),
      .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .pstrb(pstrb),
      .pready(pready), .prdata(prdata), .pslverr(pslverr), .irq(irq),
      .enable(cfg_enable), .channel_enable(cfg_channels), .wdata_timeout(cfg_timeout),
      .error_timeout(timeout_event), .error_protocol(protocol_event | (|return_error)),
      .err_cmdq_overflow(err_cmdq_overflow), .err_wdb_overflow(err_wdb_overflow),
      .err_ref_deadline_miss(err_ref_deadline_miss), .cmdq_full(cmdq_full),
      .wdb_full(wdb_full), .rdb_valid(rdb_valid), .busy(backend_busy), .write_faulted(write_faulted),
      .write_complete(wr_complete), .read_complete(rd_complete)
    );
  end else begin : g_decoded
    assign core_reset_n = ctl_reset_n;
    assign core_cmd_push_val = cmd_push_val;
    assign core_cmd_push_entry = cmd_push_entry;
    assign core_wdb_push_val = wdb_push_val;
    assign core_wdb_push_data = wdb_push_data;
    assign core_wdb_push_mask = wdb_push_mask;
    assign core_rdb_ready = rdb_ready;
    assign awready = 0; assign wready = 0; assign bid = 0; assign bresp = 0; assign bvalid = 0;
    assign arready = 0; assign rid = 0; assign rdata = 0; assign rresp = 0; assign rlast = 0; assign rvalid = 0;
    assign pready = 0; assign prdata = 0; assign pslverr = 0; assign irq = 0;
  end

endmodule : mc16x2
`default_nettype wire
