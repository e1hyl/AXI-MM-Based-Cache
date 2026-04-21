module data_store #(
    parameter int SET_INDEX = 128,
    parameter int SET_WAY   = 4,
    parameter int DATA_W    = 64
)(
    input  logic clk,

    input  logic [6:0]        rd_index,
    input  logic [1:0]        rd_way,
    output logic [DATA_W-1:0] rd_data,

    input  logic              cpu_wr_en,
    input  logic [6:0]        cpu_wr_index,
    input  logic [1:0]        cpu_wr_way,
    input  logic [DATA_W-1:0] cpu_wr_data,

    input  logic              fill_wr_en,
    input  logic [6:0]        fill_wr_index,
    input  logic [1:0]        fill_wr_way,
    input  logic [DATA_W-1:0] fill_wr_data
);

    logic [DATA_W-1:0] data_array [SET_INDEX-1:0][SET_WAY-1:0];

    always_ff @(posedge clk) begin
        if (cpu_wr_en)
            data_array[cpu_wr_index][cpu_wr_way] <= cpu_wr_data;
        if (fill_wr_en)
            data_array[fill_wr_index][fill_wr_way] <= fill_wr_data;
    end

    assign rd_data = data_array[rd_index][rd_way];

endmodule
