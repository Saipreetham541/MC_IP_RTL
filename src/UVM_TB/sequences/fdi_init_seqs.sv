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
			assert(fditxn.randomize() with {opcode == 4'h4;
											credit_rtn_vcn == vcn_list[i]; 
											credit_rtn_cnt == 6'd32; 
											})
`uvm_info("SEQ_DEBUG",
  $sformatf("Loop i=%0d credit_rtn_vcn=%0d", i, fditxn.credit_rtn_vcn),
  UVM_LOW)		
			else begin
				`uvm_error("FDI_INIT", "Randomization failed")
					
			end
			finish_item(fditxn);
					//#50;
	
    end

  endtask

endclass