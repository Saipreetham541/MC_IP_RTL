//test
//import uvm_pkg::*;
//`include "uvm_macros.svh";

class axfdi_test extends uvm_test;
`uvm_component_utils(axfdi_test)

axfdi_env env;
axi_agt_config agt_cfg[];

env_config env_cfg;
fdi_agt_config fdi_cfg;
apb_agt_config apb_cfg;
int no_of_axi_agts=2;

//virtual interfaces for reset

virtual reset_interface rst_intf;



function new(string name="axfdi_test",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);

agt_cfg=new[no_of_axi_agts];

env_cfg=env_config::type_id::create("env_cfg");
env_cfg.no_of_axi_agts=2;

env_cfg.agt_cfg=new[no_of_axi_agts];



foreach(agt_cfg[i])
begin
agt_cfg[i]=axi_agt_config::type_id::create($sformatf("agt_cfg[%0d]",i));
//getting the interface  from top and connecting it to config interface
//if(!uvm_config_db #(virtual axi_interface)::get(this,"","vif",agt_cfg))
//`uvm_fatal("FATAL1","FROM MGR INTERFACE")
agt_cfg[i].is_active=UVM_ACTIVE;
env_cfg.agt_cfg[i]=agt_cfg[i];
end


fdi_cfg=fdi_agt_config::type_id::create("fdi_cfg");
if(!uvm_config_db #(virtual fdi_interface)::get(this,"","in2",fdi_cfg.fdi_intf))
`uvm_fatal("FATAL3","FROM FDI INTERFACE")
fdi_cfg.is_active=UVM_ACTIVE;

apb_cfg=apb_agt_config::type_id::create("apb_cfg");
if(!uvm_config_db #(virtual apb_interface)::get(this,"","in3",apb_cfg.apb_intf))
`uvm_fatal("FATAL4","FROM APB INTERFACE")
apb_cfg.is_active=UVM_ACTIVE;
env_cfg.fdi_cfg=fdi_cfg;
env_cfg.apb_cfg=apb_cfg;


//setting env_config
uvm_config_db #(env_config)::set(this,"*","env_config",env_cfg);
env=axfdi_env::type_id::create("env",this);
//getting interfaces from top for reset driving
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")


endfunction

function void end_of_elaboration_phase(uvm_phase phase);
uvm_top.print_topology;
endfunction

task apply_reset();
`uvm_info("RESET","Applying reset",UVM_MEDIUM)
rst_intf.global_reset=0;
rst_intf.axi_rst_n=0;
rst_intf.fdi_rst_n=0;
rst_intf.apb_rst_n=0;
#50;
rst_intf.global_reset=1;
repeat(16)
@(posedge rst_intf.axi_clk);
rst_intf.axi_rst_n=1;
wait(rst_intf.axi_rst_n==1);
repeat(16)
@(posedge rst_intf.fdi_clk);
rst_intf.fdi_rst_n=1;
repeat(16)
@(posedge rst_intf.apb_clk);
rst_intf.apb_rst_n=1;
`uvm_info("RESET","reset completed",UVM_MEDIUM)
endtask

endclass


/*class test_case1 extends axfdi_test;
	`uvm_component_utils(test_case1)
	
	virtual_seqs vseqh;
	virtual_seqr vseqrh;
	
function new(string name ="test_case1" , uvm_component parent);
	super.new(name, parent);
endfunction

function void build_phase (uvm_phase phase);
	super.build_phase(phase);
vseqh=virtual_seqs :: type_id :: create("vseqh");
vseqrh=virtual_seqr:: type_id :: create("vseqrh", this);
endfunction

task run_phase(uvm_phase phase);
	phase.raise_objection(this);
	apply_reset;
	vseqh.start(vseqrh);
	phase.drop_objection(this);
endtask
endclass*/

	
