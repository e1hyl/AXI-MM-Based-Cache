module byte_offset_mux(
    input  logic [63:0] selectedLine,
    input  logic [2:0]  offset,

    output logic [7:0]  caRDATA
);

always_comb begin
    case(offset)
        3'd0: caRDATA=selectedLine[7:0];
        3'd1: caRDATA=selectedLine[15:8];
        3'd2: caRDATA=selectedLine[23:16];
        3'd3: caRDATA=selectedLine[31:24];
        3'd4: caRDATA=selectedLine[39:32];
        3'd5: caRDATA=selectedLine[47:40];
        3'd6: caRDATA=selectedLine[55:48];
        3'd7: caRDATA=selectedLine[63:56];
    endcase
end

endmodule
