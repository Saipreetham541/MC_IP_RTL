class mgr_axi_req_ready_seq extends uvm_sequence #(axi4_seq_item);
    `uvm_object_utils(mgr_axi_req_ready_seq)

    axi4_seq_item txn;
	
    function new(string name="mgr_axi_req_ready_seq");
        super.new(name);
    endfunction
    
    task body();
        begin
            txn = axi4_seq_item::type_id::create("txn");
            start_item(txn);
            if(!txn.randomize() with {
                                        len==0;
										data.size() == len+1;
										strb.size() == len+1;  
                                        addr == 0;           
                                        id == 0;
										foreach(strb[i]) {
											strb[i] == 128'b0;
											}
							
										foreach (data[i]) {
											data[i][1023 : 0] == '0;
										}
										})begin
										`uvm_fatal("RAND_FAIL", "FDI txn randomization failed")
                                        end
                        
            finish_item(txn);
        end
    endtask
endclass
