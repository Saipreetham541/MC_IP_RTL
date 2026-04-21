transcript on

set cwd [file normalize [pwd]]
set repo_root ""

if {[file exists [file join $cwd Busbridges src dummy_tops top_rx.sv]]} {
  set repo_root [file join $cwd Busbridges]
} elseif {[file exists [file join $cwd src dummy_tops top_rx.sv]]} {
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

vlog -sv [file join $repo_root src rtl axfdi_fdi_if.sv] \
         [file join $repo_root src rtl axfdi_depacketizer.sv] \
         [file join $repo_root src rtl axfdi_port_router.sv] \
         [file join $repo_root src rtl axfdi_completion_tracker.sv] \
         [file join $repo_root src rtl axfdi_credit_mgr.sv] \
         [file join $repo_root src dummy_tops top_rx.sv] \
         [file join $repo_root src tb top_rx_tb.sv]
#vsim -voptargs=+acc top_rx_tb
vsim top_rx_tb

view structure
view signals
view wave

add wave -r /*

run -all
