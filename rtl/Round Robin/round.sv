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
    
   always_ff @(posedge clk or negedge rst) begin
            if (!rst)
            begin
                out_data<=0;
                out_valid<=0;
                read_or_write<=0;   // 0 for read
                r_ready<=0;
                w_ready<=0;
            end
            else if (grant==0)   //read case
             begin  
               out_data<={{(w_width-r_width){1'b0}}, rdata};
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
   always_ff @(posedge clk or negedge rst)
   begin
        if(!rst)
            last_served<= 1'b0;   //assume its read
        else if( out_valid && out_ready)
               last_served<=grant;   //The arbiter must wait until out_ready = 1 before it can actually send data
            
   end
        
endmodule