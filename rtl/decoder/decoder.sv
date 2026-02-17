`timescale 1ns / 1ps

module decoder (
    input  logic read_or_write,   // 0=READ, 1 = WRITE
    input  logic [127:0]  result_arb,

    output logic [31:0]  addr,
    output logic [3:0]   id,
    output logic [1:0]   burst,
    output logic [2:0]   size,
    output logic [7:0]   len,

    output logic [63:0]  wdata,
    output logic [7:0]   wstrb,

    output logic [21:0]  tag,
    output logic [6:0]   index,
    output logic [2:0]   offset
);
always_comb begin

    addr=32'b0;
    id=4'b0;
    burst=2'b0;
    size=3'b0;
    len=8'b0;
    wdata=64'b0;
    wstrb=8'b0;


    if (read_or_write) begin
        addr=result_arb[120:89];
        id=result_arb[88:85];
        burst=result_arb[84:83];
        size=result_arb[82:80];
        len=result_arb[79:72];
        wdata=result_arb[71:8];
        wstrb=result_arb[7:0];
    end
    else
    begin 
        addr=result_arb[48:17];
        id=result_arb[16:13];
        burst=result_arb[12:11];
        size=result_arb[10:8];
        len=result_arb[7:0];
    end

end

always_comb begin
    offset= addr[2:0];    // 8-byte block
    index=addr[9:3];    // 128 sets
    tag=addr[31:10];  // remaining bits
end


endmodule