//mgr_driver
class mgr_driver extends uvm_driver#(axi_xtn);
`uvm_component_utils(mgr_driver)
axi_xtn txn;
virtual mgr_interface.MGR_DRV_MP vif;
virtual reset_interface rst_intf;

axi_agt_config agt_cfg;
function new(string name="mgr_driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
`uvm_fatal("FATAL","FROM MGR_DRIVER CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
endfunction

function void connect_phase(uvm_phase phase);
vif=agt_cfg.mgr_intf;
endfunction
	
	task run_phase(uvm_phase phase);
	fork 
		drive_b(txn);
		drive_r(txn);
	join
	endtask 
	
	task drive_b(axi_xtn txn);
		@( vif.mgr_drv_cb)
		vif.mgr_drv_cb.bvalid<=0;
		vif.mgr_drv_cb.bid<=txn.id;
		vif.mgr_drv_cb.bresp<=txn.resp;
		wait(vif.mgr_drv_cb.bready);  
		@(vif.mgr_drv_cb)
		vif.mgr_drv_cb.bvalid<=1;
	endtask
	
	task drive_r(axi_xtn txn);
		@(vif.mgr_drv_cb)
		vif.mgr_drv_cb.rvalid<=0;
		
		vif.mgr_drv_cb.rid<=txn.id;
		foreach(txn.data[i]) begin
		vif.mgr_drv_cb.rdata<=txn.data[i];
		end
		vif.mgr_drv_cb.rresp<=txn.resp;
	//	vif.mgr_drv_cb.rlast<=txn.last;
	//	vif.mgr_drv_cb.rvalid<=txn.rvalid;
	//	vif.mgr_drv_cb.awready<=txn.awready;
	//	vif.mgr_drv_cb.wreday<=txn.wready;
		
		wait(vif.mgr_drv_cb.rready);
		@(vif.mgr_drv_cb)
		vif.mgr_drv_cb.rvalid<=0;
	endtask
endclass