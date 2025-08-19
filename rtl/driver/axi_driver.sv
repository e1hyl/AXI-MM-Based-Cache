`timescale 1ns / 1ps

module axi_driver
  #(
    parameter integer AXI_ADDR_WIDTH  = 32,
    parameter integer AXI_DATA_WIDTH  = 64,
    parameter integer AXI_ID_WIDTH    = 4,
    )
   (
    input                                init_transaction,

    input wire                           M_AXI_ACLK,
    input wire                           M_AXI_ARESETN,

    // aw
    output wire [AXI_ADDR_WIDTH-1:0]     M_AXI_AWADDR,
    output wire                          M_AXI_AWVALID,
    output wire [AXI_ID_WIDTH-1:0]       M_AXI_AWID,
    output wire [1:0]                    M_AXI_AWBURST,
    output wire [2:0]                    M_AXI_AWSIZE,
    output wire [7:0]                    M_AXI_AWLEN,
    input wire                           M_AXI_AWREADY,

    // w
    output wire [AXI_DATA_WIDTH-1 : 0]   M_AXI_WDATA,
    output wire [AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    output wire                          M_AXI_WVALID,
    output wire                          M_AXI_WLAST,
    input wire                           M_AXI_WREADY,

    // b resp
    input wire [1:0]                     M_AXI_BRESP,
    input wire                           M_AXI_BVALID,
    input wire [AXI_ID_WIDTH-1:0]        M_AXI_BID,
    output wire                          M_AXI_BREADY,

    // ar
    output wire [AXI_ADDR_WIDTH-1:0]     M_AXI_ARADDR,
    output wire                          M_AXI_ARVALID,
    output wire [AXI_ID_WIDTH-1:0]       M_AXI_ARID,
    output wire [1:0]                    M_AXI_ARBURST,
    output wire [2:0]                    M_AXI_ARSIZE,
    output wire [7:0]                    M_AXI_ARLEN,
    input wire                           M_AXI_ARREADY,

    // r
    input wire [AXI_DATA_WIDTH-1:0]      M_AXI_RDATA,
    input wire [1:0]                     M_AXI_RRESP,
    input wire                           M_AXI_RVALID,
    input wire [AXI_ID_WIDTH-1:0]        M_AXI_RID,
    input wire                           M_AXI_RLAST,
    output wire                          M_AXI_RREADY

    // front-end, external interface
    input  logic                         req_valid, req_is_write,
    input  logic [AXI_ADDR_WIDTH-1:0]    req_addr,
    input  logic [7:0]                   req_len,
    input  logic [2:0]                   req_size,
    input  logic [AXI_DATA_WIDTH-1:0]    req_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]  req_wstrb,
    output logic                         req_ready 


    );


   localparam BYTES_PER_BEAT = AXI_DATA_WIDTH/8;
   localparam [2:0] AWSIZE_8B = 3'd3; //

   // assignments for constants
   assign M_AXI_AWSIZE  = AWSIZE_8B;    // 8 bytes per beat
   assign M_AXI_ARSIZE  = AWSIZE_8B;
   assign M_AXI_AWLEN   = 8'd0;         // AWLEN = beats - 1 -> 0 means 1 beat
   assign M_AXI_ARLEN   = 8'd0;
   assign M_AXI_AWBURST = 2'b01;        // INCR burst (typical)
   assign M_AXI_ARBURST = 2'b01;


   assign M_AXI_AWID = 'b0;
   assign M_AXI_BID  = 'b0;
   assign M_AXI_ARID = 'b0;  
   assign M_AXI_RID  = 'b0;


  
   
   logic                                 write_done;
   assign write_done = axi_bready & M_AXI_BVALID; 

   logic                                 read_done;
   assign read_done = axi_rready & M_AXI_RVALID; 

   logic stall_active;


   logic                                 init_transaction_i;


   always_ff @(posedge M_AXI_ACLK)
     begin
        init_transaction_i <= init_transaction;
     end


   logic start;
   assign start = (init_transaction & ~init_transaction_i) ? 1 : 0;

   logic                                 req_latched_valid;
   logic [AXI_ADDR_WIDTH-1:0]            req_latched_addr;
   logic [7:0]                           req_latched_len;
   logic [2:0]                           req_latched_size;
   logic [AXI_DATA_WIDTH-1:0]            req_latched_wdata;
   logic [AXI_DATA_WIDTH/8-1:0]          req_latched_wstrb;



   logic                                 in_flight;
   logic                                 current_id = 0;
   logic [AXI_ADDR_WIDTH-1:0]            saved_addr;
   logic [7:0]                           saved_len;
   logic [2:0]                           saved_size;
   logic [AXI_DATA_WIDTH-1:0]            saved_wdata;
   logic [AXI_DATA_WIDTH/8-1:0]          saved_wstrb;


   logic                                 data_ptr;
   logic                                 line_buffer;                              


   // State machine
   // write to registers
   typedef enum {IDLE, SEND_AW, SEND_W, SEND_AR, WAIT_RESP}  my_state;

   my_state current_state, next_state;

   assign req_ready = (state == IDLE) && !in_flight;

   always_ff @(posedge M_AXI_ACLK or negedge M_AXI_ARESETN) begin

      if(!M_AXI_ARESETN) begin
         req_latched_valid = 1'b0;
      end else begin

      if(req_valid & req_ready) begin
         req_latched_valid   <= 1'b1;
         req_latched_addr    <= req_addr;
         req_latched_len     <= req_len;
         req_latched_size    <= req_size;
         req_latcehd_iswrite <= req_is_write;
         req_latched_strobe  <= req_wstrb
         req_latched_data    <= req_wdata;
      end

      if (write_done | read_done)
         req_latched_valid <= 1'b0;
      end
   end



   always_comb begin // computing the next state
      next_state = state; 

      M_AXI_AWVALID = 0;
      M_AXI_WVALID  = 0;
      M_AXI_WLAST   = 0;
      M_AXI_ARVALID = 0;
      M_AXI_RREADY  = 1;   
      M_AXI_BREADY  = 1;   

   case (state)
      IDLE: begin
         if(req_valid && in_flight) begin
            
            if(req_is_write) begin
               M_AXI_VALID = 1;
               M_AXI_AWADDR = req_addr;
               M_AXI_AWLEN = req_len;
               M_AXI_AWSIZE = req_size;
               next_state = SEND_AW;
            
            end else begin
               M_AXI_ARVALID = 1;
               M_AXI_ARADDR  = req_addr;
               M_AXI_AWLEN   = req_len;
               M_AXI_ARSIZE  = req_size;
               next_state = SEND_AR;
            end
         end
      end

      SEND_AW: begin
         M_AXI_AWVALID = 1;
         if(M_AXI_AWREADY) begin
            saved_addr = req_latched_addr;
            next_state =  SEND_W;
         end
      end

      SEND_W: begin
         M_AXI_VALID = 1;
         M_AXI_WLAST = 1;
         if (M_AXI_WVALID && M_AXI_WREADY) begin
            next_state  = WAIT_RESP;
            saved_wdata = req_latched_addr;
            saved_wstrb = req_latched_strobe;
         end
      end

      SEND_AR: begin
         M_AXI_ARVALID = 1;
         if(M_AXI_ARREADY && M_AXI_ARVALID) 
            saved_addr = req_latched_addr;
            next_state = WAIT_RESP;
      end

      WAIT_RESP: begin
         if(req_is_write) begin
            if(M_AXI_BVALID && (BRESP == 3'b000))
               next_state = IDLE;   
         end else begin
            if (M_AXI_RVALID && M_AXI_RLAST)
               next_state = IDLE;
         end
      end
   
   endcase
   end

   // TO BE CONTINUED

   always_ff @(posedge M_AXI_CLK or negedge M_AXI_ARESTEN) begin

   end


   assign M_AXI_WDATA = saved_wdata;
   assign M_AXI_WSTRB = saved_wstrb;
   assign M_AXI_WVALID = (state == SEND_W) && (beats_remaining > 0);
   assign M_AXI_WLAST  = (beats_remaining == 1);

endmodule
