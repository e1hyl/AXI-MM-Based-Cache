module axi_merger
#(
   parameter integer AXI_ADDR_WIDTH  = 32,
   parameter integer AXI_DATA_WIDTH  = 64,
   parameter integer AXI_ID_WIDTH    = 4
)
(
   input clk, rst_n,

   input logic awvalid,
   input logic [AXI_ADDR_WIDTH-1:0] awaddr,
   input logic [AXI_ID_WIDTH-1:0] awid,
   input logic [1:0] awburst,
   input logic [2:0] awsize,
   input logic [7:0] awlen,
   input logic awready,
   output logic awready,


   input logic [AXI_DATA_WIDTH-1:0] wdata,
   input logic [AXI_DATA_WIDTH/8-1:0] wstrb,
   input logic wvalid,
   output logic wready,

   input logic bready,
   output logic bresp,
   output logic bvalid,
   output logic bid,
);

   logic pending_data; // flag for pending data

   logic c_awvalid;
   logic [AXI_ID_WIDTH-1:0] c_awid;
   logic [1:0] c_awburst;
   logic [2:0] c_awsize;
   logic [7:0] c_awlen;
   logic c_awready;

   logic [AXI_DATA_WIDTH-1:0] c_wdata;
   logic [AXI_DATA_WIDTH/8-1:0] c_wstrb;
   logic c_wvalid;


   assign awready = !pending_data;
   assign wready = ((awvalid & awready) || pending_data);
  // assign pending_data = (pending_data & wvalid & wready)?1'b0:pending_data;

   always_ff (posedge clk or negedge rst_n) begin
      if(!rst_n)
         pending_data <= 1'b0; 
      else begin
         if((awvalid & awready) && !wvalid) 
            pending_data <= 1'b1;     
         else if(pending_data & wvalid & wready)
            pending_data <= 1'b0;
         else
            pending_data <= 1'b0; 
      end
   end
   
   always_ff (posedge clk or negedge rst_n) begin
      if(!rst_n) begin

      end
      else begin
         if(pending_data && awvalid) begin
            c_awvalid <= awvalid;
            c_awid <= awid;
            c_awaddr <= awaddr;
            c_awburst <= awburst;
            c_awsize <= awsize;
            c_awlen <= awlen; 
         end

         if(wvalid) begin
            
         end


      end
   end


endmodule