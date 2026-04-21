//axi_agent class
class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)

    int agent_id;
    virtual mgr_interface mgr_intf;
    virtual sub_interface sub_intf;
    axi_agt_config agt_cfg;

    mgr_driver mgr_drvh;
    mgr_monitor mgr_mon;
    mgr_sequencer mgr_seqr;
    sub_driver sub_drvh;
    sub_monitor sub_mon;
    sub_sequencer sub_seqr;


    function new(string name="axi_agent",uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(int)::get(this,"","agent_id",agent_id))
            `uvm_fatal("FROM AGT CLASS","FATAL1")

        if(!uvm_config_db#(axi_agt_config)::get(this,"","axi_agt_config",agt_cfg))
            `uvm_fatal("FATAL2","FROM AGENT CLASS")


        if(!uvm_config_db#(virtual mgr_interface)::get(this,"","mgr_vif",mgr_intf))
            `uvm_fatal("FATAL","FROM GETTING INTERFACE IN AGENT CLASS")
            
        agt_cfg.mgr_intf=mgr_intf;

        if(!uvm_config_db#(virtual sub_interface)::get(this,"","sub_vif",sub_intf))
            `uvm_fatal("FATAL","FROM GETTING INTERFACE IN AGENT CLASS")
        
        agt_cfg.sub_intf=sub_intf;

        uvm_config_db#(axi_agt_config)::set(this,"*","axi_agt_config",agt_cfg);

        mgr_mon=mgr_monitor::type_id::create($sformatf("mgr_mon[%0d]",agent_id),this);
        sub_mon=sub_monitor::type_id::create($sformatf("sub_mon[%0d]",agent_id),this);
        
        
        if(agt_cfg.is_active) begin
            mgr_drvh=mgr_driver::type_id::create($sformatf("mgr_drv[%0d]",agent_id),this);

            mgr_seqr=mgr_sequencer::type_id::create($sformatf("mgr_seqr[%0d]",agent_id),this);
            sub_drvh=sub_driver::type_id::create($sformatf("sub_drvh[%0d]",agent_id),this);

            sub_seqr=sub_sequencer::type_id::create($sformatf("sub_seqr[%0d]",agent_id),this);
        end
    endfunction

endclass