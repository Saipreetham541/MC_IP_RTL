`default_nettype none
`timescale 1ns/1ps

// End-to-end AXI/APB regression through real CDC FIFOs, 32 cores and PHY lanes.
module tb_mc16x2_axi;
  /* verilator lint_off BLKSEQ */
  logic  dfi_clk;
  logic  ctl_reset_n;
  logic [31:0]            cmd_push_val;
  logic [31:0][35:0]      cmd_push_entry;
  logic [31:0]            cmdq_full;
  logic [31:0]            wdb_push_val;
  logic [31:0][31:0]      wdb_push_data;
  logic [31:0][3:0]       wdb_push_mask;
  logic [31:0][3:0]       wdb_alloc_ptr;
  logic [31:0]            wdb_full;
  logic [31:0]            rdb_valid;
  logic [31:0]            rdb_ready;
  logic [31:0][31:0]      rdb_data;
  logic [31:0][7:0]       rdb_axi_id;
  logic [15:0]            dfi_row_val;
  logic [15:0][21:0]      dfi_row;
  logic [15:0]            dfi_col_val;
  logic [15:0][11:0]      dfi_col;
  logic [15:0][63:0]      dfi_wrdata;
  logic [15:0][7:0]       dfi_wrdata_mask;
  logic [15:0][1:0]       dfi_wrdata_en;
  logic [15:0][1:0]       dfi_rddata_en;
  logic [15:0][63:0]      dfi_rddata;
  logic [15:0][1:0]       dfi_rddata_valid;
  logic [31:0]            err_cmdq_overflow;
  logic [31:0]            err_wdb_overflow;
  logic [31:0]            err_ref_deadline_miss;
  logic  aclk;
  logic  aresetn;
  logic [7:0]  awid;
  logic [39:0]  awaddr;
  logic [7:0]  awlen;
  logic [2:0]  awsize;
  logic [1:0]  awburst;
  logic [3:0]  awqos;
  logic [3:0]  awcache;
  logic [2:0]  awprot;
  logic  awlock;
  logic  awvalid;
  logic  awready;
  logic [255:0]  wdata;
  logic [31:0]  wstrb;
  logic  wlast;
  logic  wvalid;
  logic  wready;
  logic [7:0]  bid;
  logic [1:0]  bresp;
  logic  bvalid;
  logic  bready;
  logic [7:0]  arid;
  logic [39:0]  araddr;
  logic [7:0]  arlen;
  logic [2:0]  arsize;
  logic [1:0]  arburst;
  logic [3:0]  arqos;
  logic [3:0]  arcache;
  logic [2:0]  arprot;
  logic  arlock;
  logic  arvalid;
  logic  arready;
  logic [7:0]  rid;
  logic [255:0]  rdata;
  logic [1:0]  rresp;
  logic  rlast;
  logic  rvalid;
  logic  rready;
  logic  pclk;
  logic  presetn;
  logic [19:0]  paddr;
  logic  psel;
  logic  penable;
  logic  pwrite;
  logic [31:0]  pwdata;
  logic [3:0]  pstrb;
  logic  pready;
  logic [31:0]  prdata;
  logic  pslverr;
  logic  irq;
  mc16x2 dut (.*);
  int unsigned seed=1;
  realtime axi_half=1.0;
  bit dfi_running=1;
  initial begin dfi_clk=0; forever #0.5 if(dfi_running) dfi_clk=~dfi_clk; end
  initial begin aclk=0; #0.17; forever #(axi_half) aclk=~aclk; end
  initial begin pclk=0; #0.31; forever #10 pclk=~pclk; end
  int dcycle, bhead, btail, rhead, rtail, wtotal, rdtotal, ar_burst_total;
  int bstall, rstall, refreshes[32], writes_seen[32], reads_seen[32];
  int wleft[32], windex[32], active_expect[32];
  int last_act[32][16], last_pre[32][16], last_data[32][16], last_read[32][16];
  int act_history[32][4], last_column[32], last_write[32], last_refresh[32];
  longint unsigned write_key[32];
  bit [15:0] open_banks[32];
  logic [13:0] rows[32][16];
  logic [255:0] reference_memory[longint unsigned];
  logic [255:0] phy_memory[longint unsigned];
  int read_credits[longint unsigned];
  typedef struct packed {logic [7:0] id; logic [1:0] resp;} b_item_t;
  typedef struct packed {logic [7:0] id; logic [1:0] resp; logic last; logic [255:0] data;} r_item_t;
  typedef struct packed {logic valid; logic [39:0] key; logic [255:0] data; logic [31:0] strb;} w_item_t;
  b_item_t expected_b[1024];
  r_item_t expected_r[4096];
  w_item_t expected_w[1024];
  logic [255:0] return_frames[32][64];
  int return_due[32][64], qhead[32], qtail[32], return_word[32];
  bit random_ready;
  bit old_bstall, old_rstall;
  logic [9:0] held_b;
  logic [266:0] held_r;
  logic [31:0] temporary;
  int target, saved_b, saved_r;

  function automatic logic [39:0] address_of(input int p, input int bank, input int row, input int col);
    return {7'b0,4'(p>>1),1'(p),14'(row),2'(bank>>2),2'(bank),5'(col),5'b0};
  endfunction
  function automatic logic [255:0] data_pattern(input int tag);
    logic [255:0] value;
    for (int n=0;n<8;n++) value[n*32+:32]=32'hA531_8709 ^ (32'(tag)*32'h8101_0103) ^ (32'(n)*32'h1731_9181) ^ seed;
    return value;
  endfunction
  function automatic logic [31:0] lane_mask(input logic [39:0] addr,input int size);
    logic [31:0] value;
    value=0;
    for(int n=0;n<32;n++) if(n>=int'(addr[4:0]) && n<int'(addr[4:0])+(1<<size)) value[n]=1;
    return value;
  endfunction
  function automatic logic [255:0] reference_at(input longint unsigned key);
    if(reference_memory.exists(key)!=0) return reference_memory[key];
    return '0;
  endfunction
  function automatic logic [255:0] phy_at(input longint unsigned key);
    if(phy_memory.exists(key)!=0) return phy_memory[key];
    return '0;
  endfunction

  // AXI output scoreboard, including valid/payload stability during stalls.
  always @(posedge aclk) begin
    if (!aresetn || !ctl_reset_n) begin
      old_bstall=0; old_rstall=0;
    end else begin
      if(old_bstall && (!bvalid || {bid,bresp} !== held_b)) $fatal(1,"B changed under stall");
      if(old_rstall && (!rvalid || {rid,rdata,rresp,rlast} !== held_r)) $fatal(1,"R changed under stall");
      old_bstall=bvalid&&!bready; old_rstall=rvalid&&!rready;
      held_b={bid,bresp}; held_r={rid,rdata,rresp,rlast};
      if(bvalid) begin
        if(bhead>=btail || bid !== expected_b[bhead].id || bresp !== expected_b[bhead].resp)
          $fatal(1,"Wrong/duplicate B response index=%0d ID=%h RESP=%b",bhead,bid,bresp);
        if(bready) bhead++; else bstall++;
      end
      if(rvalid) begin
        if(rhead>=rtail || rid !== expected_r[rhead].id || rresp !== expected_r[rhead].resp ||
           rlast !== expected_r[rhead].last || rdata !== expected_r[rhead].data)
          $fatal(1,"Wrong/duplicate R response index=%0d ID=%h RESP=%b LAST=%b got=%h expected=%h",
                 rhead,rid,rresp,rlast,rdata,expected_r[rhead].data);
        if(rready) rhead++; else rstall++;
      end
    end
  end
  always @(negedge aclk) if(random_ready) begin
    bready=((dcycle+int'(seed))%5)!=0;
    rready=((dcycle+int'(seed))%7)>1;
  end

  // PHY command/data model. Each WR/RD command transfers eight lane words.
  // Read snapshots are independent from the host's expected-memory scoreboard.
  always @(posedge dfi_clk) begin : memory_monitor
    int p,b,c,index;
    longint unsigned key;
    logic [255:0] line;
    logic [31:0] word_data;
    logic [3:0] mask;
    if(!dut.core_reset_n) begin
      dcycle=0;
      for(int q=0;q<32;q++) begin
        open_banks[q]=0; wleft[q]=0; windex[q]=0; qhead[q]=0; qtail[q]=0;
        return_word[q]=0; refreshes[q]=0; writes_seen[q]=0; reads_seen[q]=0;
        last_column[q]=-1000000; last_write[q]=-1000000; last_refresh[q]=-1000000;
        for(int k=0;k<16;k++) begin
          last_act[q][k]=-1000000; last_pre[q][k]=-1000000;
          last_data[q][k]=-1000000; last_read[q][k]=-1000000;
        end
        for(int k=0;k<4;k++) act_history[q][k]=-1000000;
      end
    end else begin
      dcycle++;
      #1ps;
      if(err_cmdq_overflow!=0 || err_wdb_overflow!=0 || err_ref_deadline_miss!=0)
        $fatal(1,"Unexpected core overflow/refresh error");
      for(int ch=0;ch<16;ch++) begin
        if(dfi_row_val[ch]) begin
          p=2*ch+int'(dfi_row[ch][21]); b=int'(dfi_row[ch][17:14]);
          case(dfi_row[ch][20:18])
            3'b001: begin
              if(open_banks[p][b] || dcycle-last_pre[p][b]<14 || dcycle-last_act[p][b]<50 ||
                 dcycle-act_history[p][0]<6 || dcycle-act_history[p][3]<32 ||
                 dcycle-last_refresh[p]<350) $fatal(1,"ACT bank/timing violation");
              open_banks[p][b]=1; rows[p][b]=dfi_row[ch][13:0];
              last_act[p][b]=dcycle;
              for(int k=3;k>0;k--) act_history[p][k]=act_history[p][k-1];
              act_history[p][0]=dcycle;
            end
            3'b010: begin
              if(!open_banks[p][b] || (wleft[p]!=0 && int'(write_key[p][13:10])==b) ||
                 dcycle-last_act[p][b]<34 || dcycle-last_data[p][b]<18 ||
                 dcycle-last_read[p][b]<8) $fatal(1,"PRE bank/tRAS/last-data tWR/tRTP violation");
              open_banks[p][b]=0;
              last_pre[p][b]=dcycle;
            end
            3'b100: begin
              if(open_banks[p]!=0 || wleft[p]!=0) $fatal(1,"Unsafe REF");
              for(int k=0;k<16;k++) if(dcycle-last_pre[p][k]<14) $fatal(1,"REF before tRP");
              last_refresh[p]=dcycle;
              refreshes[p]++;
            end
            default: $fatal(1,"Bad row encoding");
          endcase
        end
        if(dfi_col_val[ch]) begin
          p=2*ch+int'(dfi_col[ch][11]); b=int'(dfi_col[ch][8:5]); c=int'(dfi_col[ch][4:0]);
          if(!open_banks[p][b] || dcycle-last_act[p][b]<18 ||
             dcycle-last_column[p]<8 || dcycle-last_refresh[p]<350) $fatal(1,"Column bank/tRCD/burst-spacing/tRFC violation");
          last_column[p]=dcycle;
          key=64'(address_of(p,b,int'(rows[p][b]),c));
          if(dfi_col[ch][10:9]==2'b10) begin
            if(wleft[p]!=0) $fatal(1,"Overlapping write bursts");
            index=-1;
            for(int n=0;n<1024;n++)
              if(expected_w[n].valid && expected_w[n].key==40'(key) &&
                 expected_w[n].data[31:0]==dfi_wrdata[ch][(p%2)*32+:32] &&
                 ~expected_w[n].strb[3:0]==dfi_wrdata_mask[ch][(p%2)*4+:4]) index=n;
            if(index<0) $fatal(1,"Unsolicited/misrouted WR at PC%0d key=%h",p,key);
            active_expect[p]=index; write_key[p]=key; wleft[p]=8; windex[p]=0;
          end else if(dfi_col[ch][10:9]==2'b01) begin
            if(dcycle-last_write[p]<8) $fatal(1,"RD before last-data tWTR");
            last_read[p][b]=dcycle;
            if((read_credits.exists(key)==0) || read_credits[key]<=0) $fatal(1,"Unsolicited/misrouted RD PC%0d",p);
            read_credits[key]--;
            if(qtail[p]-qhead[p]>=64) $fatal(1,"PHY return queue overflow");
            return_frames[p][qtail[p]%64]=phy_at(key);
            return_due[p][qtail[p]%64]=dcycle+5+int'(seed&3);
            qtail[p]++; reads_seen[p]++; rdtotal++;
          end else $fatal(1,"Bad column encoding");
        end
        for(int pc=0;pc<2;pc++) begin
          p=2*ch+pc;
          if(dfi_rddata_en[ch][pc] !== (dfi_col_val[ch] && int'(dfi_col[ch][11])==pc && dfi_col[ch][10:9]==2'b01))
            $fatal(1,"RD enable mismatch");
          if(dfi_wrdata_en[ch][pc]) begin
            if(wleft[p]==0) $fatal(1,"Unsolicited write data");
            index=active_expect[p]; word_data=dfi_wrdata[ch][pc*32+:32]; mask=dfi_wrdata_mask[ch][pc*4+:4];
            if(word_data !== expected_w[index].data[windex[p]*32+:32] ||
               mask !== ~expected_w[index].strb[windex[p]*4+:4])
              $fatal(1,"Serialization/data/mask mismatch PC%0d word%0d",p,windex[p]);
            line=phy_at(write_key[p]);
            for(int byte_n=0;byte_n<4;byte_n++) if(!mask[byte_n])
              line[(windex[p]*4+byte_n)*8+:8]=word_data[byte_n*8+:8];
            phy_memory[write_key[p]]=line;
            last_data[p][int'(write_key[p][13:10])]=dcycle;
            last_write[p]=dcycle;
            wleft[p]--; windex[p]++;
            if(wleft[p]==0) begin expected_w[index].valid=0; writes_seen[p]++; wtotal++; end
          end else if(wleft[p]!=0) $fatal(1,"Gap in write burst");
        end
      end
    end
  end
  always @(negedge dfi_clk) begin
    dfi_rddata_valid='0; dfi_rddata='0;
    if(dut.core_reset_n) for(int p=0;p<32;p++)
      if(qhead[p]<qtail[p] && return_due[p][qhead[p]%64]<=dcycle && (dcycle+p+int'(seed))%5!=0) begin
        dfi_rddata_valid[p/2][p%2]=1;
        dfi_rddata[p/2][(p%2)*32+:32]=return_frames[p][qhead[p]%64][return_word[p]*32+:32];
        if(return_word[p]==7) begin return_word[p]=0; qhead[p]++; end
        else return_word[p]++;
      end
  end

  task automatic apb(input bit wr,input logic [19:0] addr,input logic [31:0] data,
                     input logic [3:0] strb,input bit expect_error,output logic [31:0] result);
    int cycles;
    @(negedge pclk); psel=1; penable=0; paddr=addr; pwrite=wr; pwdata=data; pstrb=strb;
    @(negedge pclk); penable=1; cycles=0;
    do begin @(posedge pclk); cycles++; if(cycles>20) $fatal(1,"APB timeout"); end while(!pready);
    result=prdata;
    if(pslverr !== expect_error) $fatal(1,"APB error mismatch at %h",addr);
    @(negedge pclk); psel=0; penable=0;
  endtask
  task automatic send_aw(input logic [39:0] addr,input int id,len,size,burst,
                         input bit lock,input logic [1:0] response);
    @(negedge aclk);
    awaddr=addr; awid=8'(id); awlen=8'(len); awsize=3'(size); awburst=2'(burst); awlock=lock; awvalid=1;
    do @(posedge aclk); while(!awready);
    expected_b[btail]='{id:8'(id),resp:response}; btail++;
    @(negedge aclk); awvalid=0;
  endtask
  task automatic send_w(input logic [39:0] addr,input logic [255:0] data,input logic [31:0] strb,
                        input bit last,commit);
    longint unsigned key;
    logic [255:0] line;
    int slot;
    @(negedge aclk); wdata=data; wstrb=strb; wlast=last; wvalid=1;
    do @(posedge aclk); while(!wready);
    if(commit) begin
      key=64'(addr) & ~64'd31; line=reference_at(key);
      for(int byte_n=0;byte_n<32;byte_n++) if(strb[byte_n]) line[byte_n*8+:8]=data[byte_n*8+:8];
      reference_memory[key]=line;
      slot=-1;
      for(int n=1023;n>=0;n--) if(!expected_w[n].valid) slot=n;
      if(slot<0) $fatal(1,"Write scoreboard full");
      expected_w[slot]='{valid:1'b1,key:40'(key),data:data,strb:strb};
    end
    @(negedge aclk); wvalid=0;
  endtask
  task automatic write_burst(input logic [39:0] addr,input int id,len,size,
                            input logic [31:0] mask,input bit w_first,input logic [1:0] response,
                            input int burst=1,input bit lock=0,input bit bad_last=0);
    int goal;
    goal=btail+1;
    if(!w_first) send_aw(addr,id,len,size,burst,lock,response);
    for(int beat_n=0;beat_n<=len;beat_n++) begin
      repeat((beat_n+int'(seed))%3) @(negedge aclk);
      send_w(addr+(40'(beat_n)<<size),data_pattern(id*32+beat_n),
             mask & lane_mask(addr+(40'(beat_n)<<size),size),
             bad_last ? 1'b0 : (beat_n==len),response==0);
    end
    if(w_first) begin
      if(len==15) begin
        repeat(4) @(negedge aclk);
        if(wready) $fatal(1,"W FIFO did not fill before AW");
      end
      send_aw(addr,id,len,size,burst,lock,response);
    end
    while(bhead<goal) @(negedge aclk);
  endtask
  task automatic send_ar(input logic [39:0] addr,input int id,len,size,
                        input logic [1:0] response,input int burst=1,input bit lock=0);
    longint unsigned key;
    logic [255:0] line;
    logic [31:0] lanes;
    @(negedge aclk); araddr=addr; arid=8'(id); arlen=8'(len); arsize=3'(size);
    arburst=2'(burst); arlock=lock; arvalid=1;
    do @(posedge aclk); while(!arready);
    ar_burst_total++;
    for(int beat_n=0;beat_n<=len;beat_n++) begin
      key=(64'(addr)+(64'(beat_n)<<size)) & ~64'd31;
      lanes=lane_mask(addr+(40'(beat_n)<<size),size); line=reference_at(key);
      for(int n=0;n<32;n++) if(!lanes[n] || response!=0) line[n*8+:8]=0;
      expected_r[rtail]='{id:8'(id),resp:response,last:(beat_n==len),data:line}; rtail++;
      if(response==0) begin
        if((read_credits.exists(key)==0)) read_credits[key]=0;
        read_credits[key]++;
      end
    end
    @(negedge aclk); arvalid=0;
  endtask
  task automatic read_burst(input logic [39:0] addr,input int id,len,size,
                           input logic [1:0] response,input int burst=1,input bit lock=0);
    int goal;
    goal=rtail+len+1;
    send_ar(addr,id,len,size,response,burst,lock);
    while(rhead<goal) @(negedge aclk);
  endtask
  task automatic reset_transactions(input bit fast_release=0,input int reset_kind=0);
    @(negedge aclk);
    if(reset_kind!=2) aresetn=0;
    if(reset_kind!=1) ctl_reset_n=0;
    awvalid=0; arvalid=0; wvalid=0; random_ready=0; bready=0; rready=0;
    repeat(5) @(negedge aclk);
    bhead=0; btail=0; rhead=0; rtail=0;
    foreach(expected_w[n]) expected_w[n]='0;
    read_credits.delete();
    aresetn=1; ctl_reset_n=1;
    if(!fast_release) repeat(8) @(negedge aclk);
    if(bvalid || rvalid) $fatal(1,"Stale AXI response after reset");
    bready=1; rready=1;
  endtask

  initial begin : stimulus
    logic [39:0] base;
    if(!$value$plusargs("seed=%d",seed)) seed=1;
    axi_half=1.0+0.1*real'(seed%3);
    ctl_reset_n=0; aresetn=0; presetn=0;
    cmd_push_val=0; cmd_push_entry=0; wdb_push_val=0; wdb_push_data=0; wdb_push_mask=0; rdb_ready=0;
    awid=0; awaddr=0; awlen=0; awsize=0; awburst=1; awqos=0; awcache=0; awprot=0; awlock=0; awvalid=0;
    wdata=0; wstrb=0; wlast=0; wvalid=0; bready=0;
    arid=0; araddr=0; arlen=0; arsize=0; arburst=1; arqos=0; arcache=0; arprot=0; arlock=0; arvalid=0; rready=0;
    paddr=0; psel=0; penable=0; pwrite=0; pwdata=0; pstrb=0;
    bhead=0;btail=0;rhead=0;rtail=0;wtotal=0;rdtotal=0;bstall=0;rstall=0;random_ready=0;ar_burst_total=0;
    foreach(expected_w[n]) expected_w[n]='0;
    repeat(5) @(negedge pclk); presetn=1;
    reset_transactions();
    $display("AXI/APB end-to-end seed=%0d",seed);
    apb(0,20'h0,0,0,0,temporary); if(temporary!=32'h4D43_1602) $fatal(1,"Wrong IP ID");
    apb(1,20'h0,0,15,1,temporary);
    apb(0,20'h3,0,0,1,temporary);
    apb(0,20'h100,0,0,1,temporary);
    apb(1,20'h4,0,0,0,temporary);
    apb(0,20'h4,0,0,0,temporary); if(temporary!=1) $fatal(1,"Zero PSTRB changed a register");
    apb(1,20'hC,32'h1234_5678,1,0,temporary);
    apb(0,20'hC,0,0,0,temporary); if(temporary!=32'h478) $fatal(1,"APB byte strobes failed");
    apb(1,20'hC,1024,15,0,temporary);
    apb(0,20'h10,0,0,0,temporary); if(!temporary[5]) $fatal(1,"APB access error did not latch status");
    apb(1,20'h10,32'h3F,15,0,temporary);
    apb(0,20'h10,0,0,0,temporary); if(temporary!=0) $fatal(1,"APB error W1C failed");
    $display("TEST bounded APB wait and delayed CDC acknowledgement");
    @(negedge dfi_clk); dfi_running=0;
    apb(0,20'h0,0,0,1,temporary);
    dfi_running=1;
    repeat(8) @(negedge pclk);
    apb(0,20'h10,0,0,0,temporary); if(!temporary[5] || !irq) $fatal(1,"APB timeout event was lost");
    apb(1,20'h10,32'h20,15,0,temporary);
    apb(0,20'h0,0,0,0,temporary); if(temporary!=32'h4D43_1602) $fatal(1,"Late APB reply corrupted next access");
    random_ready=1;

    $display("TEST all 32 destinations and 256-bit data/masks");
    for(int p=0;p<32;p++) begin
      base=address_of(p,p%16,32'h123,(p+3)%16);
      write_burst(base,p,1,5,32'hFFFF_FFFF,(p%2)!=0,0);
      read_burst(base,p,1,5,0);
      write_burst(base,p+32,0,5,32'h0F0F_55AA,0,0);
      read_burst(base,p+32,0,5,0);
    end
    $display("TEST 16-beat W-before-AW burst and narrow writes/reads");
    base=address_of(0,0,32'h123,0);
    write_burst(base,80,15,5,'1,1,0);
    read_burst(base,80,15,5,0);
    write_burst(address_of(3,0,32'h1555,28),81,15,5,'1,0,0);
    read_burst(address_of(3,0,32'h1555,28),81,15,5,0);
    // Immediate row conflict must honor tWR measured from word 7, not WR command.
    write_burst(address_of(0,0,32'h123,5),82,0,5,'1,0,0);
    write_burst(address_of(0,0,32'h1555,5),83,0,5,'1,0,0);
    read_burst(address_of(0,0,32'h1555,5),83,0,5,0);
    for(int sz=0;sz<5;sz++) begin
      write_burst(address_of(31,3,32'h1555,24),90+sz,3,sz,'1,0,0);
      read_burst(address_of(31,3,32'h1555,24),90+sz,3,sz,0);
    end
    write_burst(base,99,0,5,0,0,0); read_burst(base,99,0,5,0);

    $display("TEST queued AW headers and B FIFO backpressure");
    random_ready=0; bready=0; rready=1;
    saved_b=btail;
    for(int n=0;n<9;n++) send_aw(address_of(2,1,32'h123,n),110+n,0,5,1,0,0);
    repeat(5) @(negedge aclk);
    if(awready) $fatal(1,"AW FIFO did not fill");
    for(int n=0;n<9;n++) send_w(address_of(2,1,32'h123,n),data_pattern(110+n),'1,1,1);
    repeat(200) @(negedge aclk);
    if(!bvalid || bhead!=saved_b || dut.g_axi.u_axi_cdc.u_b_fifo.wready)
      $fatal(1,"B FIFO backpressure not exercised");
    bready=1;
    while(bhead<btail) @(negedge aclk);

    $display("TEST full R/AR FIFOs and stable stalled responses");
    rready=0;
    send_ar(base,130,15,5,0);
    send_ar(base,131,1,5,0);
    repeat(600) @(negedge aclk);
    for(int n=0;n<8;n++) send_ar(base,132+n,0,5,0);
    repeat(10) @(negedge aclk);
    if(!rvalid || arready || dut.g_axi.u_axi_cdc.u_r_fifo.wready) $fatal(1,"R/AR FIFOs did not backpressure");
    random_ready=1;
    while(rhead<rtail) @(negedge aclk);

    $display("TEST APB enable/disable, channel errors, protocol errors and IRQ");
    random_ready=0; bready=1; rready=1;
    apb(1,20'h4,0,1,0,temporary);
    send_ar(base,150,0,5,0);
    repeat(40) @(negedge aclk);
    if(rvalid) $fatal(1,"Disabled frontend still admitted work");
    apb(1,20'h4,1,1,0,temporary);
    while(rhead<rtail) @(negedge aclk);
    apb(1,20'h8,32'hFFF7,3,0,temporary);
    read_burst(address_of(6,0,32'h123,0),151,0,5,3);
    write_burst(address_of(7,0,32'h123,0),152,0,5,'1,0,3);
    apb(1,20'h8,32'hFFFF,3,0,temporary);
    read_burst(40'h200000000,153,0,5,3);
    read_burst(base,154,0,5,2,0);
    read_burst(base+1,155,0,2,2);
    read_burst(address_of(0,3,32'h123,31),156,1,5,2);
    read_burst(base,157,16,5,2);
    read_burst(base,158,0,5,2,1,1);
    write_burst(base,159,0,5,'1,0,2,1,0,1);
    target=btail+1;
    send_aw(base,160,0,0,1,0,2);
    send_w(base,data_pattern(160),32'h2,1,0); // strobe outside the byte lane
    while(bhead<target) @(negedge aclk);
    target=btail+1;
    send_aw(base,161,1,5,1,0,2);
    send_w(base,data_pattern(161),32'hFFFF_FFFF,1,0); // early WLAST
    send_w(base+32,data_pattern(162),32'hFFFF_FFFF,1,0);
    while(bhead<target) @(negedge aclk);
    write_burst(base,163,0,5,'1,0,2,1,1);
    write_burst(base,164,16,5,'1,0,2);
    apb(0,20'h24,0,0,0,temporary); if(temporary!=32'(btail)) $fatal(1,"Write burst counter mismatch");
    apb(0,20'h28,0,0,0,temporary); if(temporary!=32'(ar_burst_total)) $fatal(1,"Read burst counter mismatch");
    if(!irq) $fatal(1,"Protocol IRQ absent");
    apb(0,20'h10,0,0,0,temporary); if(!temporary[1]) $fatal(1,"Protocol status absent");
    apb(1,20'h14,0,15,0,temporary); if(irq) $fatal(1,"IRQ mask failed");
    apb(1,20'h10,32'h3F,15,0,temporary);
    apb(0,20'h10,0,0,0,temporary); if(temporary!=0) $fatal(1,"W1C failed");
    apb(1,20'h14,32'h3F,15,0,temporary);
    while(dcycle<4400) @(negedge dfi_clk);
    for(int p=0;p<32;p++)
      if(writes_seen[p]==0 || reads_seen[p]==0 || refreshes[p]==0) $fatal(1,"Missing PC%0d traffic/refresh coverage",p);
    if(bstall==0 || rstall==0) $fatal(1,"No response backpressure");
    foreach(expected_w[n]) if(expected_w[n].valid) $fatal(1,"Posted write was lost before recovery reset");

    $display("TEST missing WDATA timeout, poisoned write-path recovery and reset flush");
    apb(1,20'hC,64,15,0,temporary);
    target=btail+1; send_aw(base,170,0,5,1,0,2);
    while(bhead<target) @(negedge aclk);
    apb(0,20'h10,0,0,0,temporary); if(!temporary[0] || !irq) $fatal(1,"Timeout status/IRQ absent");
    apb(0,20'h2C,0,0,0,temporary); if(!temporary[1]) $fatal(1,"Write poison state absent");
    read_burst(base,171,0,5,0);
    reset_transactions(0,1);
    apb(0,20'hC,0,0,0,temporary); if(temporary!=64) $fatal(1,"AXI reset erased CSR configuration");
    apb(1,20'hC,1024,15,0,temporary);
    read_burst(base,172,0,5,0);
    // Flush a queued/in-flight read and recover using retained PHY memory.
    send_ar(base,173,15,5,0);
    repeat(10) @(negedge aclk);
    reset_transactions(1,2);
    read_burst(base,174,0,5,0);
    write_burst(address_of(31,0,32'h123,0),175,0,5,'1,0,0);
    read_burst(address_of(31,0,32'h123,0),175,0,5,0);
    repeat(20) @(negedge aclk);
    foreach(expected_w[n]) if(expected_w[n].valid) $fatal(1,"Unconsumed write scoreboard entry");
    if(bhead!=btail || rhead!=rtail) $fatal(1,"Unconsumed AXI responses");
    $display("PASS AXI/APB seed=%0d checked PHY writes=%0d reads=%0d B-stalls=%0d R-stalls=%0d",seed,wtotal,rdtotal,bstall,rstall);
    $finish;
  end
  initial begin #200000; $fatal(1,"AXI/APB regression watchdog"); end
  /* verilator lint_on BLKSEQ */
endmodule
`default_nettype wire
