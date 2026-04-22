//sub_driver
 class sub_driver extends uvm_driver#(axi4_seq_item);
`uvm_component_utils(sub_driver)
axi4_seq_item txn;
/*logic awvalid,awaready;
logic arvalid, arready;
logic wvalid, rvalid;*/


virtual sub_interface.SUB_DRV_MP vif;
virtual reset_interface rst_intf;
axi_agt_config agt_cfg;
function new(string name="sub_driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
`uvm_fatal("FATAL","FROM SUB_DRIVER CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
txn=axi4_seq_item::type_id::create("txn");
endfunction

function void connect_phase(uvm_phase phase);
vif=agt_cfg.sub_intf;
endfunction

task run_phase(uvm_phase phase);
		wait(vif.axi_rst_n && vif.global_reset);
			@(vif.sub_drv_cb)
		
		forever begin
			seq_item_port.get_next_item(txn);
			 if(txn.axn_type==txn.write)
					drive_write(txn);
				else if (txn.axn_type==txn.read);
					drive_read(txn);
			seq_item_port.item_done();
		end 
	endtask
	
	task drive_write(axi4_seq_item txn);
		fork
			drive_aw(txn);
			drive_w(txn);
		join
	endtask
	
	task drive_aw(axi4_seq_item txn);
		@(vif.sub_drv_cb)
		
		vif.sub_drv_cb.awvalid<=1;
		vif.sub_drv_cb.awaddr<=txn.addr;
		vif.sub_drv_cb.awid<=txn.id;
		vif.sub_drv_cb.awlen<=txn.len;
		vif.sub_drv_cb.awsize<=txn.size;
		vif.sub_drv_cb.awburst<=txn.burst;
	//	vif.sub_drv_cb.bready<=txn.bready;
		
		wait(vif.sub_drv_cb.awready);
		@(vif.sub_drv_cb)
		vif.sub_drv_cb.awvalid<=0;
		txn.display();
	endtask
	
	task drive_w(axi4_seq_item txn);
		for(int i=0; i<=txn.len; i++)
			begin
				@(vif.sub_drv_cb);
				
				vif.sub_drv_cb.wvalid<=1;
				vif.sub_drv_cb.wdata<=txn.data[i];
				vif.sub_drv_cb.wstrb<=txn.strb[i];
				if(i==txn.len)
					vif.sub_drv_cb.wlast<=1;
				else
					vif.sub_drv_cb.wlast<=0;
				wait(vif.sub_drv_cb.wready);
			end
					@(vif.sub_drv_cb)
				
					vif.sub_drv_cb.wvalid<=0;
					//vif.sub_drv_cb.wready<=0;
					txn.display();
			
	endtask
			
			
	task drive_read(axi4_seq_item txn);
		@( vif.sub_drv_cb)
		
			vif.sub_drv_cb.arvalid<=1;
			vif.sub_drv_cb.araddr<=txn.addr;
			vif.sub_drv_cb.arid<=txn.id;
			vif.sub_drv_cb.arlen<=txn.len;
			vif.sub_drv_cb.arsize<=txn.size;
			vif.sub_drv_cb.arburst<=txn.burst;
			//vif.sub _drv_cb.rready<=txn.rready;
			
			wait(vif.sub_drv_cb.arready);
				@(vif.sub_drv_cb)
			vif.sub_drv_cb.arvalid<=0;
			txn.display();
	endtask
				

endclass








