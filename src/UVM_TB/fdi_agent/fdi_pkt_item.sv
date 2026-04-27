class fdi_pkt_item extends uvm_sequence_item;

    `uvm_object_utils(fdi_pkt_item)
    
    rand bit trdy;
    rand bit [2:0] vcn;
    rand bit [3:0] opcode;
    rand bit port_id;
    rand bit [7:0] txn_id;
    rand bit [7:0] burst_len;
    rand bit [1:0] burst_type;
    rand bit [2:0] burst_size;
    rand bit [1:0] resp;
    rand bit [39:0] addr;
    rand bit [7:0] data[]; // byte array payload
    rand bit [127:0] wstrb[]; // write strobes
    rand int backpressure_cycles; // PL trdy deassert duration
    rand bit [5:0] credit_rtn_cnt;
    rand bit [1:0] credit_rtn_vcn;
	rand bit startofpkt;
	rand bit endofpkt;
	
    function new(string name="fdi_pkt_item");
    super.new(name);
    endfunction


	constraint vcn_c1{vcn inside{0,1};}
	constraint opcode_c2{opcode inside{[0:5]};}
	constraint addr_c3{addr%(2**burst_size)==0;}
	constraint b_cycles_c4{backpressure_cycles inside{[5:10]};}



    function string convert2string();

        return $sformatf(
        "\nopcode=%0d vcn=%0d port=%0d txn_id=%0d len=%0d type=%0d size=%0d resp=%0d addr=0x%0h payload=%0d credit_cnt=%0d credit_vcn=%0d bp=%0d\n",
        opcode,vcn,port_id,txn_id,burst_len,burst_type,burst_size,resp,addr,data.size(),credit_rtn_cnt,credit_rtn_vcn,backpressure_cycles
        );

    endfunction

    function void do_copy(uvm_object rhs);

        fdi_pkt_item rhs_;

        if(!$cast(rhs_, rhs))
        `uvm_fatal("COPY", "Cast failed in do_copy")

        super.do_copy(rhs);

        vcn                 = rhs_.vcn;
        opcode              = rhs_.opcode;
        port_id             = rhs_.port_id;
        txn_id              = rhs_.txn_id;
        burst_len           = rhs_.burst_len;
        burst_type          = rhs_.burst_type;
        burst_size          = rhs_.burst_size;
        resp                = rhs_.resp;
        addr                = rhs_.addr;
        backpressure_cycles = rhs_.backpressure_cycles;
        credit_rtn_cnt      = rhs_.credit_rtn_cnt;
        credit_rtn_vcn      = rhs_.credit_rtn_vcn;
		startofpkt			= rhs_.startofpkt;
		endofpkt            = rhs_.endofpkt;
		trdy                = rhs_.trdy;
        data = new[rhs_.data.size()];
        foreach(data[i])
        data[i] = rhs_.data[i];

        wstrb = new[rhs_.wstrb.size()];
        foreach(wstrb[i])
        wstrb[i] = rhs_.wstrb[i];
	endfunction
	
	
		
		virtual function void do_print(uvm_printer printer);
		printer.print_field("VCN",vcn,8,UVM_DEC);
		printer.print_field("opcode",opcode,4,UVM_DEC);
		printer.print_field("port_id",port_id,1,UVM_DEC);
		printer.print_field("txn_id",txn_id,8,UVM_DEC);
		printer.print_field("burst_len",burst_len,8,UVM_DEC);
		printer.print_field("burst_type",burst_type,2,UVM_DEC);
		printer.print_field("burst_size",burst_size,8,UVM_DEC);
		printer.print_field("resp",resp,2,UVM_DEC);
		printer.print_field("addr",addr,40,UVM_DEC);
		foreach(data[i]) begin
		printer.print_field($sformatf("data[%0d]",i),data[i],8,UVM_DEC);
		end
		foreach(wstrb[i]) begin
		printer.print_field($sformatf("wstrb[%0d]",i),wstrb[i],128,UVM_DEC);
		end
		printer.print_field("backpressure_cycle",backpressure_cycles,1,UVM_DEC);
		printer.print_field("credit_rtn_cnt",credit_rtn_cnt,6,UVM_DEC);
		printer.print_field("credit_rtn_vcn",credit_rtn_vcn,2,UVM_DEC);
		endfunction
		
	function void display();
		this.print(uvm_default_tree_printer);
	endfunction

   
endclass