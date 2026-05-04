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



  int total_cnt, pass_cnt, fail_cnt;
  int total_expected_cnt, total_actual_cnt;
  int unexpected_actual_tnx, pending_expected_txn;

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
      total_actual_cnt++;
      key = make_key_for_axi_rsp(act_axi,port);

      if (!exp_axi_rsp_db.exists(key) || exp_axi_rsp_db[key].size() == 0) begin
        `uvm_error("CMP", $sformatf("Unexpected AXI SUB RSP  packet key=%s", key))
        unexpected_actual_tnx++;
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
      total_actual_cnt++;
      key = make_key_for_axi_req(act_axi,port);

      $display("\n[cmp] collect_act_mgr_req\n");
      $display(act_axi.convert2string);
      $display("\n\n");

      if (!exp_axi_req_db.exists(key) || exp_axi_req_db[key].size() == 0) begin
        `uvm_error("CMP", $sformatf("Unexpected AXI MGR REQ  packet key=%s", key))
        unexpected_actual_tnx++;
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
      total_actual_cnt++;
      key = make_key_for_fdi(act_pkt);

      $display("\n[CMP] collect_act_fdi_tx\n");
      $display(act_pkt.convert2string);
      $display("\n\n");
      //$display("\n\n\n\n\ncollect_act_fdi_tx\n\n\n\n\n\n");
      //$display(act_pkt.credit_rtn_vcn);
      //$display(key);
      //$display("\n\n\n\n\n\n\n\n\n\n\n");

      if (!exp_fdi_tx_db.exists(key) || exp_fdi_tx_db[key].size() == 0) begin
        `uvm_error("\n[CMP", $sformatf("Unexpected FDI TX packet key=%s\n\n", key))
        unexpected_actual_tnx++;
        fail_cnt++;
        total_cnt++;
        `uvm_info("\n\n[CMP collect_act_fdi_tx",act_pkt.convert2string(),UVM_LOW)
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
      total_expected_cnt++;
      key = make_key_for_axi_rsp(exp_axi,port);
      exp_axi_rsp_db[key].push_back(exp_axi);
      $display("\n[cmp] collect_exp_sub_rsp\n");
      $display(exp_axi.convert2string);
      $display("\n\n");
    end
  endtask 

  task collect_exp_mgr_req(int port);
    axi4_seq_item exp_axi;
    string key;
    forever begin
      exp_mgr_req_fifo[port].get(exp_axi);
      total_expected_cnt++;
      key = make_key_for_axi_req(exp_axi,port);
      exp_axi_req_db[key].push_back(exp_axi);
      $display("\n[cmp] collect_exp_mgr_req\n");
      $display(exp_axi.convert2string);
      $display("\n\n");
    end    
  endtask 

  task collect_exp_fdi_tx(); 
    fdi_pkt_item exp_pkt;
    string key;
    forever begin
      exp_fdi_tx_fifo.get(exp_pkt);
      total_expected_cnt++;
      key = make_key_for_fdi(exp_pkt);
      exp_fdi_tx_db[key].push_back(exp_pkt);
      //$display("\n\n\n\n\ncollect_exp_fdi_tx\n\n\n\n\n\n");
      //$display(exp_pkt.credit_rtn_vcn);
      //$display(key);
      //$display("\n\n\n\n\n\n\n\n\n\n\n");
      $display("\n[CMP] collect_exp_fdi_tx\n");
      $display(exp_pkt.convert2string);
      $display("\n\n");
    end
  endtask 
  
  //KEY CREATION FUNCTIONS

  function string make_key_for_fdi(fdi_pkt_item pkt);
    if (pkt.opcode == CREDIT_RTN) begin
      return $sformatf("fdi_credit_rtn_op%0d_vcn%0d_cnt%d", pkt.opcode, pkt.credit_rtn_vcn, pkt.credit_rtn_cnt);
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
    //foreach (exp.strb[0][i])
      //$display("[cmp] compare_axi_req exp_strobe [%0d] == %0d  | act_strobe [%0d] == %0d",i,exp.strb[0][i],i,act.strb[0][i]);
    if (!pass) begin

      `uvm_error("\n[CMP_AXI_REQ",
        $sformatf("\nAXI REQ PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))

    end
    else begin
      `uvm_info("\n[CMP_AXI_REQ",
        $sformatf("\nAXI REQ PACKET MATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()),UVM_LOW)
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
    //foreach (exp.strb[0][i])
      //$display("[cmp] compare_axi_req exp_strobe [%0d] == %0d  | act_strobe [%0d] == %0d",i,exp.strb[0][i],i,act.strb[0][i]);

    if (!pass) begin

      `uvm_error("\n[CMP_AXI_RSP",
        $sformatf("\nAXI RSP PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))

    end
    else begin
      `uvm_info("\n[CMP_AXI_RSP",
        $sformatf("\nAXI RSP PACKET MATCH \nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()),UVM_LOW)
    end
    return pass;
  endfunction

  function bit compare_fdi_pkt_item(fdi_pkt_item exp, fdi_pkt_item act);
    bit pass = 1;

    case (exp.opcode)
      CREDIT_RTN: begin
        if (exp.opcode         !== act.opcode)         pass = 0;
        if (exp.credit_rtn_cnt !== act.credit_rtn_cnt) pass = 0;
        if (exp.credit_rtn_vcn !== act.credit_rtn_vcn) pass = 0;
        //$display("\n\n\n\n\ncompare_fdi_pkt_item\n\n\n\n\n\n");
        //$display(exp.credit_rtn_vcn);
        //$display("\n\n\n\n\n\n\n\n\n\n\n");
      end

      WRITE_REQ, READ_REQ: begin
        if (exp.vcn         !== act.vcn)         pass = 0;
        if (exp.opcode      !== act.opcode)      pass = 0;
        if (exp.port_id     !== act.port_id)     pass = 0;
        if (exp.txn_id      !== act.txn_id)      pass = 0;
        if (exp.burst_len   !== act.burst_len)   pass = 0;
        if (exp.burst_type  !== act.burst_type)  pass = 0;
        if (exp.burst_size  !== act.burst_size)  pass = 0;
        if (exp.resp        !== act.resp)        pass = 0;
        if (exp.addr        !== act.addr)        pass = 0;
        if (exp.data        !=  act.data)        pass = 0;
        if (exp.wstrb       !=  act.wstrb)       pass = 0;
        //foreach (exp.wstrb[0][i])
      //$display("[cmp] compare_axi_req exp_wstrobe [%0d] == %0d  | act_strobe [%0d] == %0d",i,exp.wstrb[0][i],i,act.wstrb[0][i]);
      end

      WRITE_RESP, READ_RESP: begin
        if (exp.vcn         !== act.vcn)         pass = 0;
        if (exp.opcode      !== act.opcode)      pass = 0;
        if (exp.port_id     !== act.port_id)     pass = 0;
        if (exp.txn_id      !== act.txn_id)      pass = 0;
        if (exp.resp        !== act.resp)        pass = 0;
        if (exp.data        !=  act.data)        pass = 0;
      end
    endcase

    if (!pass) begin

      `uvm_error("\n[CMP_FDI",
        $sformatf("\nFDI PACKET MISMATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()))
    end
    else begin
      `uvm_info("\n[CMP_FDI",
        $sformatf("\nFDI PACKET MATCH\nEXPECTED:\n%s\nACTUAL:\n%s",
        exp.convert2string(),
        act.convert2string()),UVM_LOW)
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
          $sformatf("\n\nUnmatched expected AXI SUB RSP packets remain: key=%s count=%0d\n",
                    key, exp_axi_rsp_db[key].size()))
      end
    end

    foreach (exp_axi_req_db[key]) begin
      if (exp_axi_req_db[key].size() != 0) begin
        pending_req = pending_req + exp_axi_req_db[key].size();
        `uvm_error("CMPCHK",
          $sformatf("\n\nUnmatched expected AXI MGR REQ packets remain: key=%s count=%0d\n",
                    key, exp_axi_req_db[key].size()))
      end
    end

    foreach (exp_fdi_tx_db[key]) begin
      if (exp_fdi_tx_db[key].size() != 0) begin
        pending_fdi = pending_fdi + exp_fdi_tx_db[key].size();
        `uvm_error("CMPCHK",
          $sformatf("\n\nUnmatched expected FDI TX packets remain: key=%s count=%0d\n",
                    key, exp_fdi_tx_db[key].size()))
      end
    end

    pending_total = pending_rsp + pending_req + pending_fdi;
    pending_expected_txn = pending_total;
    if (pending_total != 0) begin
      fail_cnt  = fail_cnt+pending_total;
      total_cnt = total_cnt+pending_total;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    uvm_component test_h;
    string test_name;
    string test_status;

    super.report_phase(phase);

    test_h = uvm_root::get().find("uvm_test_top");
    if (test_h != null)
      test_name = test_h.get_type_name();
    else
      test_name = "UNKNOWN_TEST";

    test_status = (fail_cnt == 0) ? "PASSED" : "FAILED";

    if (fail_cnt != 0) begin
      `uvm_error("CMP_SUMMARY",
        $sformatf("\n\n\n\nComparator summary:\n  test name                       = %s\n  test status                     = %s\n  total comparisons               = %0d\n  pass comparisons                = %0d\n  fail comparisons                = %0d\n  total expected transactions     = %0d\n  total actual transactions       = %0d\n  total unmatched actual txns     = %0d\n  total pending expected txns     = %0d\n\n\n",
                  test_name, test_status,
                  total_cnt, pass_cnt, fail_cnt,
                  total_expected_cnt, total_actual_cnt,
                  unexpected_actual_tnx, pending_expected_txn))
    end
    else begin
      `uvm_info("CMP_SUMMARY",
        $sformatf("\n\n\nComparator summary:\n  test name                       = %s\n  test status                     = %s\n  total comparisons               = %0d\n  pass comparisons                = %0d\n  fail comparisons                = %0d\n  total expected transactions     = %0d\n  total actual transactions       = %0d\n  total unmatched actual txns     = %0d\n  total pending expected txns     = %0d\n\n\n",
                  test_name, test_status,
                  total_cnt, pass_cnt, fail_cnt,
                  total_expected_cnt, total_actual_cnt,
                  unexpected_actual_tnx, pending_expected_txn),
        UVM_LOW)
    end
  endfunction

endclass
