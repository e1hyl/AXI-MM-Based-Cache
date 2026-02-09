`timescale 1ns / 1ps

module axi_merger
#(
   parameter integer ADDR_WIDTH  = 32,
   parameter integer DATA_WIDTH  = 64,
   parameter integer ID_WIDTH    = 4
)
(
   input clk, rst_n,

   // input interface (unsynchronized)
   input logic [ADDR_WIDTH-1:0] in_awaddr,
   input logic [ID_WIDTH-1:0] in_awid,
   input logic [1:0] in_awburst,
   input logic [2:0] in_awsize,
   input logic [7:0] in_awlen,
   input logic in_awvalid,
   output logic in_awready,

   input logic [DATA_WIDTH-1:0] in_wdata,
   input logic [DATA_WIDTH/8-1:0] in_wstrb,
   input logic in_wlast, 
   input logic in_wvalid,
   output logic in_wready,

   // output interface (synchronized)

   output logic [ADDR_WIDTH-1:0] out_awaddr,
   output logic [ID_WIDTH-1:0] out_awid,
   output logic [1:0] out_awburst,
   output logic [2:0] out_awsize,
   output logic [7:0] out_awlen,
   output logic out_awvalid,
   input logic out_awready,

   output logic [DATA_WIDTH-1:0] out_wdata,
   output logic [DATA_WIDTH/8-1:0] out_wstrb,
   output logic out_wlast, 
   output logic out_wvalid,
   input logic out_wready

);

   logic pending_data; // flag for pending data

   // registers for capturing aw 
   logic [DATA_WIDTH-1:0] c_awaddr;
   logic [ID_WIDTH-1:0] c_awid;
   logic [1:0] c_awburst;
   logic [2:0] c_awsize;
   logic [7:0] c_awlen;
   logic c_awready;

   // registers for capturing w 
   logic [DATA_WIDTH-1:0] c_wdata;
   logic [DATA_WIDTH/8-1:0] c_wstrb;
   logic c_wvalid;

   assign in_awready = !pending_data;
   assign in_wready = ((in_awvalid && in_awready) || pending_data);
   assign out_awvalid = in_wvalid;
   assign out_wvalid = in_wvalid;

   always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n)
         pending_data <= 1'b0; 
      else begin
         if((in_awvalid && in_awready) && !in_wvalid) 
            pending_data <= 1'b1;     
         else if(pending_data & wvalid)
            pending_data <= 1'b0;
         else
            pending_data <= pending_data; 
      end
   end


   always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
         c_awid <= '0;
         c_awaddr <= '0;
         c_awburst <= '0;
         c_awsize <= '0;
         c_awlen <= '0; 
      end else begin
      if(pending_data && in_awvalid) begin
         c_awid <= in_awid;
         c_awaddr <= in_awaddr;
         c_awburst <= in_awburst;
         c_awsize <= in_awsize;
         c_awlen <= in_awlen; 
      end
      else begin
         c_awid <= c_awid;
         c_awaddr <= c_awaddr;
         c_awburst <= c_awburst;
         c_awsize <= c_awsize;
         c_awlen <= c_awlen; 
      end
   end
   end

   assign out_awid = c_awid;
   assign out_awaddr = c_awid;
   assign out_awburst = c_awburst;
   assign out_awsize = c_awsize;
   assign out_awlen = c_awlen;
   
   assign out_wdata = in_wdata;
   assign out_wstrb = in_wstrb;
   assign out_wlast = in_wlast; 

endmodule