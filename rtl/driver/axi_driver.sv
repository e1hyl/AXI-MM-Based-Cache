`timescale 1ns / 1ps

module axi_driver
  #(
   parameter integer AXI_ADDR_WIDTH  = 32,
   parameter integer AXI_DATA_WIDTH  = 64,
   parameter integer AXI_ID_WIDTH    = 4
   )
   (
 
   input logic                           clk,
   input logic                           rst_n,

   input  logic [AXI_ADDR_WIDTH-1:0]     TB_AXI_AWADDR,
   input  logic                          TB_AXI_AWVALID,
   input  logic [AXI_ID_WIDTH-1:0]       TB_AXI_AWID,
   input  logic [1:0]                    TB_AXI_AWBURST,
   input  logic [2:0]                    TB_AXI_AWSIZE,
   input  logic [7:0]                    TB_AXI_AWLEN,
   output logic                          TB_AXI_AWREADY,

   input  logic [AXI_DATA_WIDTH-1:0]     TB_AXI_WDATA,
   input  logic [AXI_DATA_WIDTH/8-1:0]   TB_AXI_WSTRB,
   input  logic                          TB_AXI_WVALID,
   input  logic                          TB_AXI_WLAST,
   output logic                          TB_AXI_WREADY,

   output logic [1:0]                    TB_AXI_BRESP,
   output logic                          TB_AXI_BVALID,
   output logic [AXI_ID_WIDTH-1:0]       TB_AXI_BID,
   input  logic                          TB_AXI_BREADY,

   input  logic [AXI_ADDR_WIDTH-1:0]     TB_AXI_ARADDR,
   input  logic                          TB_AXI_ARVALID,
   input  logic [AXI_ID_WIDTH-1:0]       TB_AXI_ARID,
   input  logic [1:0]                    TB_AXI_ARBURST,
   input  logic [2:0]                    TB_AXI_ARSIZE,
   input  logic [7:0]                    TB_AXI_ARLEN,
   output logic                          TB_AXI_ARREADY,

   output logic [AXI_DATA_WIDTH-1:0]     TB_AXI_RDATA,
   output logic                          TB_AXI_RVALID,
   output logic [AXI_ID_WIDTH-1:0]       TB_AXI_RID,
   output logic                          TB_AXI_RLAST,
   //input  logic                          TB_AXI_RREADY,

// ----

   // aw
   output logic [AXI_ADDR_WIDTH-1:0]     M_AXI_AWADDR,
   output logic                          M_AXI_AWVALID,
   output logic [AXI_ID_WIDTH-1:0]       M_AXI_AWID,
   output logic [1:0]                    M_AXI_AWBURST,
   output logic [2:0]                    M_AXI_AWSIZE,
   output logic [7:0]                    M_AXI_AWLEN,
   input  logic                          M_AXI_AWREADY,

   // w
   output logic [AXI_DATA_WIDTH-1:0]     M_AXI_WDATA,
   output logic [AXI_DATA_WIDTH/8-1:0]   M_AXI_WSTRB,
   output logic                          M_AXI_WVALID,
   output logic                          M_AXI_WLAST,
   input  logic                          M_AXI_WREADY,

   // b 
   input  logic [1:0]                    M_AXI_BRESP,
   input  logic                          M_AXI_BVALID,
   input  logic [AXI_ID_WIDTH-1:0]       M_AXI_BID,
   output logic                          M_AXI_BREADY,

   // ar
   output logic [AXI_ADDR_WIDTH-1:0]     M_AXI_ARADDR,
   output logic                          M_AXI_ARVALID,
   output logic [AXI_ID_WIDTH-1:0]       M_AXI_ARID,
   output logic [1:0]                    M_AXI_ARBURST,
   output logic [2:0]                    M_AXI_ARSIZE,
   output logic [7:0]                    M_AXI_ARLEN,
   input  logic                          M_AXI_ARREADY,

   // r
   input  logic [AXI_DATA_WIDTH-1:0]     M_AXI_RDATA,
   input  logic                          M_AXI_RVALID,
   input  logic [AXI_ID_WIDTH-1:0]       M_AXI_RID,
   input  logic                          M_AXI_RLAST,
   output logic                          M_AXI_RREADY

   );

   localparam [2:0] SIZE_8B    = 3'd3; 
   localparam [1:0] BURST_INCR = 2'b01;

   logic [AXI_ADDR_WIDTH-1:0]     latched_awaddr;
   logic                          latched_awvalid;
   logic [AXI_ID_WIDTH-1:0]       latched_awid;
   logic [1:0]                    latched_awburst;
   logic [2:0]                    latched_awsize;
   logic [7:0]                    latched_awlen;

   logic [AXI_DATA_WIDTH-1:0]     latched_wdata;
   logic [AXI_DATA_WIDTH/8-1:0]   latched_wstrb;
   logic                          latched_wvalid;
   logic                          latched_wlast;

   logic                          latched_bready;

   logic [AXI_ADDR_WIDTH-1:0]     latched_araddr;
   logic                          latched_arvalid;
   logic [AXI_ID_WIDTH-1:0]       latched_arid;
   logic [1:0]                    latched_arburst;
   logic [2:0]                    latched_arsize;
   logic [7:0]                    latched_arlen;

   logic                          latched_rready;


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
      state               <= IDLE;
      latched_awaddr      <= 1'b0;
      latched_awvalid     <= 1'b0;
      latched_awid        <= 1'b0;
      latched_awburst     <= 1'b0;
      latched_awsize      <= 1'b0;
      latched_awlen       <= 1'b0;

      latched_wdata       <= 1'b0;
      latched_wstrb       <= 1'b0;
      latched_wvalid      <= 1'b0;
      latched_wlast       <= 1'b0;

      latched_bready      <= 1'b0;

      latched_araddr      <= 1'b0;
      latched_arvalid     <= 1'b0;
      latched_arid        <= 1'b0;
      latched_arburst     <= 1'b0;
      latched_arsize      <= 1'b0;
      latched_arlen       <= 1'b0;


   end else begin
      state               <= next_state;

   if(TB_AXI_AWREADY && req_ready) begin
      latched_awvalid     <= 1'b1;
      latched_awaddr      <= TB_AXI_AWADDR;
      latched_awid        <= TB_AXI_AWID;
      latched_awburst     <= TB_AXI_AWBURST;
      latched_awsize      <= TB_AXI_AWSIZE;
      latched_awlen       <= TB_AXI_AWLEN;
      
      latched_wdata       <= TB_AXI_WDATA;
      latched_wstrb       <= TB_AXI_WSTRB;
      latched_wvalid      <= TB_AXI_WVALID;
      latched_wlast       <= TB_AXI_WLAST;
      
      latched_bready      <= TB_AXI_BREADY;
   end

   else begin
      latched_arvalid     <= 1'b1;
      latched_araddr      <= TB_AXI_ARADDR;
      latched_arid        <= TB_AXI_ARID;
      latched_arburst     <= TB_AXI_ARBURST;
      latched_arsize      <= TB_AXI_ARSIZE;
      latched_arlen       <= TB_AXI_ARLEN;
   end


   if (M_AXI_BVALID && M_AXI_BREADY) begin
      if(M_AXI_BID == latched_awid) begin 
         latched_awvalid      <= 1'b0;
         latched_wvalid       <= 1'b0; 
      end  
   end


   if (M_AXI_RVALID && M_AXI_RREADY) begin
      resp_data <= M_AXI_RDATA;
      if (M_AXI_RLAST && M_AXI_RID == latched_arid) begin
         latched_arvalid <= 1'b0;
      end
   end

  end

end
   

assign M_AXI_AWADDR = latched_awaddr; 
assign M_AXI_AWVALID = latched_awvalid;
// ...
assign M_AXI_WDATA = latched_wdata;



endmodule
