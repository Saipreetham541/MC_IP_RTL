class fdi_init_seqs extends uvm_sequence#(fdi_pkt_item);
  `uvm_object_utils(fdi_init_seqs)

  fdi_pkt_item fditxn;

  int vcn_list[2] = '{0,1};

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
			else begin
				`uvm_error("FDI_INIT", "Randomization failed")
				
			end
		finish_item(fditxn);
		#50;
    end

  endtask

endclass