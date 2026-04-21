//mgr-monitor

class mgr_monitor extends uvm_monitor;
 `uvm_component_utils(mgr_monitor)
 axi_agt_config agt_cfg;
 virtual mgr_interface.MGR_MON_MP vif;
 
 virtual reset_interface rst_intf;
 axi_xtn txnh;
 		uvm_analysis_port#(axi_xtn) req1;
		uvm_analysis_port#(axi_xtn) res1;
		
 
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
		txnh = axi_xtn::type_id::create("txnh");

		 fork
			monitor_b(txnh);
			monitor_r(txnh);
			monitor_aw(txnh);
			monitor_ar(txnh);
			monitor_w(txnh);
		join
		endtask
		
		task monitor_r(axi_xtn txnh);
		//axi_xtn txn;
		forever begin
		@(vif.mgr_mon_cb)
		if(vif.mgr_mon_cb.rvalid && vif.mgr_mon_cb.rready) begin

        //txnh = axi_xtn::type_id::create("txnh");
		txnh.id=vif.mgr_mon_cb.rid;
		foreach(txnh.data[i]) begin
		txnh.data[i]=vif.mgr_mon_cb.rdata;
		//txnh.ready=vif.mgr_mon_cb.arready;
		if(vif.mgr_mon_cb.rlast)
		$display("packet");
		end
		
		txnh.resp=vif.mgr_mon_cb.rresp;
		res1.write(txnh);
		end
		end
		endtask
		
		task monitor_b(axi_xtn txnh);
		//axi_xtn txnh;
		forever begin
		@(vif.mgr_mon_cb)
		if(vif.mgr_mon_cb.bvalid && vif.mgr_mon_cb.bready) begin
			//txnh = axi_xtn::type_id::create("txnh");
			 txnh.id    = vif.mgr_mon_cb.bid;
			txnh.resp = vif.mgr_mon_cb.bresp;
			//txnh.ready=vif.mgr_mon_cb.awready;
			//txnh.ready=vif.mgr_mon_cb.wraedy;
			res1.write(txnh);
			end
			end
		endtask
		
		
		task monitor_aw(axi_xtn txnh);
		//axi_xtn txnh;
		forever begin
		@( vif.mgr_mon_cb)
		if(vif.mgr_mon_cb.awvalid && vif.mgr_mon_cb.awready) begin
		//txnh = axi_xtn::type_id::create("txnh");
		
		txnh.addr  = vif.mgr_mon_cb.awaddr;
        txnh.id    = vif.mgr_mon_cb.awid;
        txnh.len   = vif.mgr_mon_cb.awlen;
        txnh.size  = vif.mgr_mon_cb.awsize;
        txnh.burst = vif.mgr_mon_cb.awburst;
		
		req1.write(txnh);
		
		end
		
		end
		endtask
		int i=0;
		task monitor_w(axi_xtn txnh);
		int beat_count1;
		beat_count1=vif.mgr_mon_cb.awlen+1;//6
		while( i<=vif.mgr_mon_cb.awlen)//0=6
		begin
		@(vif.mgr_mon_cb)
		if(vif.mgr_mon_cb.wvalid && vif.mgr_mon_cb.wready) begin
		  txnh.data[i]=vif.mgr_mon_cb.wdata;
		txnh.strb[i]=vif.mgr_mon_cb.wstrb;
		
		if(vif.mgr_mon_cb.wlast)
		$display("packet ended");
		i=i+1;
		
		end
		req1.write(txnh);
		end
		endtask
		
		task monitor_ar(axi_xtn txnh);
		forever begin
		@(vif.mgr_mon_cb)
		if(vif.mgr_mon_cb.arvalid && vif.mgr_mon_cb.arready) begin
		txnh = axi_xtn::type_id::create("txnh");
		txnh.addr=vif.mgr_mon_cb.araddr;
		txnh.id=vif.mgr_mon_cb.arid;
		txnh.len=vif.mgr_mon_cb.arlen;
		txnh.size=vif.mgr_mon_cb.arsize;
		txnh.burst=vif.mgr_mon_cb.arburst;
		req1.write(txnh);
		end
		end
		endtask
 
 endclass