//==============================================================
// FDI COVERAGE COLLECTOR
// Samples FDI packet traffic from FDI monitor
//==============================================================
class fdi_cov extends uvm_subscriber #(fdi_pkt_item);

  `uvm_component_utils(fdi_cov)

  covergroup cg_fdi with function sample(fdi_pkt_item t);

    option.per_instance = 1;
    option.name = "cg_fdi";

    //----------------------------------------------------------
    // OPCODE
    //----------------------------------------------------------
    cp_opcode : coverpoint t.opcode {
      bins write_req  = {WRITE_REQ};
      bins read_req   = {READ_REQ};
      bins write_resp = {WRITE_RESP};
      bins read_resp  = {READ_RESP};
      bins credit_rtn = {CREDIT_RTN};
      illegal_bins = default;
    }

    //----------------------------------------------------------
    // PORT ROUTING
    //----------------------------------------------------------
    cp_port : coverpoint t.port_id {
      bins port0 = {0};
      bins port1 = {1};
    }

    //----------------------------------------------------------
    // VCN (Virtual Channel Number)
    //----------------------------------------------------------
    cp_vcn : coverpoint t.vcn {
      bins vcn0         = {0};
      bins vcn1         = {1};
      illegal_bins vcn2 = {2};
      illegal_bins vcn3 = {3};
      illegal_bins Reserved [] = {[4:7]};
    }

    //----------------------------------------------------------
    // TRANSACTION ID
    //----------------------------------------------------------
    cp_txn_id : coverpoint t.txn_id {
      bins low_ids[]  = {[0:15]};
      bins mid_ids[]  = {[16:127]};
      bins high_ids[] = {[128:255]};
    }

    //----------------------------------------------------------
    // BURST LENGTH
    // beats = burst_len + 1
    //----------------------------------------------------------
    cp_len : coverpoint t.burst_len
             iff (t.opcode inside {WRITE_REQ, READ_REQ}) {

      bins single           = {0};
      illegal_bins burst4   = {3};
      illegal_bins burst8   = {7};
      illegal_bins burst16  = {15};
      illegal_bins burst32  = {31};
      illegal_bins burst64  = {63};
      illegal_bins burst128 = {127};
      illegal_bins burst256 = {255};
      illegal_bins others[] = {[1:254]};
    }

    //----------------------------------------------------------
    // BURST TYPE
    //----------------------------------------------------------
    cp_burst : coverpoint t.burst_type
               iff (t.opcode inside {WRITE_REQ, READ_REQ}) {

      bins fixed = {0};
      bins incr  = {1};
      bins wrap  = {2};
      illegal_bins reserved = {3};
    }

    //----------------------------------------------------------
    // BURST SIZE
    //----------------------------------------------------------
    cp_size : coverpoint t.burst_size
              iff (t.opcode inside {WRITE_REQ, READ_REQ}) {

      illegal_bins b1   = {0};
      illegal_bins b2   = {1};
      illegal_bins b4   = {2};
      illegal_bins b8   = {3};
      illegal_bins b16  = {4};
      illegal_bins b32  = {5};
      illegal_bins b64  = {6};
      bins b128 = {7};
    }

    //----------------------------------------------------------
    // RESPONSE
    //----------------------------------------------------------
    cp_resp : coverpoint t.resp
              iff (t.opcode inside {WRITE_RESP, READ_RESP}) {

      bins okay   = {0};
      bins slverr = {2};
      bins decerr = {3};
      illegal_bins exokay = {1};
    }

    //----------------------------------------------------------
    // ADDRESS ALIGNMENT (128-byte boundary)
    //----------------------------------------------------------
    cp_addr_align : coverpoint t.addr[6:0]
                    iff (t.opcode inside {WRITE_REQ, READ_REQ}) {

      bins aligned     = {0};
      illegal_bins unaligned[] = {[1:127]};
    }

    //----------------------------------------------------------
    // PAYLOAD SIZE (byte array)
    //----------------------------------------------------------
    cp_payload_bytes : coverpoint t.data.size()
                       iff (t.opcode inside {WRITE_REQ, READ_RESP}) {

      bins empty      = {0};
      bins full_beat  = {128};
      bins others[]   = {[1:127]};
    }

    //----------------------------------------------------------
    // WSTRB
    // Current design uses all bytes valid only
    //----------------------------------------------------------
    cp_wstrb : coverpoint t.wstrb[0]
               iff (t.opcode == WRITE_REQ && t.wstrb.size() > 0) {

      bins full_valid = {'1};
      illegal_bins partial = default;
    }

    //----------------------------------------------------------
    // CREDIT RETURN COUNT
    //----------------------------------------------------------
    cp_credit_cnt : coverpoint t.credit_rtn_cnt
                    iff (t.opcode == CREDIT_RTN) {

      bins credit_rtn  = {16};
      bins credit_init = {32};
      bins zero        = {0};
    }

    //----------------------------------------------------------
    // CREDIT RETURN VCN
    //----------------------------------------------------------
    cp_credit_vcn : coverpoint t.credit_rtn_vcn
    iff (t.opcode == CREDIT_RTN) {

      bins np_vcn  = {0};
      bins cpl_vcn = {1};
      illegal_bins others[] = {[2:3]};
    }

    //----------------------------------------------------------
    // USEFUL CROSS COVERAGE
    //----------------------------------------------------------
    cross cp_opcode, cp_port;
    cross cp_opcode, cp_vcn;
    cross cp_opcode, cp_len;
    cross cp_opcode, cp_burst;
    cross cp_port, cp_vcn;
    cross cp_opcode, cp_resp;
    cross cp_opcode, cp_addr_align;
    cross cp_opcode, cp_payload_bytes;

  endgroup

  function new(string name="fdi_cov", uvm_component parent=null);
    super.new(name,parent);
    cg_fdi = new();
  endfunction

  function void write(fdi_pkt_item t);
    cg_fdi.sample(t);
  endfunction

endclass

