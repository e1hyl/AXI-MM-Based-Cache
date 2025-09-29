module axi_merger
#(
   parameter integer AXI_ADDR_WIDTH  = 32,
   parameter integer AXI_DATA_WIDTH  = 64,
   parameter integer AXI_ID_WIDTH    = 4
)
(
   input clk, rst_n,

   input  logic [AXI_DATA_WIDTH-1:0]     dr_wdata,
   input  logic [AXI_DATA_WIDTH/8-1:0]   dr_wstrb,
   input  logic                          dr_wvalid,
   input  logic                          dr_wlast,
   output logic                          dr_wready,

   output logic [AXI_DATA_WIDTH-1:0]     mr_wdata,
   output logic [AXI_DATA_WIDTH/8-1:0]   mr_wstrb,
   output logic                          mr_wvalid,
   output logic                          mr_wlast,
   input  logic                          mr_wready       
);

   logic                        stored_wvalid;
   logic [AXI_DATA_WIDTH-1:0]   stored_wdata;
   logic [AXI_DATA_WIDTH/8-1:0] stored_wstrb;
   logic                        stored_wlast;     


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stored_wvalid <= 1'b0;
            stored_wdata  <= '0;
            stored_wstrb  <= '0;
            stored_wlast  <= 1'b0;

            mr_wvalid   <= 1'b0;
            mr_wdata    <= '0;
            mr_wstrb    <= '0;
            mr_wlast    <= 1'b0;

            in_wready    <= 1'b1; 
        end else begin
            if (dr_wvalid && dr_wready) begin
                stored_wdata  <= dr_wdata;
                stored_wstrb  <= dr_wstrb;
                stored_wlast  <= dr_wlast;
                stored_wvalid <= 1'b1;
                dr_wready    <= 1'b0;
            end
 
            if (stored_wvalid && !mr_wvalid) begin
                mr_wdata  <= stored_wdata;
                nr_wstrb  <= stored_wstrb;
                mr_wlast  <= stored_wlast;
                mr_wvalid <= 1'b1;
            end
 
            if (mr_wvalid && mr_wready) begin
                mr_wvalid   <= 1'b0;
                stored_wvalid <= 1'b0;
                dr_wready    <= 1'b1;
            end

        end
    end
   

endmodule