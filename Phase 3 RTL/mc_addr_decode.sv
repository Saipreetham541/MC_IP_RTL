module mc_addr_decode (
    input  logic [39:0] addr,

    output logic [3:0]  ch_sel,
    output logic        pc_sel,
    output logic [13:0] row_addr,
    output logic [1:0]  bank_group,
    output logic [1:0]  bank_addr,
    output logic [4:0]  col_addr,
    output logic [4:0]  byte_offset
    );
 
    assign byte_offset = addr[4:0]; //position of the byte within the block.
    assign col_addr    = addr[9:5];
    assign bank_addr   = addr[11:10];
    assign bank_group  = addr[13:12];
    assign row_addr    = addr[27:14];
    assign pc_sel      = addr[28];
    assign ch_sel      = addr[32:29];
    endmodule
