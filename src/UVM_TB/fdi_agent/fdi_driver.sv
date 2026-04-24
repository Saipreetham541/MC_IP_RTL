//fdi_driver

 class fdi_driver extends uvm_driver#(fdi_pkt_item);
`uvm_component_utils(fdi_driver)

virtual fdi_interface.FDI_DRV_MP vif;
virtual reset_interface rst_intf;
fdi_pkt_item txn;
fdi_credit_manager credit_mgr;

fdi_agt_config fdi_cfg;
function new(string name="fdi_driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
if(!uvm_config_db#(fdi_agt_config)::get(this,"","fdi_agt_config",fdi_cfg))
`uvm_fatal("FATAL","FROM FDI_DRIVER CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")

if(!uvm_config_db#(fdi_credit_manager) :: get(this, "", "fdi_credit_manager",credit_mgr))
`uvm_fatal("fdi_driver", "credit get is failed")

txn=fdi_pkt_item :: type_id :: create("txn");

endfunction

function void connect_phase(uvm_phase phase);
vif= fdi_cfg.fdi_intf;
endfunction


task run_phase(uvm_phase phase);
$display("waiting for reset");
while(!(vif.global_reset && vif.fdi_rst_n))
	@(vif.fdi_drv_cb);
forever begin


	vif.fdi_drv_cb.fdi_pl_inband_pres<=1;
	
	if(vif.fdi_drv_cb.fdi_lp_state_req==3'b010) begin
	@(vif.fdi_drv_cb);
	vif.fdi_drv_cb.fdi_pl_state_sts<=3'b010;
	end
	else
	vif.fdi_drv_cb.fdi_pl_state_sts<=3'b000;
	
$display("driver");
  

    seq_item_port.get_next_item(txn);
	$display("driver1");
	txn.print();
	//apply_backpressure(txn.backpressure_cycles);
		if(txn.opcode == 4'h4) begin
			drive_packet(txn);
		end
	    else if (txn.opcode == 4'h0 || txn.opcode == 4'h1 || txn.opcode == 4'h1 || txn.opcode == 4'h1)
		begin
			while(!credit_mgr.has_credit(txn.vcn))
				@(vif.fdi_drv_cb);
				drive_packet(txn);
		end
		
	
	
	$display("outside while");
	credit_mgr.consume_credit(txn.vcn);
	$display("after consumecredit");
    seq_item_port.item_done();

  end

endtask



// OPCODE DECODING

task drive_packet(fdi_pkt_item txn);

  case(txn.opcode)
    4'h0: drive_write_req(txn);
    4'h1: drive_read_req(txn);
    4'h2: drive_write_resp(txn);
    4'h3: drive_read_resp(txn);
    4'h4: drive_credit_return(txn);
  endcase

endtask


// HEADER FORMATION


function bit [2047:0] build_header(fdi_pkt_item txn);

  bit [2047:0] flit;

  flit = '0;

  flit[5:3]    =txn.vcn;
  flit[11:8]    =txn.opcode;
  flit[12]      =txn.port_id;
  flit[20:13]   =txn.txn_id;
  flit[28:21]  =txn.burst_len;
  flit[30:29]  =txn.burst_type;
  flit[33:31]  =txn.burst_size;
  flit[84:45]  =txn.addr;

  return flit;

endfunction


// SENDING FLIT

task send_flit(bit [2047:0] flit,bit sop,bit eop);

  @(vif.fdi_drv_cb);
$display("start of send flit");
  vif.fdi_drv_cb.fdi_pl_data<=flit;
  vif.fdi_drv_cb.fdi_pl_valid<=1;
  vif.fdi_drv_cb.fdi_pl_irdy<=1;
  vif.fdi_drv_cb.fdi_pl_startofpkt<=sop;
  vif.fdi_drv_cb.fdi_pl_endofpkt<=eop;
	vif.fdi_drv_cb.fdi_pl_trdy<=1;
$display("after flit");
  while(!vif.fdi_drv_cb.fdi_lp_trdy)
  @(vif.fdi_drv_cb);
  $display("before making valid 0");
             //@(vif.fdi_drv_cb);
  vif.fdi_drv_cb.fdi_pl_valid<=0;
//txn.display();
endtask


// WRITE REQUEST

task drive_write_req(fdi_pkt_item txn);

  bit [2047:0] header_flit;

  int idx;
  int wstrb_present=0;

  header_flit=build_header(txn);
	idx=0;
  

foreach(txn.wstrb[i]) begin
  if(txn.wstrb[i] != '1) begin
    wstrb_present = 1;
  end
end

  if(wstrb_present==1)
    header_flit[255:128]=txn.wstrb[0];
  else 
	header_flit[255:128]='0;

  for(int i=0;i<216;i++) begin

    if(idx < txn.data.size())
      header_flit[(256+i*8)+:8]=txn.data[idx++];
    else
      header_flit[(256+i*8)+:8]=0;

  end
  header_flit[2047:1984]=64'h0;                                    
  send_flit(header_flit,1,(idx >= txn.data.size()));
 // send_remaining_payload(txn, idx);

endtask


// READ REQUEST

task drive_read_req(fdi_pkt_item txn);

  bit [2047:0] header_flit;

  header_flit = build_header(txn);
  header_flit[2047:1984]=64'h0;
  send_flit(header_flit,1,1);

endtask


// WRITE RESPONSE 

task drive_write_resp(fdi_pkt_item txn);

  bit [2047:0] header_flit;

  header_flit=build_header(txn);

  header_flit[31:30]=txn.resp;

  header_flit[2047:1984]=64'h0;

  send_flit(header_flit,1,1);

endtask

// READ RESPONSE 

task drive_read_resp(fdi_pkt_item txn);

  bit [2047:0] header_flit;

  int idx;

  header_flit = build_header(txn);

  idx = 0;

  for(int i=0;i<216;i++) begin

    if(idx < txn.data.size())
      header_flit[(256+i*8)+:8] = txn.data[i];
    else
      header_flit[(256+i*8)+:8] = 0;
	idx++;
  end

  header_flit[2047:1984] = 64'h0;

  send_flit(header_flit,1,(idx >= txn.data.size()));


endtask

//CREDIT RETURN

task drive_credit_return(fdi_pkt_item txn);

  bit [2047:0] header_flit;
$display("entering drive_credit_return");
  header_flit = '0;
header_flit[11:8] = txn.opcode;
$display("opcode =%0b", header_flit[11:8]);
  header_flit[43:38] = txn.credit_rtn_cnt;
  $display("credit_rtn_cnt=%0b",header_flit[43:38]);
  header_flit[37:36] = txn.credit_rtn_vcn;
$display("credit_rtn_vcn=%0b",header_flit[37:36]);
  header_flit[2047:1984]=64'h0;
  send_flit(header_flit,1,1);

endtask


task apply_backpressure(int cycles);

  vif.fdi_drv_cb.fdi_pl_trdy<=0;

  repeat(cycles)
    @(vif.fdi_drv_cb);

  vif.fdi_drv_cb.fdi_pl_trdy<=1;

endtask

endclass


