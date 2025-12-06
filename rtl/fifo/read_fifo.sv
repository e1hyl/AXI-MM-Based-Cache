module read_fifo(
    parameter integer ADDR_WIDTH = 64,
    parameter integer ID_WIDTH = 4,
    parameter integer DEPTH = 8,
    localparam integer WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8
)(
    input logic clk,
    input logic rst_n,

    // input interface
    input logic [ADDR_WIDTH-1:0] araddr,
    input logic [ID_WIDTH-1:0] arid,
    input logic [1:0] arburst,
    input logic [2:0] arsize,
    input logic [7:0] arlen,

    input logic push_arvalid,
    output logic push_arready,

    // output interface
    input logic pop_arvalid,
    output logic pop_arready,
    output logic [WIDTH-1:0] pop_data,
    
    output logic full,
    output logic empty    

);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH+1)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH+1)-1:0] count; 
     
    logic [WIDTH-1:0] push_data = {araddr, arid, arburst, arsize, arlen};

    assign full = (count == DEPTH);
    assign empty = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
       if(!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
       end else begin 

        if(push_arvalid && push_arready) begin
            mem[wr_ptr] <= push_data;
            wr_ptr <= wr_ptr + 1;
        end

        if(pop_arvalid && pop_arready) begin
            pop_data <= mem[rd_ptr];
            rd_ptr <= (rd_ptr + 1) % DEPTH;
        end
    
        case ({push_arvalid && push_arready, pop_arvalid && pop_arready})
            2'b10: count <= count + 1; 
            2'b01: count <= count - 1; 
            default: count <= count;   
        endcase
       
       end
    end



endmodule