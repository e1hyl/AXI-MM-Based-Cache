`timescale 1ns / 1ps

parameter integer r_width =32;
parameter integer w_width =64;

module round(
        input logic clk, rst,
        input logic [r_width-1:0] rdata,
        input logic [w_width-1:0] wdata,
        input logic r_valid, w_valid,
        input logic out_ready,
        
        output logic [w_width-1:0] out_data,
        output logic out_valid,
        output logic read_or_write,
        output logic w_ready, r_ready
             
    );
    
    logic last_served; // read ya write
    logic grant;     //which to select
    
    always_comb begin
           if ( r_valid && !w_valid)
                grant=0;    //read select
           else if (!r_valid && w_valid)
                grant=1;    //write select
           else
                grant=~last_served;  //alternate, read to write and vice versa
            
    end
    

    
endmodule