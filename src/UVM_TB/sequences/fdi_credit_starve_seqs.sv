class fdi_credit_starve_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_credit_starve_seqs)
	fdi_pkt_item fditxn;
	
	function new(string name="fdi_credit_starve_seqs");
		super.new(name);
	endfunction	
	
	task body();
		forever begin
		  fditxn=fdi_pkt_item:: type_id:: create("fditxn");
		  start_item(fditxn);
		  assert(fditxn.randomize() with{credit_rtn_cnt==0;
										 credit_rtn_vcn==0;});
		  finish_item(fditxn);
		end
	endtask
endclass