typedef enum bit {
  READ  = 1,
  WRITE = 0
} axn_type_e;

class axi4_seq_item extends uvm_sequence_item;

  `uvm_object_utils(axi4_seq_item)
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
  rand  bit axn_type; // READ / WRITE
 
 //rand bit [31:0] delay_cycles; // inter-transaction delay
 
 
 	function new(string name = "axi4_seq_item");
		super.new(name);
	endfunction
	

	constraint burst_c1{burst inside{1,2};}
	
	constraint len_c2{len inside {[0:255]}; solve len before data;}
	constraint addr_align_c3{addr % (2 ** size) == 0;}
	constraint data_size{data.size==len+1;}
	constraint strb_size_c {strb.size == len+1;}
	constraint strb_zero_c {foreach(strb[i])
								strb[i] == 128'b1;}
	//constraint data_value{foreach(data[i])
							//data[i]==i+1;}							
		constraint data_value{foreach(data[i])
							data[i]== 'hAA;}							
														
								
								
	//constraint awaddr_align_c3{awaddr % ((2 ** awsize)) == 0;}
	
	function void do_copy(uvm_object rhs);

		axi4_seq_item rhs_;

		if(!$cast(rhs_, rhs))
		`uvm_fatal("COPY", "Cast failed in do_copy")

		super.do_copy(rhs);

		addr         = rhs_.addr;
		id           = rhs_.id;
		len          = rhs_.len;
		size         = rhs_.size;
		burst        = rhs_.burst;
		resp         = rhs_.resp;
	//	qos          = rhs_.qos;
		axn_type     = rhs_.axn_type;
	//	delay_cycles = rhs_.delay_cycles;

		data = new[rhs_.data.size()];
		foreach(data[i])
		data[i] = rhs_.data[i];

		strb = new[rhs_.strb.size()];
		foreach(strb[i])
		strb[i] = rhs_.strb[i];

	endfunction

	
	
	virtual function void do_print(uvm_printer printer);
		printer.print_field("addr",addr,40,UVM_DEC);
		printer.print_field("id",id,8,UVM_DEC);
		printer.print_field("len",len,8,UVM_DEC);
		printer.print_field("size",size,3,UVM_DEC);
		printer.print_field("burst",burst,2,UVM_DEC);
		foreach(data[i]) begin
		printer.print_field($sformatf("data[%0d]",i),data[i],1024,UVM_DEC);
		end
		foreach(strb[i]) begin
		printer.print_field($sformatf("strb[%0d]",i),strb[i],128,UVM_DEC);
		end
		//printer.print_field("last",last,1,UVM_DEC);
	endfunction
	
	function void display();
		this.print(uvm_default_tree_printer);
	endfunction

	function string convert2string();

		return $sformatf(
		"type=%s addr=0x%0h id=%0d len=%0d size=%0d burst=%0d resp=%0d beats=%0d",
		(axn_type == WRITE) ? "WRITE" : "READ",addr,id,len,size,burst,resp,len+1);

	endfunction
endclass