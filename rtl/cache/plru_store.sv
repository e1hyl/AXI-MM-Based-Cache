module plru_state_store (
    input  logic         clk,
    input  logic         rst_n,
    
    // Read Interface
    input  logic [6:0]   index,
    
    // Update Interface (Triggered on Hit or Fill)
    input  logic         update_en,     // plruUpdate in your diagram
    input  logic [1:0]   accessed_way,  // The way that was just used
    
    // Output to FSM
    output logic [1:0]   victim_way     // The way recommended for eviction
);

    // 128 sets x 3 bits per set
    logic [2:0] plru_bits [128];

    // --- Victim Selection (Combinational) ---
    // The FSM uses this during a miss to know which targetWay to pick.
    always_comb begin
        if (plru_bits[index][0] == 0) begin
            // Left side (0 or 1)
            victim_way = (plru_bits[index][1] == 0) ? 2'd1 : 2'd0;
        end else begin
            // Right side (2 or 3)
            victim_way = (plru_bits[index][2] == 0) ? 2'd3 : 2'd2;
        end
    end

    // --- State Update Logic (Synchronous) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 128; i++) begin
                plru_bits[i] <= 3'b000;
            end
        end else if (update_en) begin
            case (accessed_way)
                2'd0: begin 
                    plru_bits[index][0] <= 1'b1; // Point away from Left
                    plru_bits[index][1] <= 1'b1; // Point away from 0
                end
                2'd1: begin 
                    plru_bits[index][0] <= 1'b1; // Point away from Left
                    plru_bits[index][1] <= 1'b0; // Point away from 1
                end
                2'd2: begin 
                    plru_bits[index][0] <= 1'b0; // Point away from Right
                    plru_bits[index][2] <= 1'b1; // Point away from 2
                end
                2'd3: begin 
                    plru_bits[index][0] <= 1'b0; // Point away from Right
                    plru_bits[index][2] <= 1'b0; // Point away from 3
                end
            endcase
        end
    end

endmodule