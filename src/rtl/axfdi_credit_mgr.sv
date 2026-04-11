module axfdi_credit_mgr #(
                          parameter credit_cnt = 3
)(
  input logic fdi_clk,
  input logic fdi_rst_n,
  input logic por_n,

  input logic [1:0] depktr_crdtmgr_credit_vcn,
  input logic [5:0] depktr_crdtmgr_credit_cnt,
  input logic       depktr_crdtmgr_valid,
);


endmodule
