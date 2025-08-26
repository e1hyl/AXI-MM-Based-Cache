`timescale 1ns / 1ps

module axi_driver
  #(
   parameter integer AXI_ADDR_WIDTH  = 32,
   parameter integer AXI_DATA_WIDTH  = 64,
   parameter integer AXI_ID_WIDTH    = 4,
   )
   (
 
   input logic                          clk,
   input logic                          rst_n,
    
   input  wire                           req_valid,
   output logic                          req_ready,
   input  wire                           req_is_write, 
   input  wire [AXI_ADDR_WIDTH-1:0]      req_addr,
   input  wire [AXI_DATA_WIDTH-1:0]      req_wdata,     
   input  wire [AXI_DATA_WIDTH/8-1:0]    req_wstrb,   

   output logic                          resp_valid,
   output logic [AXI_DATA_WIDTH-1:0]     resp_data,

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

   // b resp
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
   input  logic [1:0]                    M_AXI_RRESP,
   input  logic                          M_AXI_RVALID,
   input  logic [AXI_ID_WIDTH-1:0]       M_AXI_RID,
   input  logic                          M_AXI_RLAST,
   output logic                          M_AXI_RREADY

    );


   localparam BYTES_PER_BEAT  = AXI_DATA_WIDTH/8;
   localparam [2:0] AWSIZE_8B =  $clog2(BYTES_PER_BEAT); 
   
   localparam [2:0] SIZE_8B = 3'd3; 
   localparam [1:0] BURST_INCR = 2'b01;

   localparam line_depth      = 2;

   logic                                  req_latched_valid;
   logic                                  req_latched_is_write;
   logic [AXI_ADDR_WIDTH-1:0]             req_latched_addr;
   logic [7:0]                            req_latched_len;
   logic [2:0]                            req_latched_size;
   logic [AXI_DATA_WIDTH-1:0]             req_latched_wdata;
   logic [AXI_DATA_WIDTH/8-1:0]           req_latched_wstrb;
   
   logic                                  in_flight;


   // assignments for constants
   assign M_AXI_AWSIZE  = SIZE_8B;      // 8 bytes per beat
   assign M_AXI_ARSIZE  = SIZE_8B;
   assign M_AXI_AWLEN   = 8'd0;         // AWLEN = beats - 1 -> 0 means 1 beat
   assign M_AXI_ARLEN   = 8'd0;
   assign M_AXI_AWBURST = BURST_INCR;   // INCR burst
   assign M_AXI_ARBURST = BURST_INCR;
   assign M_AXI_AWID    = '0;
   assign M_AXI_ARID    = '0;  
   assign M_AXI_WLAST   = 1;




   logic [AXI_DATA_WIDTH-1:0]             line_buffer[line_depth-1:0];                              


   typedef enum logic [2:0] {
      IDLE, 
      SEND_AW, 
      SEND_W, 
      SEND_AR, 
      WAIT_RESP
      } my_state;

   my_state state, next_state;

   assign req_ready = (state == IDLE) && !in_flight;

   always_comb begin 
      next_state = state; 

      M_AXI_AWVALID = 1'b0;
      M_AXI_WVALID  = 1'b0;
      M_AXI_WLAST   = 1'b0;
      M_AXI_ARVALID = 1'b0;
      M_AXI_RREADY  = 1'b0;   
      M_AXI_BREADY  = 1'b0;
      M_AXI_WDATA   = '0';
      M_AXI_WSTRB   = '0;
      M_AXI_BREADY  = 1'b0;
      M_AXI_RREADY  = 1'b0;

      req_ready  = (state == S_IDLE) && !req_latched_valid && !in_flight;

      resp_valid = 1'b0;
      resp_data  = '0;  

      case (state)

         IDLE: begin
            if(req_latched_valid) begin
               
               if(req_latched_is_write)
                  next_state = SEND_AW;
               else  
                  next_state = SEND_AR;

               end
            end

         SEND_AW: begin
            M_AXI_AWVALID = 1'b1;
            M_AXI_AWADDR  = req_latched_addr;
            if(M_AXI_AWREADY) begin
               next_state =  SEND_W;
            end
         end

         SEND_W: begin
            M_AXI_VALID = 1'b1;
            M_AXI_WDATA = req_latched_wdata;
            M_AXI_WSTRB = req_latched_strb;
            if (M_AXI_WVALID && M_AXI_WREADY) begin
               next_state  = WAIT_RESP;
            end
         end

         SEND_AR: begin
            M_AXI_ARVALID = 1'b1;
            M_AXI_ARADDR  = req_latched_addr;
            if(M_AXI_ARREADY) 
               next_state = WAIT_RESP;
         end

         WAIT_RESP: begin
            if(req_is_write) begin
               M_AXI_BREADY = 1'b1;
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
         
         default: next_state = S_IDLE;

      endcase
   end


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
      state                <= IDLE;
      req_latched_valid    <= 1'b0;
      req_latched_is_write <= 1'b0;
      req_latched_addr     <= '0;
      req_latched_wdata    <= '0;
      req_latched_wstrb    <= '0;
      complete_event       <= 1'b0;
      req_valid            <= 1'b0;
      resp_data            <= '0;
      in_flight            <= 1'b0;

   end else begin
      state                <= next_state;
      complete_event       <= 1'b0;
      resp_valid           <= 1'b0;

   if(req_valid & req_ready) begin
      req_latched_valid    <= 1'b1;
      req_latched_addr     <= req_addr;
      req_latcehd_is_write <= req_is_write;
      req_latched_wstrbe   <= req_wstrb
      req_latched_wdata    <= req_wdata;
   end

   if (state == SEND_AW && M_AXI_AWVALID && M_AXI_AWREADY) begin
      in_flight       <= 1;
   end

    if (state == SEND_AR && M_AXI_ARVALID && M_AXI_ARREADY) begin
      in_flight  <= 1;
    end

 
   if (M_AXI_BVALID && M_AXI_BREADY) begin
      req_latched_valid  <= 1'b0;
      in_flight          <= 1'b0;
      complete_event     <= 1'b1;
      resp_valid         <= 1'b1;   
      resp_data          <= '0;    
   end


   if (M_AXI_RVALID && M_AXI_RREADY) begin
      resp_data <= M_AXI_RDATA;
      if (M_AXI_RLAST) begin
         req_latched_valid <= 1'b0;
         in_flight         <= 1'b0;
         complete_event    <= 1'b1;
         resp_valid        <= 1'b1;
      end
   end


  end
end
   

endmodule
