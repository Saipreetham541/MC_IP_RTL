# Source after loading work.tb_mc_axi_smoke with vsim -voptargs=+acc.
# Example: do /absolute/path/to/src_mc/sim/mc_axi_smoke_wave.do
add wave -noupdate -group Control sim:/tb_mc_axi_smoke/phase
foreach sig {aclk aresetn dfi_clk ctl_reset_n} {
    add wave -noupdate -group Control sim:/tb_mc_axi_smoke/$sig
}
foreach sig {s_axi_awaddr s_axi_awid s_axi_awlen s_axi_awsize s_axi_awburst
             s_axi_awvalid s_axi_awready s_axi_wdata s_axi_wstrb s_axi_wlast
             s_axi_wvalid s_axi_wready s_axi_bid s_axi_bresp s_axi_bvalid s_axi_bready} {
    add wave -noupdate -radix hexadecimal -group AXI_write sim:/tb_mc_axi_smoke/$sig
}
foreach sig {s_axi_araddr s_axi_arid s_axi_arlen s_axi_arsize s_axi_arburst
             s_axi_arvalid s_axi_arready s_axi_rid s_axi_rdata s_axi_rresp
             s_axi_rlast s_axi_rvalid s_axi_rready} {
    add wave -noupdate -radix hexadecimal -group AXI_read sim:/tb_mc_axi_smoke/$sig
}
foreach sig {sub_awaddr sub_awvalid sub_awready sub_awlock sub_awqos sub_awcache sub_awprot
             sub_wdata sub_wvalid sub_wready sub_bvalid sub_bready
             sub_araddr sub_arvalid sub_arready sub_arlock sub_arqos sub_arcache sub_arprot
             sub_rdata sub_rvalid sub_rready} {
    add wave -noupdate -radix hexadecimal -group Subordinate sim:/tb_mc_axi_smoke/dut/$sig
}
foreach sig {m_awaddr m_awvalid m_awready m_wdata m_wvalid m_wready m_bvalid m_bready
             m_araddr m_arvalid m_arready m_rdata m_rvalid m_rready} {
    add wave -noupdate -radix hexadecimal -group After_CDC sim:/tb_mc_axi_smoke/dut/$sig
}
add wave -noupdate -group Backend sim:/tb_mc_axi_smoke/dut/u_addr_decode/state
foreach sig {target row bg bank col word_index} {
    add wave -noupdate -radix hexadecimal -group Backend sim:/tb_mc_axi_smoke/dut/u_addr_decode/$sig
}
foreach sig {cmd_push_val cmd_push_entry cmdq_full wdb_push_val wdb_push_data
             wdb_push_mask wdb_full row_grant col_grant wr_done rdb_valid rdb_data rdb_ready} {
    add wave -noupdate -radix hexadecimal -group Core sim:/tb_mc_axi_smoke/dut/$sig
}
foreach sig {dfi_row_val dfi_row dfi_col_val dfi_col dfi_wrdata_en dfi_wrdata dfi_wrdata_mask
             dfi_rddata_en dfi_rddata_valid dfi_rddata} {
    add wave -noupdate -radix hexadecimal -group DFI sim:/tb_mc_axi_smoke/$sig
}
foreach sig {acts_seen writes_seen reads_seen err_cmdq_overflow err_wdb_overflow err_ref_deadline_miss} {
    add wave -noupdate -radix unsigned -group Checks sim:/tb_mc_axi_smoke/$sig
}
configure wave -timelineunits ns
