//env
//import uvm_pkg::*;
//`include "uvm_macros.svh";
class axfdi_env extends uvm_env;
`uvm_component_utils(axfdi_env)
axi_agent axi_agt[];
fdi_agent fdi_agt;
apb_agent apb_agt;

env_config env_cfg;
axfdi_scoreboard sb;

virtual_seqr vseqrh;



function new(string name="axfdi_env",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db#(env_config)::get(this,"","env_config",env_cfg))
`uvm_fatal("FATAL","FROM ENV ")
axi_agt=new[env_cfg.no_of_axi_agts];
vseqrh= virtual_seqr:: type_id:: create("vserqrh",this);



foreach(axi_agt[i])
begin
axi_agt[i]=axi_agent::type_id::create($sformatf("axi_agt[%0d]",i),this);
uvm_config_db#(axi_agt_config)::set(this,$sformatf("axi_agt[%0d]",i),"axi_agt_config",env_cfg.agt_cfg[i]);
uvm_config_db#(int)::set(this,$sformatf("axi_agt[%0d]",i),"agent_id",i);
end



fdi_agt=fdi_agent::type_id::create("fdi_agt",this);
apb_agt=apb_agent::type_id::create("apb_agt",this);
sb=axfdi_scoreboard::type_id::create("sb",this);


uvm_config_db#(fdi_agt_config)::set(this,"*","fdi_agt_config",env_cfg.fdi_cfg);
uvm_config_db#(apb_agt_config)::set(this,"*","apb_agt_config",env_cfg.apb_cfg);


endfunction

function void connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	//foreach(vseqrh.sub_seqr[i]) begin
  vseqrh.sub_seqr0 = this.axi_agt[0].sub_seqr;
  vseqrh.sub_seqr1 = this.axi_agt[1].sub_seqr;
  
//end
	//foreach(vseqrh.mgr_seqr[i]) begin
 vseqrh.mgr_seqr0 = this.axi_agt[0].mgr_seqr;
 vseqrh.mgr_seqr1 =this.axi_agt[1].mgr_seqr;
  //end
  vseqrh.fdi_seqr=this.fdi_agt.fdi_seqr;
  
  
 endfunction

endclass