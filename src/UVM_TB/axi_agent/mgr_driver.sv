//mgr_driver
class mgr_driver extends uvm_driver#(axi4_seq_item);
`uvm_component_utils(mgr_driver)
axi4_seq_item txn;
virtual mgr_interface.MGR_DRV_MP vif;
virtual reset_interface rst_intf;

axi_agt_config agt_cfg;
function new(string name="mgr_driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
txn=axi4_seq_item::type_id::create("txn");
if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
`uvm_fatal("FATAL","FROM MGR_DRIVER CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
endfunction

function void connect_phase(uvm_phase phase);
vif=agt_cfg.mgr_intf;
endfunction
	
	task run_phase(uvm_phase phase);
	
			wait(vif.axi_rst_n && vif.global_reset);

			if(agt_cfg.role!=axi_agt_config::MGR) begin
				`uvm_info("from mgr_drv","mgr_drv disabled",UVM_MEDIUM)
				return;
			end
			seq_item_port.get_next_item(txn);
			if(agt_cfg.typ == axi_agt_config::REQ) begin
				`uvm_info("from mgr_drv","mgr_as_req",UVM_MEDIUM)
				driv_req_ready(txn); 
			end
			else begin
				drive_b(txn);
				drive_r(txn);
			end
			seq_item_port.item_done();

	endtask 

	task driv_req_ready(axi4_seq_item txn);
		@(vif.mgr_drv_cb);
		vif.mgr_drv_cb.awready<=1;
		vif.mgr_drv_cb.wready<=1;
		vif.mgr_drv_cb.arready<=1;
		txn.display();
	endtask 
	
	task drive_b(axi4_seq_item txn);
		@( vif.mgr_drv_cb);
		vif.mgr_drv_cb.bvalid<=0;
		vif.mgr_drv_cb.bid<=txn.id;
		vif.mgr_drv_cb.bresp<=txn.resp;
		wait(vif.mgr_drv_cb.bready);  
		@(vif.mgr_drv_cb);
		vif.mgr_drv_cb.bvalid<=0;
	endtask
	
	task drive_r(axi4_seq_item txn);
		@(vif.mgr_drv_cb)
		vif.mgr_drv_cb.rvalid<=0;
		vif.mgr_drv_cb.rid<=txn.id;
		foreach(txn.data[i]) begin
			vif.mgr_drv_cb.rdata<=txn.data[i];
		end
		vif.mgr_drv_cb.rresp<=txn.resp;
		wait(vif.mgr_drv_cb.rready);
		@(vif.mgr_drv_cb)
		vif.mgr_drv_cb.rvalid<=0;
	endtask
endclass