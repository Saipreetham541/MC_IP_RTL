class fdi_back_pressure_seqs extends sub_sequence;
	`uvm_object_utils(fdi_back_pressure_seqs)

	fdi_xtn fditxn;

	function new(string name="fdi_back_pressure_seqs");
		super.new(name);
	endfunction	
	
	task body();
		repeat(5)
			begin
			
				repeat(10) begin
					fditxn = fdi_xtn::type_id::create("fditxn");
					start_item(fditxn);
					assert(fditxn.randomize() with {trdy == 1; 
													startofpkt == 1;
													endofpkt   == 1;
													});
					finish_item(fditxn);
				end

		
				fditxn = fdi_xtn::type_id::create("fditxn");
				start_item(fditxn);
				assert(fditxn.randomize() with {trdy == 0;
												backpressure_cycles inside {[10:50]};
												});
				finish_item(fditxn);
				
			end

		endtask
endclass