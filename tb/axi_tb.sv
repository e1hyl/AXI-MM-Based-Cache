'timescale 1ns / 1ps

module axi_tb(
    parameter integer AXI_ADDR_WIDTH  = 32,
    parameter integer AXI_DATA_WIDTH  = 64,
    parameter integer AXI_ID_WIDTH    = 4
);


//inputs

    logic clk, rst_n;
    
    logic                          TB_AXI_AWREADY;
    logic                          TB_AXI_WREADY;
    
    logic [1:0]                    TB_AXI_BRESP;
    logic                          TB_AXI_BVALID;
    logic [AXI_ID_WIDTH-1:0]       TB_AXI_BID;
    
    logic                          TB_AXI_ARREADY;

    logic [AXI_DATA_WIDTH-1:0]     TB_AXI_RDATA;
    logic                          TB_AXI_RVALID;
    logic [AXI_ID_WIDTH-1:0]       TB_AXI_RID;
    logic                          TB_AXI_RLAST;

//outputs

    logic [AXI_ADDR_WIDTH-1:0]     TB_AXI_AWADDR;
    logic                          TB_AXI_AWVALID;
    logic [AXI_ID_WIDTH-1:0]       TB_AXI_AWID;
    logic [1:0]                    TB_AXI_AWBURST;
    logic [2:0]                    TB_AXI_AWSIZE;
    logic [7:0]                    TB_AXI_AWLEN;

    logic [AXI_DATA_WIDTH-1:0]     TB_AXI_WDATA;
    logic [AXI_DATA_WIDTH/8-1:0]   TB_AXI_WSTRB;
    logic                          TB_AXI_WVALID;
    logic                          TB_AXI_WLAST;

    logic                          TB_AXI_BREADY;

    logic [AXI_ADDR_WIDTH-1:0]     TB_AXI_ARADDR;
    logic                          TB_AXI_ARVALID;
    logic [AXI_ID_WIDTH-1:0]       TB_AXI_ARID;
    logic [1:0]                    TB_AXI_ARBURST;
    logic [2:0]                    TB_AXI_ARSIZE;
    logic [7:0]                    TB_AXI_ARLEN;

    logic [AXI_ADDR_WIDTH-1:0]     TB_AXI_ARADDR;
    logic                          TB_AXI_ARVALID;
    logic [AXI_ID_WIDTH-1:0]       TB_AXI_ARID;
    logic [1:0]                    TB_AXI_ARBURST;
    logic [2:0]                    TB_AXI_ARSIZE;
    logic [7:0]                    TB_AXI_ARLEN;

   // counters 
    logic [9:0] aw_addr_count, w_data_count, ar_addr_count;
    logic [9:0] aw_id_count, ar_id_count;

    top dut(
        .clk(clk),
        .rst_n(rst_n),

        .M_AXI_AWADDR(TB_AXI_AWADDR),
        .M_AXI_AWVALID(TB_AXI_AWVALID),
        .M_AXI_AWID(TB_AXI_AWID),
        .M_AXI_AWBURST(TB_AXI_AWBURST),
        .M_AXI_AWSIZE(TB_AXI_AWSIZE),
        .M_AXI_AWLEN(TB_AXI_AWLEN),

        .M_AXI_WDATA(TB_AXI_WDATA),
        .M_AXI_WSTRB(TB_AXI_WSTRB),
        .M_AXI_WVALID(TB_AXI_WVALID),
        .M_AXI_WLAST(TB_AXI_WLAST),

        .M_AXI_BREADY(TB_AXI_BREADY),

        .M_AXI_ARADDR(TB_AXI_ARADDR),
        .M_AXI_ARVALID(TB_AXI_ARVALID),
        .M_AXI_ARID(TB_AXI_ARID),
        .M_AXI_ARBURST(TB_AXI_ARBURST),
        .M_AXI_ARSIZE(TB_AXI_ARSIZE),
        .M_AXI_ARLEN(TB_AXI_ARLEN),

        .M_AXI_RREADY(TB_AXI_RREADY)
    ); 

    typedef enum logic [2:0] {
        IDLE, 
        SEND_AW, 
        SEND_W, 
        SEND_AR, 
    } my_state;

    my_state state, next_state;

    initial begin
        state = IDLE;
        next_state = IDLE;
        aw_addr_count = 0;
        w_data_count = 0;
        ar_addr_count = 0;
        aw_id_count = 0;
        ar_id_count = 0;
    end
    
    always #(5ns) clk = ~clk;    

    localparam [2:0] SIZE_8B    = 3'd3; 
    localparam [1:0] BURST_INCR = 2'b01;

    initial begin
        rst_n = 0;

        #10 rst_n = 1;
    end

   always_ff @(posedge clk or negedge rst_n) begin
        
        case(state)
            IDLE: begin
                next_state = SEND_AW; 
            end

            SEND_AW: begin
                if(TB_AXI_AWADDR < 8'h7FFFFFFF) begin
                    TB_AXI_AWADDR <= 8'h00000000 + aw_addr_count;
                    TB_AXI_AWVALID <= 1'b1;
                    TB_AXI_AWID <= 0 + aw_id_count;
                    TB_AXI_AWSIZE <= SIZE_8B;
                    TB_AXI_AWBURST <= BURST_INC;
                    TB_AXI_AWLEN <= 8'd0;
                    aw_addr_count <= aw_addr_count + 4; 
                end
                else 
                    next_state = SEND_AR;
                next_state = SEND_W;
            end

            SEND_W: begin
                TB_AXI_WDATA <= 16'h0000000000000000 + w_data_count;
                TB_AXI_WSTRB <= 8'b11111111;
                TB_AXI_WVALID <= 1'b1;
                TB_AXI_WLAST <= 1'b1;
                w_data_count <= w_data_count + 4; 
                next_state = SEND_AR;
            end

            SEND_AR: begin
                if (TB_AXI_ARADDR < 8'hFFFFFFFF) begin
                    TB_AXI_ARADDR <= 8'h80000000 + ar_addr_count;
                    TB_AXI_ARVALID <= 1'b1;
                    TB_AXI_ARID <= 0 + ar_id_count;  
                    TB_AXI_ARSIZE <= SIZE_8B;
                    TB_AXI_ARBURST <= BURST_INC;
                    TB_AXI_ARLEN <= 8'd0;
                    ar_addr_count <= ar_addr_count + 4; 
                end
                else
                    next_state = IDLE;
                next_state = WAIT_RESP;
            end
        endcase 

            state <= next_state;
   end

endmodule