`timescale 1ns / 1ps

module rr_arbiter #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 64,
    parameter integer ID_WIDTH   = 4,
    parameter integer DEPTH      = 8,
    localparam integer W_WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8
                               + DATA_WIDTH + DATA_WIDTH/8,
    localparam integer R_WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8
)(
    input  logic clk,
    input  logic rst,

    input  logic [R_WIDTH-1:0] rdata,
    input  logic [W_WIDTH-1:0] wdata,
    input  logic               r_valid,
    input  logic               w_valid,
    input  logic               out_ready,

    output logic [W_WIDTH-1:0] out_data,
    output logic               out_valid,
    output logic               read_or_write,
    output logic               r_ready,
    output logic               w_ready
);

    logic last_served, grant;

    logic eff_last;
    always_comb
        eff_last = (out_valid && out_ready) ? read_or_write : last_served;

    always_comb begin
        if      (r_valid && !w_valid) grant = 1'b0;
        else if (!r_valid && w_valid) grant = 1'b1;
        else                          grant = ~eff_last;
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            out_data      <= '0;
            out_valid     <= 1'b0;
            read_or_write <= 1'b0;
            r_ready       <= 1'b0;
            w_ready       <= 1'b0;
        end else begin
            r_ready <= 1'b0;
            w_ready <= 1'b0;

            if (!out_valid || out_ready) begin
                if (grant == 1'b0) begin
                    out_data      <= {{(W_WIDTH-R_WIDTH){1'b0}}, rdata};
                    out_valid     <= r_valid && !r_ready;
                    read_or_write <= 1'b0;
                    r_ready       <= r_valid && !r_ready;
                end else begin
                    out_data      <= wdata;
                    out_valid     <= w_valid && !w_ready;
                    read_or_write <= 1'b1;
                    w_ready       <= w_valid && !w_ready;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            last_served <= 1'b0;
        else if (out_valid && out_ready)
            last_served <= grant;
    end

endmodule
