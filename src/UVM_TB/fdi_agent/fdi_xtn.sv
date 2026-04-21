class fdi_xtn extends uvm_sequence_item;

`uvm_object_utils(fdi_xtn)


rand bit trdy
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
 
function new(string name="fdi_xtn");
super.new(name);
endfunction



endclass