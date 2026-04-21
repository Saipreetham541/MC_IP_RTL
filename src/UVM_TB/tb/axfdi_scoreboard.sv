//****************************************************************************
//* Company: Sevya Multimedia Technologies                                   *
//* Engineer: Shivasai Tatipalli <shivasai.tatipalli@sevyamm.com>            *
//* File Name: axfdi_scoreboard.sv                                           *
//****************************************************************************

class axfdi_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axfdi_scoreboard)

    //INPUT TO SEND PREDICTOR
    uvm_analysis_export #(axi4_seq_item) prd_sub_req_xp[2];
    uvm_analysis_export #(axi4_seq_item) prd_mgr_rsp_xp[2];
    uvm_analysis_export #(fdi_pkt_item)  prd_fdi_rx_xp;

    //INPUTS TO SEND COMPARATOR
    uvm_analysis_export #(axi4_seq_item) cmp_sub_rsp_xp[2];
    uvm_analysis_export #(axi4_seq_item) cmp_mgr_req_xp[2];
    uvm_analysis_export #(fdi_pkt_item)  cmp_fdi_tx_xp;

    axfdi_predictor prd;
    axfdi_comparator cmp;

    function new(string name = "axfdi_scoreboard",uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        
        super.build_phase(phase);
        
        foreach (prd_sub_req_xp[i]) begin
            prd_sub_req_xp[i] = new ($sformatf("prd_sub_req_xp[%0d]",i),this);
            prd_mgr_rsp_xp[i] = new ($sformatf("prd_mgr_rsp_xp[%0d]",i),this);
            cmp_sub_rsp_xp[i] = new ($sformatf("cmp_sub_rsp_xp[%0d]",i),this);
            cmp_mgr_req_xp[i] = new ($sformatf("cmp_mgr_req_xp[%0d]",i),this);
        end 
       
        prd_fdi_rx_xp = new ("prd_fdi_rx_xp",this);
        cmp_fdi_tx_xp = new ("cmp_fdi_tx_xp",this);
       
        //SCOREBOARD COMPONENTS CREATION
        prd = axfdi_predictor::type_id::create("prd", this);
        cmp = axfdi_comparator::type_id::create("cmp", this);

    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // SCORE BOARD TO PREDICTOR AND COMPARATOR CONNECTIONS

        foreach (prd_sub_req_xp[i]) begin
            prd_sub_req_xp[i].connect(prd.sub_req_fifo[i].analysis_export);
            prd_mgr_rsp_xp[i].connect(prd.mgr_rsp_fifo[i].analysis_export);
            cmp_sub_rsp_xp[i].connect(cmp.act_sub_rsp_xp[i]);
            cmp_mgr_req_xp[i].connect(cmp.act_mgr_req_xp[i]);
        end

        prd_fdi_rx_xp.connect(prd.fdi_rx_fifo.analysis_export);
        cmp_fdi_tx_xp.connect(cmp.act_fdi_tx_xp);
        
        
        // PREDICTOR TO COMPARETOR EXPECTED PKT CONNECTION

        foreach(prd_sub_req_xp[i]) begin
            prd.exp_sub_rsp_ap[i].connect(cmp.exp_sub_rsp_xp[i]);
            prd.exp_mgr_req_ap[i].connect(cmp.exp_mgr_req_xp[i]);
        end

        prd.exp_fdi_tx_ap.connect(cmp.exp_fdi_tx_xp);


    endfunction

endclass