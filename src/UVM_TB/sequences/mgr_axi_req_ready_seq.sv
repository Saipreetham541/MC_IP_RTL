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
            assert(txn.randomize() with {

                
                                        
                        id inside{[51:100]};
                        })
			else begin
                `uvm_fatal("SEQ", "Randomization failed for random_mngr_axi_seq")
            end
            finish_item(txn);
        end
    endtask
endclass
