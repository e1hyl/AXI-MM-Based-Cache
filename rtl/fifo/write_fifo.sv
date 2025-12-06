module write_fifo #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 64,
    parameter integer ID_WIDTH = 4, 
    parameter integer DEPTH = 8,
    localparam integer WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8 + 1 + DATA_WIDTH + DATA_WIDTH/8 + 1 + 1 
)(

    input logic clk,
    input logic rst_n

    // input interface 
    input logic [ADDR_WIDTH-1:0] awaddr,
    input logic [ID_WIDTH-1:0] awid,
    input logic [1:0] awburst,
    input logic [2:0] awsize,
    input logic [7:0] awlen,
    input logic awready,

    input logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH/8-1:0] wstrb,
    input logic wvalid,
    
    input logic push_awvalid,
    output logic push_awready,

    //output interface
    input logic pop_awvalid,
    output logic pop_awready,
    output logic [WIDTH-1:0] pop_data, 

    //status
    output logic full,
    output logic empty,
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH+1)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH+1)-1:0] count; 
     
    logic [WIDTH-1:0] push_data = {awaddr, awid, awburst, awsize, awlen, awready, wdata, wstrb, wvalid, awvalid};


    assign full = (count == DEPTH);
    assign empty = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
       if(!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
       end else begin 

        if(push_awvalid && push_awready) begin
            mem[wr_ptr] <= push_data;
            wr_ptr <= wr_ptr + 1;
        end

        if(pop_awvalid && pop_awready) begin
            pop_data <= mem[rd_ptr];
            rd_ptr <= (rd_ptr + 1) % DEPTH;
        end
    
        case ({push_awvalid && push_awready, pop_awvalid && pop_awready})
            2'b10: count <= count + 1; 
            2'b01: count <= count - 1; 
            default: count <= count;   
        endcase
       
       end
    end

endmodule