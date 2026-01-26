`timescale 1ns / 1ps

module rr_arbiter #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 64,
    parameter integer ID_WIDTH = 4, 
    parameter integer DEPTH = 8,
    localparam integer W_WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8 +  DATA_WIDTH + DATA_WIDTH/8,  
    localparam integer R_WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8
)(
    input logic clk, rst,
    input logic [R_WIDTH-1:0] rdata,
    input logic [W_WIDTH-1:0] wdata,
    input logic r_valid, w_valid,
    input logic out_ready,

    output logic [W_WIDTH-1:0] out_data,
    output logic out_valid,
    output logic read_or_write,
    output logic w_ready, r_ready 
);

    logic last_served, grant;

    always_comb begin
        if(r_valid && !w_valid)
            grant = 0;
        else if(!r_valid && w_valid)
            grant = 1;
        else 
            grant = ~last_served; 
    end
    
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            out_data<=0;
            out_valid<=0;
            read_or_write<=0;   // 0 for read
            r_ready<=0;
            w_ready<=0;
        end
        else if (grant==0) begin  
            out_data<={{(W_WIDTH-R_WIDTH){1'b0}}, rdata};
            out_valid<=r_valid;
            read_or_write<=0;   // 0 for read
            r_ready<=r_valid && out_ready;
            w_ready<=0;
        end
        else begin
            out_data<=wdata;
            out_valid<=w_valid;
            read_or_write<=1;   // 1 for write
            r_ready<=0;
            w_ready<=w_valid && out_ready;         
                    
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if(!rst)
            last_served<= 1'b0;   //assume its read
        else if( out_valid && out_ready)
                last_served<=grant;   //The arbiter must wait until out_ready = 1 before it can actually send data
    end
        
endmodule
