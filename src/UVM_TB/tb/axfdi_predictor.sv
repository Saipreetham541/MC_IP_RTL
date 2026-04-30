class axfdi_predictor extends uvm_component;

    `uvm_component_utils(axfdi_predictor)


  //PARAMETER DECLEARATION

  localparam int unsigned BYTES_PER_BEAT       = 128;
  localparam int unsigned NP_INIT_CREDIT       = 32;
  localparam int unsigned CPL_INIT_CREDIT      = 32;
  localparam int unsigned CREDIT_RTN_THRESHOLD = 16;
  localparam int unsigned CFG_NP_WEIGHT        = 2;
  localparam int unsigned CFG_CPL_WEIGHT       = 1;

  //ENUM DECLEARATION

  typedef enum bit [3:0] {
        WRITE_REQ   = 4'h0,
        READ_REQ    = 4'h1,
        WRITE_RESP  = 4'h2,
        READ_RESP   = 4'h3,
        CREDIT_RTN  = 4'h4,
        NOP         = 4'h5,
        RESERVED    = 4'h6
    } opcode_e;


    //PREDICTOR INPUTS

    uvm_tlm_analysis_fifo #(axi4_seq_item) sub_req_fifo[2];
    uvm_tlm_analysis_fifo #(axi4_seq_item) mgr_rsp_fifo[2];
    uvm_tlm_analysis_fifo #(fdi_pkt_item)  fdi_rx_fifo;
 
    //PREDICTOR OUTPUTS
    
    uvm_analysis_port #(axi4_seq_item) exp_sub_rsp_ap[2];
    uvm_analysis_port #(axi4_seq_item) exp_mgr_req_ap[2];
    uvm_analysis_port #(fdi_pkt_item)  exp_fdi_tx_ap;

    //AXI TRANSACTION QUEUES

    axi4_seq_item wr_req_q[2][$];
    axi4_seq_item rd_req_q[2][$];
    axi4_seq_item wr_rsp_q[2][$];
    axi4_seq_item rd_rsp_q[2][$];

    //USEFULL VARIABLES

    bit       last_port;
    opcode_e  last_req_txn_type;
    opcode_e  last_rsp_txn_type;

    int unsigned np_cnt, cpl_cnt;
    int unsigned tx_np_credit_cnt, tx_cpl_credit_cnt;
    int unsigned rx_np_consumed, rx_cpl_consumed;

    bit init_np_pending, init_cpl_pending;
    bit credit_rtn_pending;
    bit [1:0] credit_rtn_vcn_q;
    bit [5:0] credit_rtn_cnt_q;


    function new (input string name = "axfdi_predictor", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

         //CREATING RECURSIVE PORTS AND FIFOS

        foreach (sub_req_fifo[i]) begin
            sub_req_fifo[i]   = new($sformatf("sub_req_fifo_p[%0d]",i),this);
            mgr_rsp_fifo[i]   = new($sformatf("mgr_rsp_fifo_p[%0d]",i),this);
            exp_sub_rsp_ap[i] = new($sformatf("exp_sub_rsp_ap[%0d]",i),this);
            exp_mgr_req_ap[i] = new($sformatf("exp_mgr_req_ap[%0d]",i),this);
        end 

        //CREATING PORTS AND FIFOS

        fdi_rx_fifo   = new("fdi_rx_fifo",this);
        exp_fdi_tx_ap = new("exp_fdi_tx_ap",this);

        // Predictor-local reset defaults.
        np_cnt            = CFG_NP_WEIGHT;
        cpl_cnt           = CFG_CPL_WEIGHT;
        tx_np_credit_cnt  = 0;
        tx_cpl_credit_cnt = 0;
        rx_np_consumed    = 0;
        rx_cpl_consumed   = 0;

        init_np_pending   = 1'b1;
        init_cpl_pending  = 1'b1;
        credit_rtn_pending = 1'b0;
        credit_rtn_vcn_q   = '0;
        credit_rtn_cnt_q   = '0;

        last_port         = 1'b1;
        last_req_txn_type = READ_REQ;
        last_rsp_txn_type = READ_RESP;
    endfunction

    task run_phase(uvm_phase phase);
        fork

            //$display("\n[PRD] run_phase\n");
            //$display("\n\n");
            collect_sub_req(0);
            collect_sub_req(1);
            collect_mgr_rsp(0);
            collect_mgr_rsp(1);
            collect_fdi_rx();
        join
    endtask

    //INPUTS COLLECTOR TASKS
        
    task collect_sub_req(int port);
        axi4_seq_item req, req_c;
        forever begin
            sub_req_fifo[port].get(req);
            $display("\n[PRD] collect_sub_req\n");
            $display(req.convert2string);
			$display("axn_type=%0s",req.axn_type);
            $display("\n\n");
            req_c = axi4_seq_item::type_id::create("req_c");
            req_c.copy(req);
            if (req_c.axn_type == WRITE) begin
                void'(wr_req_q[port].push_back(req_c));
            end
            else begin
                void'(rd_req_q[port].push_back(req_c)); 
            end                       
            try_schedule_tx();
        end
    endtask

    task collect_mgr_rsp(int port);
        axi4_seq_item rsp, rsp_c;
        forever begin
            mgr_rsp_fifo[port].get(rsp);
            $display("\n[PRD] collect_mgr_rsp\n");
            $display(rsp.convert2string);
            $display("\n\n");
            rsp_c = axi4_seq_item::type_id::create("rsp_c");
            rsp_c.copy(rsp);
            if (rsp_c.axn_type == WRITE) begin
                wr_rsp_q[port].push_back(rsp_c);
            end 
            else begin
                rd_rsp_q[port].push_back(rsp_c);
            end                       
            try_schedule_tx();
        end
    endtask 

    task collect_fdi_rx();
        fdi_pkt_item  pkt, pkt_c;
        axi4_seq_item exp_axi_req, exp_axi_rsp;
        int           port;
        forever begin
            fdi_rx_fifo.get(pkt);
            pkt_c = fdi_pkt_item::type_id::create("pkt_c");
            pkt_c.copy(pkt);

            //$display("\n[PRD] collect_fdi_rx\n");
            //$display(pkt.convert2string);
            //$display("\n\n");

            if (pkt_c.opcode == 4'd4) begin
                
                $display("\n[PRD] collect_fdi_rx(credit)\n");
                $display(pkt_c.convert2string);
                $display("\n\n");

                if (pkt_c.credit_rtn_vcn == 2'h0)begin
                   tx_np_credit_cnt  += pkt_c.credit_rtn_cnt; 
                end 
                if (pkt_c.credit_rtn_vcn == 2'h1)begin
                    tx_cpl_credit_cnt += pkt_c.credit_rtn_cnt;
                end
                $display("\n[PRD] collect_fdi_rx(credit)\n");
                $display("tx_np_credit_cnt %0d || tx_cpl_credit_cnt %0d",tx_np_credit_cnt,tx_cpl_credit_cnt);
                $display("\n\n");
            end
            else if (pkt_c.opcode == 4'd0 || pkt_c.opcode == 4'd1 ) begin
                $display("\n[PRD] collect_fdi_rx(request)\n");
                $display(pkt_c.convert2string);
                $display("\n\n");

                rx_np_consumed++;
                exp_axi_req = predict_axi_mgr_req_from_fdi_rx_req(pkt_c);
                port = pkt_c.port_id;
                exp_mgr_req_ap[port].write(exp_axi_req);
            end
            else if (pkt_c.opcode == WRITE_RESP || pkt_c.opcode == READ_RESP) begin
                $display("\n[PRD] collect_fdi_rx(response)\n");
                $display(pkt_c.convert2string);
                $display("\n\n");

                rx_cpl_consumed++;
                exp_axi_rsp = predict_axi_sub_rsp_from_fdi_rx_rsp(pkt_c);
                port = pkt_c.port_id;
                exp_sub_rsp_ap[port].write(exp_axi_rsp);
            end

            update_credit_rtn_state();
            try_schedule_tx();
        end
    endtask

    //CREDIT RETURN UPDATE FUNCTION

    function void update_credit_rtn_state();
        if (init_cpl_pending) begin
            credit_rtn_pending = 1'b1;
            credit_rtn_vcn_q = 2'h1;
            credit_rtn_cnt_q = CPL_INIT_CREDIT[5:0];
        end
        else if (init_np_pending) begin
            credit_rtn_pending = 1'b1;
            credit_rtn_vcn_q = 2'h0;
            credit_rtn_cnt_q = NP_INIT_CREDIT[5:0];
        end
        else if (rx_cpl_consumed >= CREDIT_RTN_THRESHOLD) begin
            credit_rtn_pending = 1'b1;
            credit_rtn_vcn_q = 2'h1;
            credit_rtn_cnt_q = rx_cpl_consumed[5:0];
        end
        else if (rx_np_consumed >= CREDIT_RTN_THRESHOLD) begin
            credit_rtn_pending = 1'b1;
            credit_rtn_vcn_q = 2'h0;
            credit_rtn_cnt_q = rx_np_consumed[5:0];
        end
    endfunction

    //TRANSACTION CHECK FUNCTIONS

    function bit check_port_has_any_tx_req_txn_ready(int port);
        return (wr_req_q[port].size() != 0) || (rd_req_q[port].size() != 0);
    endfunction
    function bit check_port_has_any_tx_rsp_txn_ready(int port);
        return (wr_rsp_q[port].size() != 0) || (rd_rsp_q[port].size() != 0);
    endfunction
    function bit check_port_has_any_tx_txn_ready(int port);
        return check_port_has_any_tx_req_txn_ready(port) || check_port_has_any_tx_rsp_txn_ready(port);
    endfunction
    function bit check_bridge_has_any_tx_txn_ready();
        return check_port_has_any_tx_txn_ready(0) || check_port_has_any_tx_txn_ready(1);
    endfunction

    //CHOOSING NEXT TRANSACTION TYPE FUNCTIONS

    function opcode_e choose_next_req_txn_type(int port);
        if ((wr_req_q[port].size() != 0) && ((last_req_txn_type != WRITE_REQ) || (rd_req_q[port].size() == 0))) begin
            return WRITE_REQ;
        end
        else begin
            return READ_REQ;
        end
    endfunction

    function opcode_e choose_next_rsp_txn_type(int port);
        if ((wr_rsp_q[port].size() != 0) && ((last_rsp_txn_type != WRITE_RESP) || (rd_rsp_q[port].size() == 0)))begin
             return WRITE_RESP;
        end
        else begin
             return READ_RESP;  
        end  
    endfunction

    //CHOOSE NEXT TRANSACTION BASED ON DESIDED PORT AND TYPE

    function bit choose_next_tx(output int port, output opcode_e txn_type);
        bit p0_any_txn_redy, p1_any_txn_redy, cpl_txn_ready, np_txn_ready;
        port = 0; 
        txn_type = NOP;

        if (credit_rtn_pending && !check_bridge_has_any_tx_txn_ready()) begin
            txn_type = CREDIT_RTN;
            return 1;
        end

        p0_any_txn_redy = check_port_has_any_tx_txn_ready(0);
        p1_any_txn_redy = check_port_has_any_tx_txn_ready(1);

        if (!p0_any_txn_redy && !p1_any_txn_redy) begin 
            return 0;
        end
        if (p0_any_txn_redy && p1_any_txn_redy) begin
            port = (last_port == 1'b1) ? 0 : 1; 
        end 
        else begin
            port = p0_any_txn_redy ? 0 : 1;
        end                

        cpl_txn_ready = check_port_has_any_tx_rsp_txn_ready(port) && (cpl_cnt > 0) && (tx_cpl_credit_cnt > 0);
        np_txn_ready  = check_port_has_any_tx_req_txn_ready(port) && (np_cnt  > 0) && (tx_np_credit_cnt  > 0);

        if (cpl_txn_ready && (!np_txn_ready || (cpl_cnt >= np_cnt))) begin
            txn_type = choose_next_rsp_txn_type(port);
        return 1;
        end
        if (np_txn_ready) begin
            txn_type = choose_next_req_txn_type(port);
        return 1;
        end
        return 0;
    endfunction

    //DATA AND STROBE PACKING AND UNPACKING FUNCTIONS

    function void pack_axi_payload_to_fdi(axi4_seq_item axi, ref fdi_pkt_item pkt);

        pkt.data  = new[216];
        pkt.wstrb = new[0];

        // Fill zeros
        for (int i = 0; i < 216; i++) begin
            pkt.data[i] = 8'h00;
        end

        // Fill AXI data (MSB-first)
        for (int i = 0; i <=127; i++) begin
            pkt.data[215-i] = axi.data[0][1023 - (i*8) -: 8];
        end

    endfunction

    function void unpack_fdi_payload_to_axi(fdi_pkt_item pkt, ref axi4_seq_item axi);

    axi.data = new[1];
    axi.strb = new[1];

    axi.data[0] = '0;

    // Only 128 bytes map to AXI (1024 bits)
    for (int i = 0; i < 128; i++) begin
        axi.data[0][1023 - (i*8) -: 8] = pkt.data[215 - i];

        //$display("pkt.data[%0d] = %0h\n", 215-i, pkt.data[215-i]);
        //$display("axi.data[0][%0d] = %0h", 1023 - (i*8), axi.data[0][1023 - (i*8) -: 8]);
    end

    //$display("\nAXI DATA = %0h\n", axi.data[0]);

    // WSTRB handling
    if (pkt.wstrb.size() > 0)
        axi.strb[0] = pkt.wstrb[0];
    else
        axi.strb[0] = '1;

endfunction

    //BULDING EXPECTED FDI PACKET FROM AXI TXN

    function fdi_pkt_item build_exp_fdi_pkt(int port, opcode_e txn_type);
        fdi_pkt_item  pkt;
        axi4_seq_item axi;
        pkt = fdi_pkt_item::type_id::create("pkt");
        pkt.port_id = port;
        pkt.opcode  = txn_type;
        pkt.vcn     = (txn_type == WRITE_RESP || txn_type == READ_RESP) ? 3'h1 : 3'h0; 

        if (txn_type == WRITE_REQ) begin
            axi = wr_req_q[port][0];
            pkt.txn_id = axi.id; 
            pkt.burst_len = axi.len; 
            pkt.burst_type = axi.burst;
            pkt.burst_size = axi.size; 
            pkt.resp = axi.resp; 
            pkt.addr = axi.addr;
            pack_axi_payload_to_fdi(axi, pkt);
        end
        else if (txn_type == READ_REQ) begin
            axi = rd_req_q[port][0];
            pkt.txn_id = axi.id;
            pkt.burst_len = axi.len;
            pkt.burst_type = axi.burst;
            pkt.burst_size = axi.size;
            pkt.resp = axi.resp;
            pkt.addr = axi.addr;
            pkt.data = new[0];
            pkt.wstrb = new[0];
        end
        else if (txn_type == WRITE_RESP) begin
            axi = wr_rsp_q[port][0];
            pkt.txn_id = axi.id;
            pkt.resp = axi.resp;
            pkt.data = new[0];
            pkt.wstrb = new[0];
        end
        else if (txn_type == READ_RESP) begin
            axi = rd_rsp_q[port][0];
            pkt.txn_id = axi.id;
            pkt.resp = axi.resp;
            pack_axi_payload_to_fdi(axi, pkt);
        end
        else begin
            pkt.port_id = '0;
            pkt.vcn     = '0;
            pkt.txn_id = '0;
            pkt.burst_len = '0;
            pkt.burst_type = '0;
            pkt.burst_size = '0;
            pkt.resp = '0;
            pkt.addr = '0;
            pkt.data = new[0];
            pkt.wstrb = new[0];
        end

        if (credit_rtn_pending) begin
            pkt.credit_rtn_vcn = credit_rtn_vcn_q;
            pkt.credit_rtn_cnt = credit_rtn_cnt_q;
        end
        else begin
            pkt.credit_rtn_vcn = '0;
            pkt.credit_rtn_cnt = '0;
        end
        return pkt;
    endfunction

    task update_after_tx(int port, opcode_e txn_type, fdi_pkt_item pkt);
        case (txn_type)
            WRITE_REQ : begin 
                void'(wr_req_q[port].pop_front());
                last_req_txn_type = WRITE_REQ;
                last_port = port;
                np_cnt--;
                tx_np_credit_cnt--;  
            end
            READ_REQ  : begin 
                void'(rd_req_q[port].pop_front());
                last_req_txn_type = READ_REQ;
                last_port = port;
                np_cnt--;
                tx_np_credit_cnt--;  
            end
            WRITE_RESP: begin 
                void'(wr_rsp_q[port].pop_front());
                last_rsp_txn_type = WRITE_RESP;
                last_port = port;
                cpl_cnt--;
                tx_cpl_credit_cnt--;
            end
            READ_RESP : begin 
                void'(rd_rsp_q[port].pop_front());
                last_rsp_txn_type = READ_RESP;
                last_port = port;
                cpl_cnt--;
                tx_cpl_credit_cnt--;
            end
            CREDIT_RTN: begin 

            end
        endcase

        if (credit_rtn_pending) begin
            if (credit_rtn_vcn_q == 2'h1 && init_cpl_pending) init_cpl_pending = 0;
            else if (credit_rtn_vcn_q == 2'h0 && init_np_pending) init_np_pending = 0;
            else begin
                if (credit_rtn_vcn_q == 2'h0) rx_np_consumed  = 0;
                if (credit_rtn_vcn_q == 2'h1) rx_cpl_consumed = 0;
            end
            credit_rtn_pending = 0;
            credit_rtn_vcn_q   = '0;
            credit_rtn_cnt_q   = '0;
        end

        if (np_cnt == 0 && cpl_cnt == 0) begin
            np_cnt  = CFG_NP_WEIGHT;
            cpl_cnt = CFG_CPL_WEIGHT;
        end
    endtask

    task try_schedule_tx();
        int         port;
        opcode_e    txn_type;
        fdi_pkt_item exp_pkt;

        if (choose_next_tx(port, txn_type)) begin
            exp_pkt = build_exp_fdi_pkt(port, txn_type);
            exp_fdi_tx_ap.write(exp_pkt);
            update_after_tx(port, txn_type, exp_pkt);
        end
    endtask

    function axi4_seq_item predict_axi_mgr_req_from_fdi_rx_req(fdi_pkt_item pkt);
    
        axi4_seq_item req = axi4_seq_item::type_id::create("req");
        req.addr  = pkt.addr;
        req.id    = pkt.txn_id;
        req.len   = pkt.burst_len;
        req.size  = pkt.burst_size;
        req.burst = pkt.burst_type;
        req.resp  = pkt.resp;
        unpack_fdi_payload_to_axi(pkt, req);
        req.axn_type = (pkt.opcode == WRITE_REQ) ? WRITE : READ;
        $display("\n[PRD] predict_axi_mgr_req_from_fdi_rx_req(request)\n");
        $display(req.convert2string);
        $display("\n\n");
        $display("dsts_size = %0d",req.data.size()  );
        return req;
    endfunction

    function axi4_seq_item predict_axi_sub_rsp_from_fdi_rx_rsp(fdi_pkt_item pkt);
        axi4_seq_item rsp = axi4_seq_item::type_id::create("rsp");
        rsp.addr   = pkt.addr;
        rsp.id     = pkt.txn_id;
        rsp.len    = pkt.burst_len;
        rsp.size   = pkt.burst_size;
        rsp.burst  = pkt.burst_type;
        rsp.resp   = pkt.resp;
        unpack_fdi_payload_to_axi(pkt, rsp);
        rsp.axn_type = (pkt.opcode == WRITE_RESP) ? WRITE : READ;

        $display("\n[PRD] predict_axi_sub_rsp_from_fdi_rx_rsp(request)\n");
        $display(rsp.convert2string);
        $display("\n\n");

        return rsp;
    endfunction
endclass
