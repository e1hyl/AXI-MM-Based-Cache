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

   logic                          req_ready;
   logic [AXI_DATA_WIDTH-1:0]     resp_data;


   // assignments for constants
   //assign M_AXI_AWSIZE  = SIZE_8B;      // 8 bytes per beat
   //assign M_AXI_ARSIZE  = SIZE_8B;
   //assign M_AXI_AWLEN   = 8'd0;         // AWLEN = beats - 1 -> 0 means 1 beat
   //assign M_AXI_ARLEN   = 8'd0;
   //assign M_AXI_AWBURST = BURST_INCR;   // INCR burst
   //assign M_AXI_ARBURST = BURST_INCR;
   //assign M_AXI_WLAST   = 1'b1;     


   typedef enum logic [2:0] {
      IDLE, 
      SEND_AW, 
      SEND_W, 
      SEND_AR, 
      WAIT_RESP
      } my_state;

   my_state state, next_state;


   always_comb begin 
      next_state = state; 

      M_AXI_AWVALID = 1'b0;
      M_AXI_WVALID  = 1'b0;
      M_AXI_ARVALID = 1'b0;
      M_AXI_RREADY  = 1'b0;   
      M_AXI_BREADY  = 1'b0;
      M_AXI_WDATA   = '0;
      M_AXI_WSTRB   = '0;
      M_AXI_BREADY  = 1'b0;
      M_AXI_RREADY  = 1'b0;

      req_ready  = (state == IDLE) && !latched_awvalid && !latched_arvalid;

        case (state)

         IDLE: begin
            if(latched_awvalid)                
               next_state = SEND_AW;
            else if(latched_arvalid)
               next_state = SEND_AR;
         end

         SEND_AW: begin
            TB_AXI_AWREADY = 1'b1; 
            M_AXI_AWVALID  = 1'b1;
            M_AXI_AWADDR   = latched_awaddr;
            M_AXI_AWID     = latched_awid;
            if(M_AXI_AWREADY) begin
               next_state =  SEND_W;
            end
         end

         SEND_W: begin
            TB_AXI_WREADY = 1'b1; 
            M_AXI_WVALID  = 1'b1;
            M_AXI_WDATA   = latched_wdata;
            M_AXI_WSTRB   = latched_wstrb;
            if (M_AXI_WVALID && M_AXI_WREADY) begin
               next_state  = WAIT_RESP;
            end
         end

         SEND_AR: begin
            TB_AXI_ARREADY = 1'b1;
            M_AXI_ARVALID  = 1'b1;
            M_AXI_ARADDR   = latched_araddr;
            M_AXI_ARID     = latched_arid;
            if(M_AXI_ARREADY) 
               next_state = WAIT_RESP;
         end

         WAIT_RESP: begin
            if(latched_awvalid) begin
               M_AXI_BREADY  = 1'b1;
               TB_AXI_BRESP  = M_AXI_BRESP;
               TB_AXI_BVALID = M_AXI_BVALID;
               TB_AXI_BID    = M_AXI_BID; 
               if(M_AXI_BVALID)
                  next_state = IDLE;   
            end 
            else begin
               M_AXI_RREADY = 1'b1;
               if (M_AXI_RVALID) begin
                  if(M_AXI_RLAST)
                     next_state = IDLE;
               end
            end
         end
         
         default: next_state = IDLE;

      endcase
   end


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
   

endmodule
