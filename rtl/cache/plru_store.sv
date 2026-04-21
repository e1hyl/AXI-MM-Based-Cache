module plru_state_store (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [6:0] index,
    input  logic       update_en,
    input  logic [1:0] accessed_way,
    output logic [1:0] victim_way
);

    logic [2:0] plru_bits [128];

    wire [2:0] cur_plru = plru_bits[index];

    always_comb begin
        if (cur_plru[0] == 0)
            victim_way = (cur_plru[1] == 0) ? 2'd1 : 2'd0;
        else
            victim_way = (cur_plru[2] == 0) ? 2'd3 : 2'd2;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 128; i++)
                plru_bits[i] <= 3'b000;
        end else if (update_en) begin
            case (accessed_way)
                2'd0: plru_bits[index] <= {cur_plru[2], 1'b1, 1'b1};
                2'd1: plru_bits[index] <= {cur_plru[2], 1'b0, 1'b1};
                2'd2: plru_bits[index] <= {1'b1, cur_plru[1], 1'b0};
                2'd3: plru_bits[index] <= {1'b0, cur_plru[1], 1'b0};
                default: ;
            endcase
        end
    end

endmodule
