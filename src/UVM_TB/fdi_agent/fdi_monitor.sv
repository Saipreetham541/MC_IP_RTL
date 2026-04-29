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
    super.build_phase(phase);
    if(!uvm_config_db#(fdi_agt_config)::get(this,"","fdi_agt_config",fdi_cfg))
    `uvm_fatal("FATAL","FROM FDI_MONITOR CLASS")
    if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
    `uvm_fatal("FATAL","FROM RESET INTERFACE")

    if(!uvm_config_db#(fdi_credit_manager) :: get(this, "", "fdi_credit_manager",credit_mgr))
    `uvm_fatal("fdi_driver", "credit get is failed")
  endfunction


  function void connect_phase(uvm_phase phase);
	super.connect_phase(phase);
    vif=fdi_cfg.fdi_intf;
  endfunction
  
  
  
  task run_phase(uvm_phase phase);
    wait(vif.global_reset && vif.fdi_rst_n);
    wait(vif.fdi_mon_cb.fdi_pl_state_sts == 3'b010);
      forever begin
        @(vif.fdi_mon_cb);
        if(vif.fdi_mon_cb.fdi_pl_valid && 
           vif.fdi_mon_cb.fdi_pl_irdy &&
           vif.fdi_mon_cb.fdi_lp_trdy &&
           vif.fdi_mon_cb.fdi_pl_startofpkt) begin

            monitor_pl_to_lp(); // fdi -> dut

           end

        if(vif.fdi_mon_cb.fdi_lp_valid      &&
              vif.fdi_mon_cb.fdi_lp_irdy       &&
              vif.fdi_mon_cb.fdi_pl_trdy       &&
              vif.fdi_mon_cb.fdi_lp_startofpkt) begin

              monitor_lp_to_pl(); // dut -> fdi
        end
      end
  endtask

  // PL -> LP
  task monitor_pl_to_lp();
    bit [2047:0] flit;
    fdi_pkt_item txn;
   
      txn = fdi_pkt_item::type_id::create("txn_pl2lp");
      txn.data = new[0];
      txn.wstrb = new[0];

      flit = vif.fdi_mon_cb.fdi_pl_data;

      decode_header(flit, txn);
      collect_payload(flit, txn);

      if(txn.opcode == 4'h4)
        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt);

      txn.print();
      ap_rx.write(txn);
  endtask

  // LP -> PL
  task monitor_lp_to_pl();
    bit [2047:0] flit;
    fdi_pkt_item txn;
   
      txn = fdi_pkt_item::type_id::create("txn_lp2pl");
      txn.data = new[0];
      txn.wstrb = new[0];

      flit = vif.fdi_mon_cb.fdi_lp_data;
  
      decode_header(flit, txn);
      
      collect_payload(flit, txn);

      if(txn.opcode == 4'h4)
        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt);

      txn.print();
      ap_tx.write(txn);

  endtask

  function void decode_header(bit [2047:0] flit, ref fdi_pkt_item txn);
    txn.vcn            = flit[5:3];
    txn.opcode         = flit[11:8];
    txn.port_id        = flit[12];
    txn.txn_id         = flit[20:13];
    txn.burst_len      = flit[28:21];
    txn.burst_type     = flit[30:29];
    txn.burst_size     = flit[33:31];
    txn.resp           = flit[35:34];
    if (txn.opcode == 4'h2 || txn.opcode == 4'h3) 
      txn.resp         = flit[31:30];
    txn.addr           = flit[84:45];
    txn.credit_rtn_cnt = flit[43:38];
    txn.credit_rtn_vcn = flit[37:36];
  endfunction

  function void collect_payload (bit [2047:0] flit, ref fdi_pkt_item txn);
    bit [1727:0] temp_data;
    int old_size;

    if (!(txn.opcode == 4'h0 || txn.opcode == 4'h3))
      return;

    temp_data = flit[1983:256];
    txn.data = new[216];

    for(int i = 0; i < txn.data.size(); i++) begin
      txn.data[i] = temp_data[(i*8) +: 8];
    end

    if (txn.opcode == 4'h0 && flit[44]) begin
      txn.wstrb = new[1];
      txn.wstrb[0] = flit[255:128];
    end
  endfunction
endclass

 
