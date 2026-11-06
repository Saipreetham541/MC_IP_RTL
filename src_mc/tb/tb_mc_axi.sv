`timescale 1ns/1ps
// Valid-input profile: protocol/address validation is an upstream requirement.
// Exercise conversion, ordering, stalls and reset with supported legal traffic.
module tb_mc_axi;
  logic aclk=0, aresetn=0, dfi_clk=0, ctl_reset_n=0;
  logic [7:0] s_axi_awid;
  logic [39:0] s_axi_awaddr;
  logic [7:0] s_axi_awlen;
  logic [2:0] s_axi_awsize;
  logic [1:0] s_axi_awburst;
  logic  s_axi_awlock;
  logic [3:0] s_axi_awqos;
  logic [3:0] s_axi_awcache;
  logic [2:0] s_axi_awprot;
  logic  s_axi_awvalid;
  logic  s_axi_awready;
  logic [255:0] s_axi_wdata;
  logic [31:0] s_axi_wstrb;
  logic  s_axi_wlast;
  logic  s_axi_wvalid;
  logic  s_axi_wready;
  logic [7:0] s_axi_bid;
  logic [1:0] s_axi_bresp;
  logic  s_axi_bvalid;
  logic  s_axi_bready;
  logic [7:0] s_axi_arid;
  logic [39:0] s_axi_araddr;
  logic [7:0] s_axi_arlen;
  logic [2:0] s_axi_arsize;
  logic [1:0] s_axi_arburst;
  logic  s_axi_arlock;
  logic [3:0] s_axi_arqos;
  logic [3:0] s_axi_arcache;
  logic [2:0] s_axi_arprot;
  logic  s_axi_arvalid;
  logic  s_axi_arready;
  logic [7:0] s_axi_rid;
  logic [255:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic  s_axi_rlast;
  logic  s_axi_rvalid;
  logic  s_axi_rready;
  logic [15:0] dfi_row_val;
  logic [15:0][21:0] dfi_row;
  logic [15:0] dfi_col_val;
  logic [15:0][11:0] dfi_col;
  logic [15:0][63:0] dfi_wrdata;
  logic [15:0][7:0] dfi_wrdata_mask;
  logic [15:0][1:0] dfi_wrdata_en;
  logic [15:0][1:0] dfi_rddata_en;
  logic [15:0][63:0] dfi_rddata;
  logic [15:0][1:0] dfi_rddata_valid;
  logic [31:0] err_cmdq_overflow;
  logic [31:0] err_wdb_overflow;
  logic [31:0] err_ref_deadline_miss;
  mc16x2 dut (.*);
  // The updated top inserts u_axi_sub ahead of the five CDC FIFOs.
  // Check all forwarded fields and reverse-direction READY/response signals.
  always @(posedge aclk) begin : check_subordinate_path
    if (aresetn) begin
      if ({s_axi_awid, s_axi_awaddr, s_axi_awlen, s_axi_awsize, s_axi_awburst, s_axi_awlock, s_axi_awqos, s_axi_awcache, s_axi_awprot, s_axi_awvalid, s_axi_awready} !==
          {dut.sub_awid, dut.sub_awaddr, dut.sub_awlen, dut.sub_awsize, dut.sub_awburst, dut.sub_awlock, dut.sub_awqos, dut.sub_awcache, dut.sub_awprot, dut.sub_awvalid, dut.sub_awready})
        $fatal(1, "AXI AW fields changed across u_axi_sub");
      if ({s_axi_wdata, s_axi_wstrb, s_axi_wlast, s_axi_wvalid, s_axi_wready} !==
          {dut.sub_wdata, dut.sub_wstrb, dut.sub_wlast, dut.sub_wvalid, dut.sub_wready})
        $fatal(1, "AXI W fields changed across u_axi_sub");
      if ({s_axi_bid, s_axi_bresp, s_axi_bvalid, s_axi_bready} !==
          {dut.sub_bid, dut.sub_bresp, dut.sub_bvalid, dut.sub_bready})
        $fatal(1, "AXI B fields changed across u_axi_sub");
      if ({s_axi_arid, s_axi_araddr, s_axi_arlen, s_axi_arsize, s_axi_arburst, s_axi_arlock, s_axi_arqos, s_axi_arcache, s_axi_arprot, s_axi_arvalid, s_axi_arready} !==
          {dut.sub_arid, dut.sub_araddr, dut.sub_arlen, dut.sub_arsize, dut.sub_arburst, dut.sub_arlock, dut.sub_arqos, dut.sub_arcache, dut.sub_arprot, dut.sub_arvalid, dut.sub_arready})
        $fatal(1, "AXI AR fields changed across u_axi_sub");
      if ({s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast, s_axi_rvalid, s_axi_rready} !==
          {dut.sub_rid, dut.sub_rdata, dut.sub_rresp, dut.sub_rlast, dut.sub_rvalid, dut.sub_rready})
        $fatal(1, "AXI R fields changed across u_axi_sub");
    end
  end

  // The former field-decoder module has been folded into the CDC/backend.
  // Check the CDC's public decoded fields whenever an address is consumed.
  always @(posedge dfi_clk) begin : check_cdc_address_fields
    if (ctl_reset_n) begin
      // These attributes stay constant throughout this test. Check that the
      // updated subordinate and FIFO packing preserve their nonzero values.
      if (dut.m_awvalid && dut.m_awready &&
          {dut.m_awqos, dut.m_awcache, dut.m_awprot} !== {4'hA, 4'h6, 3'h5})
        $fatal(1, "Write attributes changed across subordinate/CDC");
      if (dut.m_arvalid && dut.m_arready &&
          {dut.m_arqos, dut.m_arcache, dut.m_arprot} !== {4'h5, 4'h9, 3'h3})
        $fatal(1, "Read attributes changed across subordinate/CDC");
      if (dut.m_awvalid && dut.m_awready &&
          {dut.u_axi_cdc.m_aw_ch_sel, dut.u_axi_cdc.m_aw_pc_sel,
           dut.u_axi_cdc.m_aw_row_addr, dut.u_axi_cdc.m_aw_bank_group,
           dut.u_axi_cdc.m_aw_bank_addr, dut.u_axi_cdc.m_aw_col_addr} !==
          {dut.m_awaddr[29:26], dut.m_awaddr[25], dut.m_awaddr[24:11],
           dut.m_awaddr[10:9], dut.m_awaddr[8:7], dut.m_awaddr[6:2]})
        $fatal(1, "CDC write address field decode mismatch");
      if (dut.m_arvalid && dut.m_arready &&
          {dut.u_axi_cdc.m_ar_ch_sel, dut.u_axi_cdc.m_ar_pc_sel,
           dut.u_axi_cdc.m_ar_row_addr, dut.u_axi_cdc.m_ar_bank_group,
           dut.u_axi_cdc.m_ar_bank_addr, dut.u_axi_cdc.m_ar_col_addr} !==
          {dut.m_araddr[29:26], dut.m_araddr[25], dut.m_araddr[24:11],
           dut.m_araddr[10:9], dut.m_araddr[8:7], dut.m_araddr[6:2]})
        $fatal(1, "CDC read address field decode mismatch");
    end
  end

  always #1.7 aclk = ~aclk;
  always #0.5 dfi_clk = ~dfi_clk;

  // Independent physical memory and byte-addressed AXI reference memory.
  logic [31:0] memory [longint unsigned];
  byte unsigned reference_bytes [longint unsigned];
  logic [13:0] rows [32][16];
  logic [15:0] bank_open [32];
  logic [31:0] pending_data [32];
  int delay_left [32];
  int writes_seen [32], reads_seen [32];
  int seed=1, checks=0, model_writes=0;
  int backend_b_stalls=0, backend_r_stalls=0;
  logic b_stalled, r_stalled, mb_stalled, mr_stalled;
  logic [9:0] held_b, held_mb;
  logic [266:0] held_r, held_mr;

  // Consume public registered command/data pins on the opposite clock edge.
  // Reconstruct word addresses independently of the dispatcher's decoder.
  always @(negedge dfi_clk) begin
    if (!ctl_reset_n) begin
      dfi_rddata='0; dfi_rddata_valid='0;
      for(int p=0;p<32;p++) begin
        bank_open[p]='0; delay_left[p]=0;
      end
    end else begin
      dfi_rddata_valid='0;
      if ((|err_cmdq_overflow) || (|err_wdb_overflow) || (|err_ref_deadline_miss))
        $fatal(1,"Unexpected core error");
      for(int p=0;p<32;p++) begin
        if(delay_left[p]>0) begin
          delay_left[p]--;
          if(delay_left[p]==0) begin
            dfi_rddata[p/2][(p%2)*32 +:32]=pending_data[p];
            dfi_rddata_valid[p/2][p%2]=1;
          end
        end
      end
      for(int ch=0;ch<16;ch++) begin
        int p,b;
        longint unsigned key;
        if(dfi_row_val[ch]) begin
          p=2*ch+int'(dfi_row[ch][21]);
          b=int'(dfi_row[ch][17:14]);
          case(dfi_row[ch][20:18])
            3'b001: begin rows[p][b]=dfi_row[ch][13:0]; bank_open[p][b]=1; end
            3'b010: bank_open[p][b]=0;
            3'b100: bank_open[p]='0;
            default: $fatal(1,"Unexpected row command");
          endcase
        end
        if(dfi_col_val[ch]) begin
          p=2*ch+int'(dfi_col[ch][11]); b=int'(dfi_col[ch][8:5]);
          if(!bank_open[p][b]) $fatal(1,"Column command to closed bank");
          key=(64'(p)<<23) | (64'(rows[p][b])<<9) |
              (64'(b)<<5) | 64'(dfi_col[ch][4:0]);
          if(memory.exists(key)==0) memory[key]='0;
          case(dfi_col[ch][10:9])
            2'b10: begin
              if(dfi_wrdata_en[ch] != (2'b01 << (p%2))) $fatal(1,"Wrong write lane");
              for(int n=0;n<4;n++)
                if(!dfi_wrdata_mask[ch][(p%2)*4+n])
                  memory[key][n*8+:8]=dfi_wrdata[ch][(p%2)*32+n*8+:8];
              writes_seen[p]++; model_writes++;
            end
            2'b01: begin
              if(dfi_rddata_en[ch] != (2'b01 << (p%2))) $fatal(1,"Wrong read lane");
              if(delay_left[p]!=0) $fatal(1,"Unexpected overlapping return");
              pending_data[p]=memory[key];
              delay_left[p]=4+((reads_seen[p]+seed)%7); reads_seen[p]++;
            end
            default: $fatal(1,"Unexpected column command");
          endcase
        end
      end
    end
  end

  // Check stable response payloads at both sides of the CDC FIFOs.
  always @(posedge aclk) begin
    if(!aresetn) begin b_stalled=0; r_stalled=0; end
    else begin
      if(b_stalled && (!s_axi_bvalid || held_b!={s_axi_bid,s_axi_bresp})) $fatal(1,"Unstable B");
      if(r_stalled && (!s_axi_rvalid || held_r!={s_axi_rid,s_axi_rdata,s_axi_rresp,s_axi_rlast})) $fatal(1,"Unstable R");
      b_stalled=s_axi_bvalid&&!s_axi_bready; held_b={s_axi_bid,s_axi_bresp};
      r_stalled=s_axi_rvalid&&!s_axi_rready; held_r={s_axi_rid,s_axi_rdata,s_axi_rresp,s_axi_rlast};
    end
  end
  always @(posedge dfi_clk) begin
    if(!ctl_reset_n) begin mb_stalled=0; mr_stalled=0; end
    else begin
      if(mb_stalled && (!dut.m_bvalid || held_mb!={dut.m_bid,dut.m_bresp})) $fatal(1,"Unstable backend B");
      if(mr_stalled && (!dut.m_rvalid || held_mr!={dut.m_rid,dut.m_rdata,dut.m_rresp,dut.m_rlast})) $fatal(1,"Unstable backend R");
      if(dut.m_bvalid&&!dut.m_bready) backend_b_stalls++;
      if(dut.m_rvalid&&!dut.m_rready) backend_r_stalls++;
      mb_stalled=dut.m_bvalid&&!dut.m_bready; held_mb={dut.m_bid,dut.m_bresp};
      mr_stalled=dut.m_rvalid&&!dut.m_rready; held_mr={dut.m_rid,dut.m_rdata,dut.m_rresp,dut.m_rlast};
    end
  end

  function automatic logic [39:0] beat_address(input logic [39:0] base,
      input int beat, len, size, burst);
    longint unsigned span, raw_addr;
    span=(64'(len)+64'd1)<<size;
    raw_addr=64'(base)+(64'(beat)<<size);
    if(burst==0) return base;
    if(burst==2) return 40'((64'(base)/span)*span + raw_addr%span);
    return 40'(raw_addr);
  endfunction
  function automatic logic [255:0] payload(input int tag, beat);
    logic [255:0] result;
    for(int n=0;n<32;n++) result[n*8+:8]=8'(tag*17+beat*37+n*11+seed);
    return result;
  endfunction

  task automatic send_aw(input logic [7:0] id, input logic [39:0] address,
      input int len=0,size=5,burst=1,wait_cycles=0,input bit locked=0);
    repeat(wait_cycles) @(negedge aclk);
    @(negedge aclk);
    s_axi_awid=id; s_axi_awaddr=address; s_axi_awlen=8'(len);
    s_axi_awsize=3'(size); s_axi_awburst=2'(burst); s_axi_awlock=locked;
    s_axi_awvalid=1;
    do @(posedge aclk); while(!s_axi_awready);
    @(negedge aclk); s_axi_awvalid=0;
  endtask

  task automatic send_w(input logic [39:0] address,input int len=0,size=5,burst=1,
      tag=1,mask_mode=0,wait_cycles=0,input bit update_reference=1,bad_last=0,
      input int inter_beat_gap=0);
    logic [39:0] a;
    logic [255:0] data_word;
    logic [31:0] strobes;
    int lane, byte_count;
    repeat(wait_cycles) @(negedge aclk);
    for(int beat=0;beat<=len;beat++) begin
      a=beat_address(address,beat,len,size,burst);
      data_word=payload(tag,beat); lane=int'(a[4:0]); byte_count=1<<size;
      strobes='0;
      for(int n=0;n<32;n++)
        if(n>=lane && n<lane+byte_count)
          strobes[n]=(mask_mode==0 || (mask_mode==1 && ((n+beat)%3)!=0));
      @(negedge aclk);
      s_axi_wvalid=1; s_axi_wdata=data_word; s_axi_wstrb=strobes;
      s_axi_wlast=(beat==len)^bad_last;
      do @(posedge aclk); while(!s_axi_wready);
      if(update_reference)
        for(int n=0;n<32;n++) if(strobes[n])
          reference_bytes[(64'(a)&~64'd31)+64'(n)]=data_word[n*8+:8];
      @(negedge aclk); s_axi_wvalid=0;
      repeat(inter_beat_gap) @(negedge aclk);
    end
  endtask

  task automatic receive_b(input logic [7:0] id,input logic [1:0] response=0,
      input int stall_cycles=0);
    s_axi_bready=0;
    repeat(stall_cycles) @(negedge aclk);
    @(negedge aclk); s_axi_bready=1;
    do @(posedge aclk); while(!s_axi_bvalid);
    if(s_axi_bid!==id || s_axi_bresp!==response)
      $fatal(1,"B id=%h/%h resp=%h/%h",s_axi_bid,id,s_axi_bresp,response);
    checks++;
    @(negedge aclk); s_axi_bready=0;
  endtask

  task automatic write_tx(input logic [7:0] id,input logic [39:0] address,
      input int len=0,size=5,burst=1,mask_mode=0,aw_delay=0,w_delay=0,
      input logic [1:0] response=0,input bit locked=0,bad_last=0);
    fork
      send_aw(id,address,len,size,burst,aw_delay,locked);
      send_w(address,len,size,burst,int'(id),mask_mode,w_delay,response==0,bad_last);
    join
    receive_b(id,response,12);
  endtask

  task automatic read_tx(input logic [7:0] id,input logic [39:0] address,
      input int len=0,size=5,burst=1,input logic [1:0] response=0,
      input bit locked=0,input int initial_stall=0);
    logic [39:0] a;
    logic [255:0] expected;
    longint unsigned key;
    int lane;
    @(negedge aclk);
    s_axi_arid=id; s_axi_araddr=address; s_axi_arlen=8'(len);
    s_axi_arsize=3'(size); s_axi_arburst=2'(burst); s_axi_arlock=locked;
    s_axi_arvalid=1; s_axi_rready=0;
    do @(posedge aclk); while(!s_axi_arready);
    @(negedge aclk); s_axi_arvalid=0;
    repeat(initial_stall) @(negedge aclk);
    for(int beat=0;beat<=len;beat++) begin
      repeat((beat+seed)%6) @(negedge aclk);
      @(negedge aclk); s_axi_rready=1;
      do @(posedge aclk); while(!s_axi_rvalid);
      expected='0; a=beat_address(address,beat,len,size,burst); lane=int'(a[4:0]);
      if(response==0)
        for(int n=0;n<32;n++) if(n>=lane && n<lane+(1<<size)) begin
          key=(64'(a)&~64'd31)+64'(n);
          expected[n*8+:8]=(reference_bytes.exists(key)!=0) ? reference_bytes[key] : 8'b0;
        end
      if(s_axi_rid!==id || s_axi_rresp!==response || s_axi_rlast!==(beat==len) || s_axi_rdata!==expected)
        $fatal(1,"R id=%h/%h beat=%0d resp=%h/%h last=%b data=%h expected=%h",s_axi_rid,id,beat,s_axi_rresp,response,s_axi_rlast,s_axi_rdata,expected);
      checks++;
      @(negedge aclk); s_axi_rready=0;
    end
  endtask

  initial begin
    if(!$value$plusargs("seed=%d",seed)) seed=1;
    s_axi_awvalid=0; s_axi_wvalid=0; s_axi_arvalid=0;
    s_axi_bready=0; s_axi_rready=0;
    s_axi_awid=0; s_axi_awaddr=0; s_axi_awlen=0; s_axi_awsize=0; s_axi_awburst=0;
    s_axi_awlock=0; s_axi_awqos=4'hA; s_axi_awcache=4'h6; s_axi_awprot=3'h5;
    s_axi_wdata=0; s_axi_wstrb=0; s_axi_wlast=0;
    s_axi_arid=0; s_axi_araddr=0; s_axi_arlen=0; s_axi_arsize=0; s_axi_arburst=0;
    s_axi_arlock=0; s_axi_arqos=4'h5; s_axi_arcache=4'h9; s_axi_arprot=3'h3;
    dfi_rddata='0; dfi_rddata_valid='0;
    for(int p=0;p<32;p++) begin writes_seen[p]=0; reads_seen[p]=0; end
    repeat(8) @(negedge aclk);
    ctl_reset_n=1;
    @(negedge aclk); aresetn=1;

    $display("TEST full-width data, all 32 PCs, AW/W skew, partial and zero strobes");
    for(int p=0;p<32;p++) begin
      logic [39:0] a;
      a=(40'(p)<<25) | 40'h1E0;
      write_tx(8'(p),a,1,5,1,0,p%3,(p+1)%3);
      read_tx(8'(p),a,1);
      write_tx(8'(p),a,1,5,1,1);
      read_tx(8'(p),a,1);
      write_tx(8'(p),a,1,5,1,2);
      read_tx(8'(p),a,1);
    end
    $display("TEST early-B regression: next AW queued before prior WLAST");
    fork
      begin send_aw(8'hA1,40'h1000,1); send_aw(8'hB2,40'h1100); end
      begin
        // First burst beat, then deliberately delay the final beat.
        @(negedge aclk); s_axi_wdata=payload(161,0); s_axi_wstrb='1;
        s_axi_wlast=0; s_axi_wvalid=1;
        do @(posedge aclk); while(!s_axi_wready);
        for(int n=0;n<32;n++) reference_bytes[64'h1000+64'(n)]=s_axi_wdata[n*8+:8];
        @(negedge aclk); s_axi_wvalid=0;
        repeat(100) begin @(negedge aclk); if(s_axi_bvalid) $fatal(1,"B before WLAST"); end
        @(negedge aclk); s_axi_wdata=payload(161,1); s_axi_wlast=1; s_axi_wvalid=1;
        do @(posedge aclk); while(!s_axi_wready);
        for(int n=0;n<32;n++) reference_bytes[64'h1020+64'(n)]=s_axi_wdata[n*8+:8];
        @(negedge aclk); s_axi_wvalid=0;
        send_w(40'h1100,0,5,1,178);
      end
      begin receive_b(8'hA1); receive_b(8'hB2); end
    join
    read_tx(8'hA1,40'h1000,1); read_tx(8'hB2,40'h1100);

    $display("TEST all narrow sizes/lanes, FIXED, WRAP, row and bank transitions");
    for(int size=0;size<=5;size++)
      for(int lane=0;lane<32;lane+=(1<<size)) begin
        write_tx(8'h44,40'h2000+40'(lane),0,size);
        read_tx(8'h44,40'h2000+40'(lane),0,size);
      end
    write_tx(8'h55,40'h3000,3,5,0); read_tx(8'h55,40'h3000,3,5,0);
    write_tx(8'h66,40'h31E0,3,5,2); read_tx(8'h66,40'h31E0,3,5,2);
    write_tx(8'h77,40'h37E0,3); read_tx(8'h77,40'h37E0,3);
    write_tx(8'h78,40'h3F00,7); read_tx(8'h78,40'h3F00,7);
    write_tx(8'h79,40'h1FFFFE0); read_tx(8'h79,40'h1FFFFE0);
    write_tx(8'h79,40'h2000000); read_tx(8'h79,40'h2000000);
    write_tx(8'h7A,40'h3FFFFE0); read_tx(8'h7A,40'h3FFFFE0);
    write_tx(8'h7A,40'h4000000); read_tx(8'h7A,40'h4000000);
    write_tx(8'h7B,40'h3FFFFFE0); read_tx(8'h7B,40'h3FFFFFE0);

    $display("TEST 256-beat narrow bursts and full R CDC FIFO backpressure");
    write_tx(8'h80,40'h5000,255,0);
    read_tx(8'h80,40'h5000,255,0,1,0,0,1000);

    $display("TEST full B CDC FIFO, queued IDs, W FIFO pressure");
    fork
      begin for(int n=0;n<12;n++) send_aw(8'(160+n),40'h6000+40'(n*32)); end
      begin for(int n=0;n<12;n++) send_w(40'h6000+40'(n*32),0,5,1,160+n); end
      begin
        wait(dut.m_bvalid && !dut.m_bready);
        repeat(25) @(negedge aclk);
        for(int n=0;n<12;n++) receive_b(8'(160+n));
      end
    join
    read_tx(8'hAA,40'h6000,11);

    $display("TEST repeated outstanding IDs and dependent writes");
    fork
      begin send_aw(8'hAC,40'h7000); send_aw(8'hAC,40'h7000); end
      begin send_w(40'h7000,0,5,1,17); send_w(40'h7000,0,5,1,29); end
      begin receive_b(8'hAC); receive_b(8'hAC); end
    join
    read_tx(8'hAC,40'h7000);
    // Queue same-ID reads to different PCs before consuming either response.
    for(int n=0;n<2;n++) begin
      @(negedge aclk); s_axi_arvalid=1; s_axi_arid=8'hAD;
      s_axi_araddr=n==0 ? 40'h3E0001E0 : 40'h1E0;
      s_axi_arlen=0; s_axi_arsize=5; s_axi_arburst=1; s_axi_arlock=0;
      do @(posedge aclk); while(!s_axi_arready);
      @(negedge aclk); s_axi_arvalid=0;
    end
    for(int n=0;n<2;n++) begin
      logic [255:0] expected;
      longint unsigned base;
      base=n==0 ? 64'h3E0001E0 : 64'h1E0;
      for(int b=0;b<32;b++) expected[b*8+:8]=reference_bytes[base+64'(b)];
      @(negedge aclk); s_axi_rready=1;
      do @(posedge aclk); while(!s_axi_rvalid);
      if(s_axi_rid!=8'hAD || s_axi_rresp!=0 || !s_axi_rlast || s_axi_rdata!==expected)
        $fatal(1,"Same-ID cross-PC ordering failed");
      checks++;
      @(negedge aclk); s_axi_rready=0;
    end
    write_tx(8'hAE,40'hA000,15,5,0); read_tx(8'hAE,40'hA000,15,5,0);
    write_tx(8'hAF,40'hB0E0,7,5,2); read_tx(8'hAF,40'hB0E0,7,5,2);
    write_tx(8'hB0,40'h10000,255,4); read_tx(8'hB0,40'h10000,255,4);

    write_tx(8'h98,40'h8000); read_tx(8'h98,40'h8000);
    $display("TEST command/write-buffer backpressure");
    fork
      begin
        int before_writes;
        before_writes=model_writes;
        force dut.cmdq_full = 32'hFFFFFFFF;
        repeat(60) @(negedge aclk);
        if(model_writes!=before_writes || s_axi_bvalid) $fatal(1,"Issued into full CMDQ");
        release dut.cmdq_full;
      end
      write_tx(8'h99,40'h9000);
    join
    read_tx(8'h99,40'h9000);
    fork
      begin
        int before_writes;
        before_writes=model_writes;
        force dut.wdb_full = 32'hFFFFFFFF;
        repeat(60) @(negedge aclk);
        if(model_writes!=before_writes || s_axi_bvalid) $fatal(1,"Issued into full WDB");
        release dut.wdb_full;
      end
      write_tx(8'h9A,40'h9020);
    join
    read_tx(8'h9A,40'h9020);

    $display("TEST coordinated reset during outstanding PHY read");
    @(negedge aclk); s_axi_arid=8'h9D; s_axi_araddr=40'h8000;
    s_axi_arlen=0; s_axi_arsize=5; s_axi_arburst=1; s_axi_arlock=0; s_axi_arvalid=1;
    do @(posedge aclk); while(!s_axi_arready);
    @(negedge aclk); s_axi_arvalid=0;
    wait(|dfi_rddata_en);
    @(negedge dfi_clk); aresetn=0; ctl_reset_n=0;
    repeat(8) @(negedge dfi_clk);
    ctl_reset_n=1;
    @(negedge aclk); aresetn=1;
    repeat(8) @(negedge aclk);
    if(s_axi_bvalid || s_axi_rvalid) $fatal(1,"Stale response after reset");
    // The PHY model flushes pending returns during the coordinated reset;
    // memory contents remain intact.
    read_tx(8'h9E,40'h8000);

    for(int p=0;p<32;p++)
      if(writes_seen[p]==0 || reads_seen[p]==0) $fatal(1,"Missing PC coverage");
    if(backend_b_stalls==0 || backend_r_stalls==0) $fatal(1,"Missing full response-FIFO coverage");
    $display("PASS AXI seed=%0d checks=%0d: 32 PCs, bursts, masks, IDs and CDC stalls",seed,checks);
    $finish;
  end
  initial begin #500000; $fatal(1,"AXI watchdog"); end
endmodule
