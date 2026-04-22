class fdi_back_pressure_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_back_pressure_seqs)

	fdi_pkt_item fditxn;

	function new(string name="fdi_back_pressure_seqs");
		super.new(name);
	endfunction	
	
	task body();
		repeat(5)
			begin
			
				repeat(10) begin
					fditxn = fdi_pkt_item::type_id::create("fditxn");
					start_item(fditxn);
					assert(fditxn.randomize() with {trdy == 1; 
													startofpkt == 1;
													endofpkt   == 1;
													});
					finish_item(fditxn);
				end

		
				fditxn = fdi_pkt_item::type_id::create("fditxn");
				start_item(fditxn);
				assert(fditxn.randomize() with {trdy == 0;
												backpressure_cycles inside {[10:50]};
												});
				finish_item(fditxn);
				
			end

		endtask
endclass