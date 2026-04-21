class axi_xtn extends uvm_sequence_item;

	`uvm_object_utils(axi_xtn);
	typedef enum{read, write}axn_type_e; 

rand bit [39:0] addr;
 rand bit [7:0] id;
 rand bit [7:0] len; // AWLEN/ARLEN
 rand bit [2:0] size; // AWSIZE/ARSIZE
 rand bit [1:0] burst; // AWBURST/ARBURST
 rand bit [1023:0] data[]; // write/read data array
 rand bit [127:0] strb[]; // write strobes per beat
 rand bit [1:0] resp; // expected/actual BRESP/RRESP
 //rand bit [3:0] qos; // AWQOS/ARQOS
 rand axn_type_e axn_type; // READ / WRITE
 
 //rand bit [31:0] delay_cycles; // inter-transaction delay
 
 
 	function new(string name="axi_xtn");
		super.new(name);
	endfunction
	

	constraint burst_c1{burst inside{1,2};}
	constraint len_c2{len inside {[0:255]};}
	constraint addr_align_c3{addr % (2 ** size) == 0;}
	//constraint awaddr_align_c3{awaddr % ((2 ** awsize)) == 0;}
	

	
	
	virtual function void do_print(uvm_printer printer);
		printer.print_field("addr",addr,40,UVM_HEX);
		printer.print_field("id",id,8,UVM_HEX);
		printer.print_field("len",len,8,UVM_HEX);
		printer.print_field("size",size,3,UVM_HEX);
		printer.print_field("burst",burst,2,UVM_HEX);
		foreach(data[i]) begin
		printer.print_field($sformatf("data[%0d]",i),data[i],1024,UVM_HEX);
		end
		foreach(strb[i]) begin
		printer.print_field($sformatf("strb[%0d]",i),strb[i],128,UVM_HEX);
		end
		//printer.print_field("last",last,1,UVM_HEX);

		
	endfunction
	
	function void display();
		this.print(uvm_default_tree_printer);
	endfunction





endclass