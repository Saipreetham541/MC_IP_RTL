package axfdi_pkg;
`include "uvm_macros.svh"
import uvm_pkg::*;




`include "../apb_agent/apb_agent_config.sv"
`include "../fdi_agent/fdi_agent_config.sv"
`include "../axi_agent/axi_agent_config.sv"
//`include "reg_class.sv"
//`include "reg_block.sv"
`include "../tb/axfdi_env_config.sv"

`include "../apb_agent/apb_xtn.sv"
`include "../apb_agent/apb_seqs.sv"
`include "../apb_agent/apb_driver.sv"
`include "../apb_agent/apb_monitor.sv"
`include "../apb_agent/apb_seqr.sv"
`include "../apb_agent/apb_agent.sv"

`include "../fdi_agent/fdi_pkt_item.sv"
`include "../fdi_agent/credit_model.sv"
`include "../fdi_agent/fdi_seqs.sv"
`include "../fdi_agent/fdi_driver.sv"
`include "../fdi_agent/fdi_monitor.sv"
`include "../fdi_agent/fdi_seqr.sv"
`include "../fdi_agent/fdi_agent.sv"

`include "../axi_agent/axi4_seq_item.sv"

`include "../axi_agent/mgr_driver.sv"
`include "../axi_agent/mgr_monitor.sv"
`include "../axi_agent/mgr_seqr.sv"
`include "../axi_agent/sub_driver.sv"
`include "../axi_agent/sub_monitor.sv"
`include "../axi_agent/sub_seqr.sv"
`include "../axi_agent/axi_agent.sv"

`include "virtual_seqr.sv"
`include "axfdi_comparator.sv"
`include "axfdi_predictor.sv"
`include "axfdi_scoreboard.sv"


//`include "axi_back_pressure_seq.sv"
//`include "credit_starve_axi_seq.sv"
//`include "fdi_back_pressure_seqs.sv"
//`include "fdi_credit_starve_seqs.sv"
//`include "fdi_data_seqs.sv"
`include "fdi_init_seqs.sv"
//`include "fdi_inline_credit_rtn_seqs.sv"
//`include "fdi_standalone_credit_rtn_seqs.sv"
`include "single_read_seq.sv"
//`include "single_rw_port_seq.sv"
`include "single_write_seq.sv"
`include "fdi_data_seqs.sv"



//`include "../virtual_seqs/credit_back_pressure_virtual_seqs.sv"
//`include "../virtual_seqs/credit_starve_virtual_seq.sv"
//`include "../virtual_seqs/inline_credit_virtual_seq.sv"
`include "../virtual_seqs/single_read_virtual_seq.sv"
//`include "../virtual_seqs/single_rw_virtual_seq.sv"
`include "../virtual_seqs/single_write_virtual_seq.sv"
//`include "../virtual_seqs/standalone_credit_virtual_seq.sv"
`include "../virtual_seqs/fdi_data_virtual_seq.sv"
`include "../virtual_seqs/base_vseq.sv"


`include "../tb/axfdi_env.sv"


//`include "credit_back_pressure_test.sv"
//`include "credit_starve_test.sv"
//`include "inline_credit_test.sv"
`include "single_read_test.sv"
//`include "single_rw_test.sv"
`include "single_write_test.sv"
//`include "standalone_credit_test.sv"
`include "fdi_data_test.sv"
`include "../test/axfdi_test.sv"

endpackage