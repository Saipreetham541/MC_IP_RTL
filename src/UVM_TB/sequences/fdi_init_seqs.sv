class fdi_init_seqs extends uvm_sequence#(fdi_pkt_item);
  `uvm_object_utils(fdi_init_seqs)

  fdi_pkt_item fditxn;

  int vcn_list[2] = '{1,0};

  function new(string name="fdi_init_seqs");
    super.new(name);
  endfunction

  task body();
    foreach (vcn_list[i]) 
	
		begin
		
			fditxn = fdi_pkt_item::type_id::create($sformatf("fditxn_%0d", i));
			start_item(fditxn);
			if (!fditxn.randomize() with {

        opcode == 4'h4;
        credit_rtn_vcn == vcn_list[i];
        credit_rtn_cnt == 6'd32;

        addr == 40'd0;
        txn_id == 8'd0;
        burst_len == 8'd0; 
        vcn == 0;
        port_id == 0;
        burst_type == 0;
        burst_size == 0;
        resp == 0;

        backpressure_cycles == 0;
        startofpkt == 1;
        endofpkt == 1;

        // 🔥 ARRAY CONSTRAINTS
        data.size() == 0;
        wstrb.size() == 0;

      }) begin
        `uvm_fatal("RAND_FAIL", "FDI txn randomization failed")
      end
			finish_item(fditxn);
			//#50;
    end
  endtask
endclass