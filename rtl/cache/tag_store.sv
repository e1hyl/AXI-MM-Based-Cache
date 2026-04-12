module tag_store (
    input  logic         clk,
    
    // Read Interface (from Decoder)
    input  logic [6:0]   index,        
    
    // Write Interface (from FSM/Controller)
    input  logic         write_en,     
    input  logic [6:0]   write_index,
    input  logic [1:0]   target_way,   
    input  logic [21:0]  new_tag,      
    
    // Output to Hit Detector
    output logic [21:0]  tags_out_0,   
    output logic [21:0]  tags_out_1,   
    output logic [21:0]  tags_out_2,   
    output logic [21:0]  tags_out_3    
);

    // Internal storage: 128 sets x 4 ways x 22-bit tags
    logic [21:0] tag_array [128][4];

    // Synchronous Write Logic
    always_ff @(posedge clk) begin
        if (write_en) begin
            tag_array[write_index][target_way] <= new_tag;
        end
    end

    // Combinational Read (Parallel output for Hit Detection)
    always_comb begin
        tags_out_0 = tag_array[index][0];
        tags_out_1 = tag_array[index][1];
        tags_out_2 = tag_array[index][2];
        tags_out_3 = tag_array[index][3];
    end
endmodule
