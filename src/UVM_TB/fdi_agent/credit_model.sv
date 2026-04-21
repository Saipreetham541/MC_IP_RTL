class fdi_credit_manager extends uvm_component;

  `uvm_component_utils(fdi_credit_manager)

  int tx_credit[2];

  function void add_credit(int vcn, int cnt);
    tx_credit[vcn]+=cnt;
  endfunction

  function bit has_credit(int vcn);
    return (tx_credit[vcn] > 0);
  endfunction

  function void consume_credit(int vcn);
    tx_credit[vcn]--;
  endfunction

endclass