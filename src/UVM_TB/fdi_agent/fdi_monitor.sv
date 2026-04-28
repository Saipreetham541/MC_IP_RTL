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
    vif=fdi_cfg.fdi_intf;
  endfunction
  
  
  
  task run_phase(uvm_phase phase);
    wait(vif.global_reset && vif.fdi_rst_n);
    wait(vif.fdi_mon_cb.fdi_pl_state_sts == 3'b010);

    fork
      monitor_pl_to_lp(); // fdi -> dut
      monitor_lp_to_pl(); // dut -> fdi
    join
  endtask

  // PL -> LP
  task monitor_pl_to_lp();
    bit [2047:0] flit;
    fdi_pkt_item txn;
   // int count = 0;

    forever begin
      txn = fdi_pkt_item::type_id::create("txn_pl2lp");
      txn.data = new[0];
      txn.wstrb = new[0];

      do begin
        @(vif.fdi_mon_cb);
      end
      while(!(vif.fdi_mon_cb.fdi_pl_valid      &&
              vif.fdi_mon_cb.fdi_pl_irdy       &&
              vif.fdi_mon_cb.fdi_lp_trdy       &&
              vif.fdi_mon_cb.fdi_pl_startofpkt));

      flit = vif.fdi_mon_cb.fdi_pl_data;
     // count = count + 1;
     // $display("//////////////////// [mon] pl -> lp count = %0d ////////////////////", count);

      decode_header(flit, txn);
      collect_payload_pl(flit, txn);

      while(!(vif.fdi_mon_cb.fdi_pl_valid      &&
              vif.fdi_mon_cb.fdi_pl_irdy       &&
              vif.fdi_mon_cb.fdi_lp_trdy       &&
              vif.fdi_mon_cb.fdi_pl_endofpkt)) begin
        @(vif.fdi_mon_cb);

        if(vif.fdi_mon_cb.fdi_pl_valid &&
           vif.fdi_mon_cb.fdi_pl_irdy  &&
           vif.fdi_mon_cb.fdi_lp_trdy) begin
          flit = vif.fdi_mon_cb.fdi_pl_data;
          collect_payload_pl(flit, txn);
        end
      end

      if(txn.opcode == 4'h4)
        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt);

      txn.print();
      ap_rx.write(txn);
    end
  endtask

  // LP -> PL
  task monitor_lp_to_pl();
    bit [2047:0] flit;
    fdi_pkt_item txn;
    //int count = 0;

    forever begin
      txn = fdi_pkt_item::type_id::create("txn_lp2pl");
      txn.data = new[0];
      txn.wstrb = new[0];

      do begin
        @(vif.fdi_mon_cb);
      end
      while(!(vif.fdi_mon_cb.fdi_lp_valid      &&
              vif.fdi_mon_cb.fdi_lp_irdy       &&
              vif.fdi_mon_cb.fdi_pl_trdy       &&
              vif.fdi_mon_cb.fdi_lp_startofpkt));

      flit = vif.fdi_mon_cb.fdi_lp_data;
     // count = count + 1;
      //$display("//////////////////// [mon] lp -> pl count = %0d ////////////////////", count);

      decode_header(flit, txn);
      collect_payload_lp(flit, txn);

      while(!(vif.fdi_mon_cb.fdi_lp_valid      &&
              vif.fdi_mon_cb.fdi_lp_irdy       &&
              vif.fdi_mon_cb.fdi_pl_trdy       &&
              vif.fdi_mon_cb.fdi_lp_endofpkt)) begin
        @(vif.fdi_mon_cb);

        if(vif.fdi_mon_cb.fdi_lp_valid &&
           vif.fdi_mon_cb.fdi_lp_irdy  &&
           vif.fdi_mon_cb.fdi_pl_trdy) begin
          flit = vif.fdi_mon_cb.fdi_lp_data;
          collect_payload_lp(flit, txn);
        end
      end

      if(txn.opcode == 4'h4)
        credit_mgr.add_credit(txn.credit_rtn_vcn, txn.credit_rtn_cnt);

      txn.print();
      ap_tx.write(txn);
    end
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
    if ((txn.opcode == 4'h2 || txn.opcode == 4'h3) && txn.resp == '0)
      txn.resp         = flit[31:30];
    txn.addr           = flit[84:45];
    txn.credit_rtn_cnt = flit[43:38];
    txn.credit_rtn_vcn = flit[37:36];
  endfunction

  function void collect_payload_pl(bit [2047:0] flit, ref fdi_pkt_item txn);
    bit [1727:0] temp_data;
    int old_size;

    if (!(txn.opcode == 4'h0 || txn.opcode == 4'h3))
      return;

    temp_data = flit[1983:256];
    old_size  = txn.data.size();

    txn.data = new[old_size + 216](txn.data);

    for(int i = 0; i < 216; i++) begin
      txn.data[old_size + i] = temp_data[(i*8) +: 8];
    end

    if (txn.opcode == 4'h0 && flit[44]) begin
      txn.wstrb = new[1];
      txn.wstrb[0] = flit[255:128];
    end
  endfunction

  function void collect_payload_lp(bit [2047:0] flit, ref fdi_pkt_item txn);
    bit [1023:0] temp_data;
    int old_size;

    txn.wstrb = new[0];

    if (txn.opcode == 4'h0 && flit[44]) begin
      txn.wstrb = new[1];
      txn.wstrb[0] = flit[255:128];
    end

    if (!(txn.opcode == 4'h0 || txn.opcode == 4'h3))
      return;

    temp_data = flit[1983:960];
    old_size  = txn.data.size();

    txn.data = new[old_size + 128](txn.data);

    for (int i = 0; i < 128; i++) begin
      txn.data[old_size + i] = temp_data[(i*8) +: 8];
    end
  endfunction

endclass

 
