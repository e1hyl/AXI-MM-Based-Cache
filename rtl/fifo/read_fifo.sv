`timescale 1ns / 1ps

module read_fifo #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer ID_WIDTH   = 4,
    parameter integer DEPTH      = 8,
    localparam integer WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8,
    localparam integer PTR_W = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic [ID_WIDTH-1:0]   arid,
    input  logic [1:0]            arburst,
    input  logic [2:0]            arsize,
    input  logic [7:0]            arlen,
    input  logic                  push_arvalid,
    output logic                  push_arready,

    output logic                  pop_arvalid,
    input  logic                  pop_arready,
    output logic [WIDTH-1:0]      pop_data
);

    logic [WIDTH-1:0]      mem [0:DEPTH-1];
    logic [PTR_W:0]        wr_ptr, rd_ptr, count;

    logic [WIDTH-1:0] push_data;
    assign push_data = {araddr, arid, arburst, arsize, arlen};

    assign full         = (count == DEPTH[PTR_W:0]);
    assign empty        = (count == '0);
    assign pop_arvalid  = !empty;
    assign push_arready = !full;
    assign pop_data     = empty ? '0 : mem[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (push_arvalid && push_arready) begin
                mem[wr_ptr] <= push_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end
            if (pop_arvalid && pop_arready)
                rd_ptr <= rd_ptr + 1'b1;
            case ({push_arvalid && push_arready, pop_arvalid && pop_arready})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;
            endcase
        end
    end

endmodule
