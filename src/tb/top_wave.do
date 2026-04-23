transcript on

set cwd [file normalize [pwd]]
set repo_root ""

if {[file exists [file join $cwd Busbridges src rtl axfdi_bridge.sv]]} {
  set repo_root [file join $cwd Busbridges]
} elseif {[file exists [file join $cwd src rtl axfdi_bridge.sv]]} {
  set repo_root $cwd
} else {
  echo "ERROR: Could not locate Busbridges repo root from current directory: $cwd"
  echo "Start Questa from /home/aravindps/sevya_proj or /home/aravindps/sevya_proj/Busbridges"
  quit -f
}

if {[file exists work]} {
  vdel -lib work -all
}
vlib work

vlog -sv [file join $repo_root src rtl TX_BUFF.sv] \
         [file join $repo_root src rtl axfdi_axi_mgr.sv] \
         [file join $repo_root src rtl axfdi_axi_sub.sv] \
         [file join $repo_root src rtl axfdi_completion_tracker.sv] \
         [file join $repo_root src rtl axfdi_credit_mgr.sv] \
         [file join $repo_root src rtl axfdi_depacketizer.sv] \
         [file join $repo_root src rtl axfdi_fdi_if.sv] \
         [file join $repo_root src rtl axfdi_packetizer.sv] \
         [file join $repo_root src rtl axfdi_port_merge.sv] \
         [file join $repo_root src rtl axfdi_port_router.sv] \
         [file join $repo_root src rtl axfdi_tx_arb.sv] \
         [file join $repo_root src rtl cdc_fifo.sv] \
         [file join $repo_root src rtl axfdi_bridge.sv] \
         [file join $repo_root src tb top_tb.sv]

vsim -voptargs=+acc work.top_tb

view structure
view signals
view wave

add wave -r sim:/top_tb/*
add wave -r sim:/top_tb/dut/*

run -all
