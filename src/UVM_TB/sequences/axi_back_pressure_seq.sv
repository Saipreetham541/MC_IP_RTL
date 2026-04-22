class axi_back_pressure_seq extends sub_sequence;
	`uvm_object_utils(axi_back_pressure_seq)
	axi_xtn txn;
	
	function new(string name="axi_back_pressure_seq");
		super.new(name);
	endfunction
	
	task body();
		repeat(50) begin
			txn=axi_xtn::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass