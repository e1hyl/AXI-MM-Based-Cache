`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/27/2026 06:40:36 AM
// Design Name: 
// Module Name: tagstore
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tagstore(

    input  logic         clk,
    input  logic         rst_n,
    
   
    input  logic [6:0]   index,        // 7 bits for 128 sets
    
    // Write Interface (from FSM/Memory Fill)
    input  logic         write_en,     // targetWayEn in your diagram
    input  logic [6:0]   write_index,
    input  logic [1:0]   target_way,   // 2 bits for 4 ways
    input  logic [18:0]  new_tag,      // 19-bit tag
    
    // Output to Hit Detector
    output logic [18:0]  tags_out_0,   
    output logic [18:0]  tags_out_1,   
    output logic [18:0]  tags_out_2,   
    output logic [18:0]  tags_out_3    
);

    // Internal storage: 128 sets, each with 4 ways of 19-bit tags
    logic [18:0] tag_array [128][4];

    // Synchronous Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 128; i++) begin
                for (int j = 0; j < 4; j++) begin
                    tag_array[i][j] <= 19'b0;
                end
            end
        end else if (write_en) begin
            tag_array[write_index][target_way] <= new_tag;
        end
    end

    // Combinational Read Logic
    // This feeds the Hit Detector in the same cycle as the index arrives
    always_comb begin
        tags_out_0 = tag_array[index][0];
        tags_out_1 = tag_array[index][1];
        tags_out_2 = tag_array[index][2];
        tags_out_3 = tag_array[index][3];
    end

endmodule


