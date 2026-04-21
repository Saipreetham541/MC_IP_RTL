package axfdi_pkg;

import uvm_pkg::*;

`include "uvm_macros.svh"


`include "../apb_agent/apb_agent_config.sv"
`include "../fdi_agent/fdi_agent_config.sv"
`include "../axi_agent/axi_agent_config.sv"
//`include "reg_class.sv"
//`include "reg_block.sv"
`include "axfdi_env_config.sv"

`include "../apb_agent/apb_xtn.sv"
`include "../apb_agent/apb_seqs.sv"
`include "../apb_agent/apb_driver.sv"
`include "../apb_agent/apb_monitor.sv"
`include "../apb_agent/apb_seqr.sv"
`include "../apb_agent/apb_agent.sv"

`include "../fdi_agent/fdi_pkt_item.sv"
`include "../fdi_agent/fdi_seqs.sv"
`include "../fdi_agent/fdi_driver.sv"
`include "../fdi_agent/fdi_monitor.sv"
`include "../fdi_agent/fdi_seqr.sv"
`include "../fdi_agent/fdi_agent.sv"

`include "../axi_agent/axi4_seq_item.sv"
//`include "mgr_seqs.sv"
`include "../axi_agent/mgr_driver.sv"
`include "../axi_agent/mgr_monitor.sv"
`include "../axi_agent/mgr_seqr.sv"
`include "../axi_agent/sub_driver.sv"
`include "../axi_agent/sub_monitor.sv"
`include "../axi_agent/sub_seqr.sv"
`include "../axi_agent/axi_agent.sv"


`include "axfdi_scoreboard.sv"

`include "../tb/virtual_seqr.sv"
`include "../tb/axfdi_env.sv"
`include "../sequences/write_sub_seqs.sv"
`include "../sequences/mgr_seqs.sv"
`include "../sequences/virtual_seqs.sv"


`include "axfdi_test.sv"

endpackage