class single_write_seq extends uvm_sequence #(axi4_seq_item);
	`uvm_object_utils(single_write_seq)
	axi4_seq_item txn;
	
	function new(string name="single_write_seq");
		super.new(name);
	endfunction
	
	task body();
	//repeat(17) 
		begin
			txn=axi4_seq_item::type_id::create("txn");
			start_item(txn);
			if(!txn.randomize() with {axn_type==0;
										len==0;
										burst==2'b01;
										data.size() == len+1;
										strb.size() == len+1;
										foreach(strb[0][i]) {
											strb[0][i] == 'd1;
											}
							
										foreach (data[i]) {
											data[i][1023 : 1016 ] == 8'hAA;  // MSB byte
											data[i][1015:0]    == 'b0;      // remaining bits
										}
										})begin
        `uvm_fatal("RAND_FAIL", "FDI txn randomization failed")
      end
	
			finish_item(txn);
		end
	endtask
endclass