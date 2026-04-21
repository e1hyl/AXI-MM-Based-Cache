module status_bits_store #(
    parameter int SET_INDEX = 128,
    parameter int SET_WAY   = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [6:0]  rd_index,
    output logic [1:0]  way_0_status,
    output logic [1:0]  way_1_status,
    output logic [1:0]  way_2_status,
    output logic [1:0]  way_3_status,

    input  logic        wr_en,
    input  logic [6:0]  wr_index,
    input  logic [1:0]  wr_way,
    input  logic [1:0]  new_status
);

    localparam logic [1:0] INVALID = 2'b00;

    logic [1:0] status_array [SET_INDEX-1:0][SET_WAY-1:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < SET_INDEX; i++)
                for (int j = 0; j < SET_WAY; j++)
                    status_array[i][j] <= INVALID;
        end else if (wr_en) begin
            status_array[wr_index][wr_way] <= new_status;
        end
    end

    always_comb begin
        way_0_status = status_array[rd_index][0];
        way_1_status = status_array[rd_index][1];
        way_2_status = status_array[rd_index][2];
        way_3_status = status_array[rd_index][3];
    end

endmodule
