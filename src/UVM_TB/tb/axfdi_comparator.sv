class axfdi_comparator extends uvm_component;

  `uvm_component_utils(axfdi_comparator)

  // INPUTS FROM SCOREBOARD/MONITORS
  uvm_analysis_export #(axi4_seq_item) act_sub_rsp_xp[2];
  uvm_analysis_export #(axi4_seq_item) act_mgr_req_xp[2];
  uvm_analysis_export #(fdi_pkt_item)  act_fdi_tx_xp;


  // INPUTS FROM PREDICTOR
  uvm_analysis_export #(axi4_seq_item) exp_sub_rsp_xp[2];
  uvm_analysis_export #(axi4_seq_item) exp_mgr_req_xp[2];
  uvm_analysis_export #(fdi_pkt_item)  exp_fdi_tx_xp;

  // FIFOS FOR MONITOR INPUTS
  uvm_tlm_analysis_fifo #(axi4_seq_item) act_sub_rsp_fifo[2];
  uvm_tlm_analysis_fifo #(axi4_seq_item) act_mgr_req_fifo[2];
  uvm_tlm_analysis_fifo #(fdi_pkt_item)  act_fdi_tx_fifo;

   // FIFOS FOR PREDICTOR INPUTS
  uvm_tlm_analysis_fifo #(axi4_seq_item) exp_sub_rsp_fifo[2];
  uvm_tlm_analysis_fifo #(axi4_seq_item) exp_mgr_req_fifo[2];
  uvm_tlm_analysis_fifo #(fdi_pkt_item)  exp_fdi_tx_fifo;

  //DATABASE

  axi4_seq_item exp_axi_rsp_db[string][$];
  axi4_seq_item exp_axi_req_db[string][$];
  fdi_pkt_item  exp_fdi_tx_db [string][$];


  typedef enum bit [3:0] {
        WRITE_REQ   = 4'h0,
        READ_REQ    = 4'h1,
        WRITE_RESP  = 4'h2,
        READ_RESP   = 4'h3,
        CREDIT_RTN  = 4'h4,
        NOP         = 4'h5,
        RESERVED    = 4'h6
  } opcode_e;

  typedef enum bit {
        WRITE = 1'b0 ,
        READ = 1'b1 
  } txn_type ;

  int total_cnt, pass_cnt, fail_cnt;

  function new(input string name = "axfdi_comparator",input uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase (uvm_phase phase);
    super.build_phase(phase);

    foreach (act_sub_rsp_xp[i]) begin

      act_sub_rsp_xp[i] = new ($sformatf("act_sub_rsp_xp[%0d]",i),this);
      act_mgr_req_xp[i] = new ($sformatf("act_mgr_req_xp[%0d]",i),this);
      exp_sub_rsp_xp[i] = new ($sformatf("exp_sub_rsp_xp[%0d]",i),this);
      exp_mgr_req_xp[i] = new ($sformatf("exp_mgr_req_xp[%0d]",i),this);

      act_sub_rsp_fifo[i] = new ($sformatf("act_sub_rsp_fifo[%0d]",i),this);
      act_mgr_req_fifo[i] = new ($sformatf("act_mgr_req_fifo[%0d]",i),this);
      exp_sub_rsp_fifo[i] = new ($sformatf("exp_sub_rsp_fifo[%0d]",i),this);
      exp_mgr_req_fifo[i] = new ($sformatf("exp_mgr_req_fifo[%0d]",i),this);

    end
    
    act_fdi_tx_xp   = new ("act_fdi_tx_xp",this);
    exp_fdi_tx_xp   = new ("exp_fdi_tx_xp",this);
    act_fdi_tx_fifo = new ("act_fdi_tx_fifo",this);
    exp_fdi_tx_fifo = new ("exp_fdi_tx_fifo",this);

  endfunction

  function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);

    foreach (act_sub_rsp_xp[i]) begin

      act_sub_rsp_xp[i].connect(act_sub_rsp_fifo[i].analysis_export);
      act_mgr_req_xp[i].connect(act_mgr_req_fifo[i].analysis_export);
      exp_sub_rsp_xp[i].connect(exp_sub_rsp_fifo[i].analysis_export);
      exp_mgr_req_xp[i].connect(exp_mgr_req_fifo[i].analysis_export);

    end

    act_fdi_tx_xp.connect(act_fdi_tx_fifo.analysis_export);
    exp_fdi_tx_xp.connect(exp_fdi_tx_fifo.analysis_export);

  endfunction

  task run_phase(uvm_phase phase);
    fork
      //COLLECT ACTUAL DATA
      collect_act_sub_rsp(0);
      collect_act_sub_rsp(1);
      collect_act_mgr_req(0);
      collect_act_mgr_req(1); 
      collect_act_fdi_tx(); 

      //COLLECT EXPECTED DATA
      collect_exp_sub_rsp(0);
      collect_exp_sub_rsp(1);
      collect_exp_mgr_req(0);
      collect_exp_mgr_req(1);
      collect_exp_fdi_tx();
    join
        
  endtask

    // ACTUAL INPUTS COLLECTOR TASKS

  task collect_act_sub_rsp(int port);
    axi4_seq_item act_axi,exp_axi;
    string key;
    bit pass;

    forever begin
      act_sub_rsp_fifo[port].get(act_axi);
      key = make_key_for_axi_rsp(act_axi,port);

      if (!exp_axi_rsp_db.exists(key) || exp_axi_rsp_db[key].size() == 0) begin
        `uvm_error("CMP", $sformatf("Unexpected AXI SUB RSP  packet key=%s", key))
        fail_cnt++;
        total_cnt++;
      end
      else begin
        exp_axi = exp_axi_rsp_db[key].pop_front();
        pass = compare_axi_rsp(exp_axi, act_axi);
        total_cnt++;
        if (pass) pass_cnt++;
        else fail_cnt++;
      end
    end 
        
  endtask 

  task collect_act_mgr_req(int port);
    axi4_seq_item act_axi,exp_axi;
    string key;
    bit pass;

    forever begin
      act_mgr_req_fifo[port].get(act_axi);
      key = make_key_for_axi_req(act_axi,port);

      if (!exp_axi_req_db.exists(key) || exp_axi_req_db[key].size() == 0) begin
        `uvm_error("CMP", $sformatf("Unexpected AXI MGR REQ  packet key=%s", key))
        fail_cnt++;
        total_cnt++;
      end
      else begin
        exp_axi = exp_axi_req_db[key].pop_front();
        pass = compare_axi_req(exp_axi, act_axi);
        total_cnt++;
        if (pass) pass_cnt++;
        else fail_cnt++;
      end
    end    
  endtask 

  task collect_act_fdi_tx();
    fdi_pkt_item act_pkt, exp_pkt;
  string key;
  bit pass;
  forever begin
    act_fdi_tx_fifo.get(act_pkt);
    key = make_key_for_fdi(act_pkt);

    $display("\n[CMP] collect_act_fdi_tx\n");
    $display(act_pkt.convert2string);
    $display("\n\n");

    if (!exp_fdi_tx_db.exists(key) || exp_fdi_tx_db[key].size() == 0) begin
      `uvm_error("\nCMP", $sformatf("\nUnexpected FDI TX packet key=%s\n\n", key))
      fail_cnt++;
      total_cnt++;

    `uvm_info("\nCMP collect_act_fdi_tx\n",act_pkt.convert2string(),UVM_LOW)

    end
    else begin
      exp_pkt = exp_fdi_tx_db[key].pop_front();
      pass = compare_fdi_pkt_item(exp_pkt, act_pkt);
      total_cnt++;
      if (pass) pass_cnt++;
      else      fail_cnt++;
    end
  end
  endtask

  // EXPEXTED INPUTS COLLECTOR TASKS

  task collect_exp_sub_rsp(int port);
    axi4_seq_item exp_axi;
    string key;
    forever begin
      exp_sub_rsp_fifo[port].get(exp_axi);
      key = make_key_for_axi_rsp(exp_axi,port);
      exp_axi_rsp_db[key].push_back(exp_axi);
    end
  endtask 

  task collect_exp_mgr_req(int port);
    axi4_seq_item exp_axi;
    string key;
    forever begin
      exp_mgr_req_fifo[port].get(exp_axi);
      key = make_key_for_axi_req(exp_axi,port);
      exp_axi_req_db[key].push_back(exp_axi);
    end    
  endtask 

  task collect_exp_fdi_tx(); 
    fdi_pkt_item exp_pkt;
    string key;
    forever begin
      exp_fdi_tx_fifo.get(exp_pkt);
      key = make_key_for_fdi(exp_pkt);
      exp_fdi_tx_db[key].push_back(exp_pkt);
    end
  endtask 
  
  //KEY CREATION FUNCTIONS

  function string make_key_for_fdi(fdi_pkt_item pkt);
    if (pkt.opcode == CREDIT_RTN) begin
      return $sformatf("fdi_credit_rtn_op%0d_rvcn%0d", pkt.opcode, pkt.credit_rtn_vcn);
    end
    return $sformatf("fdi_normal_txn_p%0d_op%0d_id%0d", pkt.port_id, pkt.opcode, pkt.txn_id);
  endfunction

  function string make_key_for_axi_rsp(axi4_seq_item rsp ,int port);
    string key;
    int port_id = port;
    key = (rsp.axn_type == WRITE) ? "WR_RSP" : "RD_RSP";
    return $sformatf("axi_rsp_p%0d_op%s_id%0h",port_id, key, rsp.id);
  endfunction


  function string make_key_for_axi_req (axi4_seq_item req ,int port);
    string key;
    int port_id = port;
    key = (req.axn_type == WRITE) ? "WR_REQ" : "RD_REQ";
    return $sformatf("axi_req_p%0d_%s_id%0d",port_id, key, req.id);
  endfunction

  // COMPARE FUNCTIONS

  function bit compare_axi_req(axi4_seq_item exp, axi4_seq_item act);
    bit pass = 1;
    if (exp.addr       != act.addr)       pass = 0;
    if (exp.id         != act.id)         pass = 0;
    if (exp.len        != act.len)        pass = 0;
    if (exp.size       != act.size)       pass = 0;
    if (exp.burst      != act.burst)      pass = 0;
    if (exp.data       != act.data)       pass = 0;
    if (exp.strb       != act.strb)       pass = 0;
    if (exp.resp       != act.resp)       pass = 0;
    if (exp.axn_type   != act.axn_type)   pass = 0;

    if (!pass) begin

      `uvm_error("CMP_AXI_REQ",
        $sformatf("\nAXI REQ PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))

    end
    return pass;
  endfunction


  function bit compare_axi_rsp(axi4_seq_item exp, axi4_seq_item act);
    bit pass = 1;
    if (exp.addr       != act.addr)       pass = 0;
    if (exp.id         != act.id)         pass = 0;
    if (exp.len        != act.len)        pass = 0;
    if (exp.size       != act.size)       pass = 0;
    if (exp.burst      != act.burst)      pass = 0;
    if (exp.data       != act.data)       pass = 0;
    if (exp.strb       != act.strb)       pass = 0;
    if (exp.resp       != act.resp)       pass = 0;
    if (exp.axn_type   != act.axn_type)   pass = 0;

    if (!pass) begin

      `uvm_error("CMP_AXI_RSP",
        $sformatf("\nAXI PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))

    end
    return pass;
  endfunction

  function bit compare_fdi_pkt_item(fdi_pkt_item exp, fdi_pkt_item act);
    bit pass = 1;

    if (exp.vcn              !== act.vcn)              pass = 0;
    if (exp.opcode           !== act.opcode)           pass = 0;
    if (exp.port_id          !== act.port_id)          pass = 0;
    if (exp.credit_rtn_cnt   !== act.credit_rtn_cnt)   pass = 0;
    if (exp.credit_rtn_vcn   !== act.credit_rtn_vcn)   pass = 0;

    case (exp.opcode)
      WRITE_REQ, READ_REQ: begin
        if (exp.txn_id      !== act.txn_id)      pass = 0;
        if (exp.burst_len   !== act.burst_len)   pass = 0;
        if (exp.burst_type  !== act.burst_type)  pass = 0;
        if (exp.burst_size  !== act.burst_size)  pass = 0;
        if (exp.resp        !== act.resp)        pass = 0;
        if (exp.addr        !== act.addr)        pass = 0;
        if (exp.data        !=  act.data)        pass = 0;
        if (exp.wstrb       !=  act.wstrb)       pass = 0;
      end

      WRITE_RESP, READ_RESP: begin
        if (exp.txn_id      !== act.txn_id)      pass = 0;
        if (exp.resp        !== act.resp)        pass = 0;
        if (exp.data        !=  act.data)        pass = 0;
      end

      CREDIT_RTN: begin
        // common + credit fields already checked
      end
    endcase

    if (!pass) begin

      `uvm_error("CMP_FDI",
        $sformatf("\nFDI PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))
    end

    return pass;
  endfunction

  function void check_phase(uvm_phase phase);
    string key;
    int pending_rsp = 0;
    int pending_req = 0;
    int pending_fdi = 0;
    int pending_total;

    super.check_phase(phase);

    foreach (exp_axi_rsp_db[key]) begin
      if (exp_axi_rsp_db[key].size() != 0) begin
        pending_rsp = pending_rsp + exp_axi_rsp_db[key].size();
        `uvm_error("CMPCHK",
          $sformatf("Unmatched expected AXI SUB RSP packets remain: key=%s count=%0d",
                    key, exp_axi_rsp_db[key].size()))
      end
    end

    foreach (exp_axi_req_db[key]) begin
      if (exp_axi_req_db[key].size() != 0) begin
        pending_req = pending_req + exp_axi_req_db[key].size();
        `uvm_error("CMPCHK",
          $sformatf("Unmatched expected AXI MGR REQ packets remain: key=%s count=%0d",
                    key, exp_axi_req_db[key].size()))
      end
    end

    foreach (exp_fdi_tx_db[key]) begin
      if (exp_fdi_tx_db[key].size() != 0) begin
        pending_fdi = pending_fdi + exp_fdi_tx_db[key].size();
        `uvm_error("CMPCHK",
          $sformatf("Unmatched expected FDI TX packets remain: key=%s count=%0d",
                    key, exp_fdi_tx_db[key].size()))
      end
    end

    pending_total = pending_rsp + pending_req + pending_fdi;
    if (pending_total != 0) begin
      fail_cnt  = fail_cnt+pending_total;
      total_cnt = total_cnt+pending_total;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (fail_cnt != 0) begin
      `uvm_error("CMP_SUMMARY",
        $sformatf("Comparator summary: total=%0d pass=%0d fail=%0d",
                  total_cnt, pass_cnt, fail_cnt))
    end
    else begin
      `uvm_info("CMP_SUMMARY",
        $sformatf("Comparator summary: total=%0d pass=%0d fail=%0d",
                  total_cnt, pass_cnt, fail_cnt),
        UVM_LOW)
    end
  endfunction

endclass
