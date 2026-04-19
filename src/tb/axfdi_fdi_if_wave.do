transcript on

set cwd [file normalize [pwd]]
set repo_root ""

if {[file exists [file join $cwd Busbridges src rtl axfdi_fdi_if.sv]]} {
  set repo_root [file join $cwd Busbridges]
} elseif {[file exists [file join $cwd src rtl axfdi_fdi_if.sv]]} {
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
         [file join $repo_root src tb axfdi_fdi_if_tb.sv]
vsim -voptargs=+acc axfdi_fdi_if_tb

view structure
view signals
view wave

add wave -r /*

run -all
