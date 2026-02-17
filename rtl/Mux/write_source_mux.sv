module write_source_mux(
    input  logic [63:0] drWDATA,  //data from driver
    input  logic [63:0] mRDATA, //data from memory
    input  logic dSel,

    output logic [63:0] writeData
);

assign writeData = (dSel) ? mRDATA : drWDATA;  //0->driver, 1->memory

endmodule