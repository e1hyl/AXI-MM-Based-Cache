module hit_detector (
    input  logic [21:0] incoming_tag,
    
    // Inputs from Tag Store
    input  logic [21:0] tags_out_0,
    input  logic [21:0] tags_out_1,
    input  logic [21:0] tags_out_2,
    input  logic [21:0] tags_out_3,
    
    // Inputs from Status Store
    input  logic [1:0]  way_0_status,
    input  logic [1:0]  way_1_status,
    input  logic [1:0]  way_2_status,
    input  logic [1:0]  way_3_status,
    
    // Logic Outputs
    output logic        hit,
    output logic        pending_hit,
    output logic [1:0]  hit_way_index,
    output logic [1:0]  pending_way_index
);

    logic [3:0] valid_matches;
    logic [3:0] pending_matches;

    always_comb begin
        // Comparison for Valid (01)
        valid_matches[0] = (incoming_tag == tags_out_0) && (way_0_status == 2'b01);
        valid_matches[1] = (incoming_tag == tags_out_1) && (way_1_status == 2'b01);
        valid_matches[2] = (incoming_tag == tags_out_2) && (way_2_status == 2'b01);
        valid_matches[3] = (incoming_tag == tags_out_3) && (way_3_status == 2'b01);

        // Comparison for Pending (10)
        pending_matches[0] = (incoming_tag == tags_out_0) && (way_0_status == 2'b10);
        pending_matches[1] = (incoming_tag == tags_out_1) && (way_1_status == 2'b10);
        pending_matches[2] = (incoming_tag == tags_out_2) && (way_2_status == 2'b10);
        pending_matches[3] = (incoming_tag == tags_out_3) && (way_3_status == 2'b10);

        hit         = |valid_matches;
        pending_hit = |pending_matches;

        // Encode the hit way for Data Store Mux control
        casez (valid_matches)
            4'b???1: hit_way_index = 2'd0;
            4'b??10: hit_way_index = 2'd1;
            4'b?100: hit_way_index = 2'd2;
            4'b1000: hit_way_index = 2'd3;
            default: hit_way_index = 2'd0;
        endcase

        // Encode the pending way (for FSM MSHR dealloc on write-to-pending)
        casez (pending_matches)
            4'b???1: pending_way_index = 2'd0;
            4'b??10: pending_way_index = 2'd1;
            4'b?100: pending_way_index = 2'd2;
            4'b1000: pending_way_index = 2'd3;
            default: pending_way_index = 2'd0;
        endcase
    end
endmodule
