//mgr-monitor

class mgr_monitor extends uvm_monitor;
	`uvm_component_utils(mgr_monitor)
	axi_agt_config agt_cfg;
	virtual mgr_interface.MGR_MON_MP vif;
	
	virtual reset_interface rst_intf;
	axi4_seq_item txnh;
			uvm_analysis_port#(axi4_seq_item) req1;
			uvm_analysis_port#(axi4_seq_item) res1;
			
	
	function new(string name="mgr_monitor",uvm_component parent);
		super.new(name,parent);
		req1=new("req1",this);
		res1=new("res1",this);
	endfunction
	
	function void build_phase(uvm_phase phase);
		if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
			`uvm_fatal("FATAL","FROM MGR_MONITOR CLASS")
		if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
			`uvm_fatal("FATAL","FROM RESET INTERFACE")

	endfunction

	function void connect_phase(uvm_phase phase);
		vif=agt_cfg.mgr_intf;
	endfunction

	task run_phase(uvm_phase phase);


	wait(vif.axi_rst_n && vif.global_reset);

		if(agt_cfg.typ == axi_agt_config::REQ ) begin
			monitor_aw_w();
			monitor_ar();
		end
		else begin
			monitor_b();
			monitor_r();
		end
	endtask

	task monitor_aw_w();
		forever begin
			txnh = axi4_seq_item::type_id::create("txnh");
			@(vif.mgr_mon_cb);
			//$display("////////////////////////////[mgr_mon] monitor_aw_w//////////////////////////////");
			if(vif.mgr_mon_cb.awvalid && vif.mgr_mon_cb.awready) begin
				txnh.addr  = vif.mgr_mon_cb.awaddr;
				txnh.id    = vif.mgr_mon_cb.awid;
				txnh.len   = vif.mgr_mon_cb.awlen;
				txnh.size  = vif.mgr_mon_cb.awsize;
				txnh.burst = vif.mgr_mon_cb.awburst;
				txnh.axn_type=WRITE;
				//$display("??????????????????????????[mgr_mon] monitor_aw_w??????????????????????????????????");

			end

			if(vif.mgr_mon_cb.wvalid && vif.mgr_mon_cb.wready) begin
				txnh.data = new[txnh.data.size()+1](txnh.data);
				txnh.strb = new[txnh.strb.size()+1](txnh.strb);
				txnh.data[0] = vif.mgr_mon_cb.wdata;
				txnh.strb[0] = vif.mgr_mon_cb.wstrb;
				
				//foreach (vif.mgr_mon_cb.wstrb[i])
      			//	$display("[mgr_mon] monitor_aw_w vif.mgr_mon_cb.wstrb[%0d] == %0d",i,vif.mgr_mon_cb.wstrb[i]);
				txnh.axn_type=WRITE;
				if(vif.mgr_mon_cb.wlast) begin
					req1.write(txnh);
					txnh.display();
				end
				//$display("+++++++++++++++++++++++++++++++++++[mgr_mon] monitor_aw_w+++++++++++++++++++++++++++=");
				//req1.write(txnh);
				//txnh.display();
			end
			
		end
	endtask
		
	task monitor_r();
		forever begin
			@(vif.mgr_mon_cb);
			if(vif.mgr_mon_cb.rvalid && vif.mgr_mon_cb.rready)begin
			txnh=axi4_seq_item::type_id::create("txnh");
				txnh.id=vif.mgr_mon_cb.rid;
			//	txnh.data.push_back(vif.mgr_mon_cb.rdata);
				txnh.resp=vif.mgr_mon_cb.rresp;
			if(vif.mgr_mon_cb.rlast)
				res1.write(txnh);
			end
		end
	endtask
		
	task monitor_b();
		forever begin
			@(vif.mgr_mon_cb);
			if(vif.mgr_mon_cb.bvalid && vif.mgr_mon_cb.bready)begin
				txnh=axi4_seq_item::type_id::create("txnh");
				txnh.id=vif.mgr_mon_cb.bid;
				txnh.resp=vif.mgr_mon_cb.bresp;
				res1.write(txnh);
			end
		end
	endtask
		
		
	task monitor_ar();
		forever begin
			txnh=axi4_seq_item::type_id::create("txnh");
			@(vif.mgr_mon_cb);
			if(vif.mgr_mon_cb.arvalid && vif.mgr_mon_cb.arready)
				begin
					txnh.addr=vif.mgr_mon_cb.araddr;
					txnh.id=vif.mgr_mon_cb.arid;
					txnh.len=vif.mgr_mon_cb.arlen;
					txnh.size=vif.mgr_mon_cb.arsize;
					txnh.burst=vif.mgr_mon_cb.arburst;
					txnh.axn_type=READ;
					$display("\n[mgr_mon] monitor_ar\n");
					//$display(req.convert2string);
					$display("axn_type=%0s",txnh.axn_type);
					$display("\n\n");
					req1.write(txnh);
					
				end
			
		end		
	endtask
 
 endclass