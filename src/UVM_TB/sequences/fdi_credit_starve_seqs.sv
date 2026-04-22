class fdi_credit_starve_seqs extends sub_sequence;
	`uvm_object_utils(fdi_credit_starve_seqs)
	fdi_xtn fditxn;
	
	function new(string name="fdi_credit_starve_seqs");
		super.new(name);
	endfunction	
	
	task body();
		forever begin
		  fditxn=fdi_xtn:: type_id:: create("fditxn");
		  start_item(fditxn);
		  assert(fditxn.randomize() with{credit_rtn_cnt==0;
										 credit_rtn_vcn==0;});
		  finish_item(fditxn);
		end
	endtask
endclass