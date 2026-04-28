class credit_starve_axi_seq extends uvm_sequence;
	`uvm_object_utils(credit_starve_axi_seq)
	axi4_seq_item txn;
	
	function new(string name="credit_starve_axi_seq");
		super.new(name);
	endfunction	
	
	task body();
		repeat(40)
		begin
			txn=axi4_seq_item::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass