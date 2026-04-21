//==============================================================
// AXI COVERAGE COLLECTOR
// Reusable for SUB / MGR interfaces
//==============================================================
class axi_cov extends uvm_subscriber #(axi4_seq_item);

  `uvm_component_utils(axi_cov)

  covergroup cg_axi with function sample(axi4_seq_item t);

    option.per_instance = 1;
    option.name = "cg_axi";

    //----------------------------------------------------------
    // READ / WRITE
    //----------------------------------------------------------
    cp_type : coverpoint t.axn_type {
      bins read  = {READ};
      bins write = {WRITE};
    }

    //----------------------------------------------------------
    // BURST TYPE
    // FIXED accepted by DUT and mapped internally
    cp_burst : coverpoint t.burst {
      bins fixed = {0};
      bins incr  = {1};
      bins wrap  = {2};
      illegal_bins reserved = {3};
    }

    //----------------------------------------------------------
    // BURST LENGTH
    // beats = len + 1
    //----------------------------------------------------------
    cp_len : coverpoint t.len {
      bins single   = {0};     // 1 beat
      illegal_bins burst4   = {3};     // 4 beats
      illegal_bins burst8   = {7};
      illegal_bins burst16  = {15};
      illegal_bins burst32  = {31};
      illegal_bins burst64  = {63};
      illegal_bins burst128 = {127};
      illegal_bins burst256 = {255};   // max
      illegal_bins others[] = {[1:254]};
    }

    //----------------------------------------------------------
    // TRANSFER SIZE (bytes = 2^size)
    //----------------------------------------------------------
    cp_size : coverpoint t.size {
      illegal_bins b1   = {0};
      illegal_bins b2   = {1};
      illegal_bins b4   = {2};
      illegal_bins b8   = {3};
      illegal_bins b16  = {4};
      illegal_bins b32  = {5};
      illegal_bins b64  = {6};
      bins b128 = {7}; // full 128-byte bus
    }

    //----------------------------------------------------------
    // RESPONSE
    // EXOKAY unsupported in DUT
    //----------------------------------------------------------
    cp_resp : coverpoint t.resp {
      bins okay   = {0};
      bins slverr = {2};
      bins decerr = {3};
      illegal_bins exokay = {1};
    }

    //----------------------------------------------------------
    // ID SPACE
    //----------------------------------------------------------
    cp_id : coverpoint t.id {
      bins low_ids[]  = {[0:15]};
      bins mid_ids[]  = {[16:127]};
      bins high_ids[] = {[128:255]};
    }

    //----------------------------------------------------------
    // ADDRESS ALIGNMENT TO 128-BYTE BOUNDARY
    //----------------------------------------------------------
    cp_addr_align : coverpoint t.addr[6:0] {
      bins aligned     = {0};
      illegal_bins unaligned[] = {[1:127]};
    }

    //----------------------------------------------------------
    // WSTRB
    // Current design supports only all bytes valid
    //----------------------------------------------------------
    cp_wstrb : coverpoint t.strb[0]
               iff (t.axn_type == WRITE && t.strb.size() > 0) {
      bins full_valid = {'1};
      illegal_bins partial = default;
    }

    //----------------------------------------------------------
    // USEFUL CROSSES
    //----------------------------------------------------------
    cross cp_type, cp_burst;
    cross cp_type, cp_len;
    cross cp_type, cp_size;
    cross cp_type, cp_resp;
    cross cp_burst, cp_len;
    cross cp_addr_align, cp_burst;
    cross cp_type, cp_addr_align;

  endgroup

  function new(string name="axi_cov", uvm_component parent=null);
    super.new(name,parent);
    cg_axi = new();
  endfunction

  function void write(axi4_seq_item t);
    cg_axi.sample(t);
  endfunction

endclass

