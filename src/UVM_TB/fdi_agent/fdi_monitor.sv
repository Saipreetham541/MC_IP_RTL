//fdi monitor

class fdi_monitor extends uvm_monitor;
 `uvm_component_utils(fdi_monitor)
 fdi_agt_config fdi_cfg;
 
 virtual fdi_interface.FDI_MON_MP vif;
 virtual reset_interface rst_intf;
 
 fdi_credit_manager credit_mgr;
 
   uvm_analysis_port #(fdi_pkt_item) ap_tx;
	uvm_analysis_port #(fdi_pkt_item) ap_rx;
 function new(string name="fdi_monitor",uvm_component parent);
 super.new(name,parent);
 ap_tx=new("ap_tx",this);
 ap_rx=new("ap_rx",this);
 
 endfunction
 
 function void build_phase(uvm_phase phase);
if(!uvm_config_db#(fdi_agt_config)::get(this,"","fdi_agt_config",fdi_cfg))
`uvm_fatal("FATAL","FROM FDI_MONITOR CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")

if(!uvm_config_db#(fdi_credit_manager) :: get(this, "", "fdi_credit_manager",credit_mgr))
`uvm_fatal("fdi_driver", "credit get is failed")
endfunction

function void connect_phase(uvm_phase phase);
vif=fdi_cfg.fdi_intf;
endfunction
 
 
 
 task run_phase(uvm_phase phase);

    fork
      monitor_pl_to_lp(); // fdi → DUt
      monitor_lp_to_pl(); // DUT → fdi
    join

  endtask

  // PL → LP 
  task monitor_pl_to_lp();

    bit [2047:0] flit;
    fdi_pkt_item txn;

    while(!(vif.global_reset && vif.fdi_rst_n))
	  @(vif.fdi_mon_cb);

    forever begin

     txn = fdi_pkt_item::type_id::create("txn_pl2lp");
      
      do begin
        @(vif.fdi_mon_cb);
      end 
	  while(!(vif.fdi_mon_cb.fdi_pl_valid && vif.fdi_mon_cb.fdi_pl_irdy  && vif.fdi_mon_cb.fdi_lp_trdy  &&  vif.fdi_mon_cb.fdi_pl_startofpkt)); // Wait for SOP

      flit = vif.fdi_mon_cb.fdi_pl_data;


      decode_header(flit, txn);
@(vif.fdi_mon_cb);
      while(!vif.fdi_mon_cb.fdi_pl_endofpkt) begin

        

        if(vif.fdi_mon_cb.fdi_pl_valid && vif.fdi_mon_cb.fdi_pl_irdy  && vif.fdi_mon_cb.fdi_lp_trdy)

          collect_payload(vif.fdi_mon_cb.fdi_pl_data,txn); 
		  // Capture payload
		  @(vif.fdi_mon_cb);
      end

      if(txn.opcode == 4'h4) begin
        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt);  // Credit return
      end
	  txn.print();
      ap_rx.write(txn);
    end
  endtask
  
  // LP - PL 

  task monitor_lp_to_pl();

    bit [2047:0] flit;
    fdi_pkt_item txn;

    forever begin

      txn = fdi_pkt_item::type_id::create("txn_lp2pl");

      do begin
        @(vif.fdi_mon_cb);
      end
	  
	  while(!(vif.fdi_mon_cb.fdi_lp_valid && vif.fdi_mon_cb.fdi_lp_irdy  && vif.fdi_mon_cb.fdi_pl_trdy  && vif.fdi_mon_cb.fdi_lp_startofpkt)); // Wait for SOP


      flit = vif.fdi_mon_cb.fdi_lp_data;  // Capture header flit

      decode_header(flit, txn);

 while(!vif.fdi_mon_cb.fdi_lp_endofpkt) begin

       

        if(vif.fdi_mon_cb.fdi_lp_valid &&  vif.fdi_mon_cb.fdi_lp_irdy  && vif.fdi_mon_cb.fdi_pl_trdy)

          collect_payload(vif.fdi_mon_cb.fdi_lp_data, txn);
		 @(vif.fdi_mon_cb);  
 end
	  
	  if(txn.opcode == 4'h4) begin

        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt );
  txn.print();
      ap_tx.write(txn);

    end
	end
  endtask

  //HEADEr

  function void decode_header(bit [2047:0]flit, ref fdi_pkt_item txn);

    txn.vcn = flit[5:3];
    txn.opcode = flit[11:8];
    txn.port_id = flit[12];
    txn.txn_id = flit[20:13];
    txn.burst_len = flit[28:21];
    txn.burst_type = flit[30:29];
    txn.burst_size = flit[33:31];
    txn.addr = flit[84:45];

    txn.credit_rtn_cnt = flit[43:38];
    txn.credit_rtn_vcn = flit[37:36];

  endfunction

  //PAYLOAD
  
  function void collect_payload(bit [2047:0]flit,ref fdi_pkt_item txn);

    for(int i=0;i<248;i++) begin
      txn.data[i]=(flit[(i*8) +: 8]);
    end

  endfunction

endclass

 