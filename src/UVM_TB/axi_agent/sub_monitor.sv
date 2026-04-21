//sub_monitor
class sub_monitor extends uvm_monitor;
 `uvm_component_utils(sub_monitor)
 
 	axi_xtn txnh;
		uvm_analysis_port#(axi_xtn) req;
		uvm_analysis_port#(axi_xtn) res;
		
 virtual sub_interface.SUB_MON_MP vif;
 virtual reset_interface rst_intf;
 axi_agt_config agt_cfg;
 function new(string name="sub_monitor",uvm_component parent);
 super.new(name,parent);
 	req=new("req",this);
	res=new("res",this);
 endfunction
 
 function void build_phase(uvm_phase phase);
if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
`uvm_fatal("FATAL","FROM SUB_MONITOR CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
endfunction

function void connect_phase(uvm_phase phase);
vif=agt_cfg.sub_intf;
endfunction


task run_phase(uvm_phase phase);
	fork
		begin
			if(vif.sub_mon_cb.awvalid && vif.sub_mon_cb.awready) begin
				fork
				monitor_aw();
				monitor_w();
				join
				end
			else if(vif.sub_mon_cb.arvalid && vif.sub_mon_cb.arready) 
				monitor_ar;
		end
		begin
			if(vif.sub_mon_cb.bvalid && vif.sub_mon_cb.bready)
				monitor_b;
			else if(vif.sub_mon_cb.rvalid && vif.sub_mon_cb.rready)
				monitor_r;
		
		end
	 
	join
		endtask
		
		task monitor_aw();
			//axi_xtn txnh;
		forever begin
			@(vif.sub_mon_cb);
			if(vif.sub_mon_cb.awvalid && vif.sub_mon_cb.awready)
				begin
					txnh=axi_xtn::type_id::create("txnh");
					txnh.addr=vif.sub_mon_cb.awaddr;
					txnh.id=vif.sub_mon_cb.awid;
					txnh.len=vif.sub_mon_cb.awlen;
					txnh.size=vif.sub_mon_cb.arsize;
					txnh.burst=vif.sub_mon_cb.awburst;
				//	txnh.rready=vif.sub_mon_cb.rready;
				//	txnh.bready=vif.sub_mon_cb.bready;
					req.write(txnh);
				end
				end
		endtask
		
		task monitor_w();
			int beat_count;
				beat_count=txnh.len+1;
				repeat(beat_count)
			if(vif.sub_mon_cb.awvalid && vif.sub_mon_cb.awready)
					begin
					txnh=axi_xtn::type_id::create("txnh");
					@(vif.sub_mon_cb);
					if(vif.sub_mon_cb.wvalid && vif.sub_mon_cb.wready) begin
				//	txnh.data.push_back(vif.sub_mon_cb.wdata);
				//	txnh.strb.push_back(vif.sub_mon_cb.wstrb);
					if(vif.sub_mon_cb.wlast)
					break;
					req.write(txnh);
					end
					end
					
		endtask
		
		task monitor_ar();
			forever begin
				txnh=axi_xtn::type_id::create("txnh");
					@(posedge vif.sub_mon_cb);
					if(vif.sub_mon_cb.arvalid && vif.sub_mon_cb.arready)
						begin
							txnh.addr=vif.sub_mon_cb.araddr;
							txnh.id=vif.sub_mon_cb.arid;
							txnh.len=vif.sub_mon_cb.arlen;
							txnh.size=vif.sub_mon_cb.arsize;
							txnh.burst=vif.sub_mon_cb.arburst;
						req.write(txnh);
						end
						end
		endtask
		
		task monitor_b();
		forever begin
			@(vif.sub_mon_cb);
			if(vif.sub_mon_cb.bvalid && vif.sub_mon_cb.bready)
				begin
					txnh=axi_xtn::type_id::create("txnh");
					txnh.id=vif.sub_mon_cb.bid;
					txnh.resp=vif.sub_mon_cb.bresp;
				
				res.write(txnh);
				end
			end
		endtask
		
		
		task monitor_r();
		forever begin
		@(vif.sub_mon_cb);
		if(vif.sub_mon_cb.rvalid && vif.sub_mon_cb.rready)
		begin
		txnh=axi_xtn::type_id::create("txnh");
			txnh.id=vif.sub_mon_cb.rid;
		//	txnh.data.push_back(vif.sub_mon_cb.rdata);
			txnh.resp=vif.sub_mon_cb.rresp;
		if(vif.sub_mon_cb.rlast)
			res.write(txnh);
		end
		end
		endtask

 
 endclass