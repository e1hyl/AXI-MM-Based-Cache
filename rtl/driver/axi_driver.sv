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

   // aw
   logic [AXI_ADDR_WIDTH-1:0]          axi_awaddr;
   logic                               axi_awvalid;

   // assign outputs to top level signals
   assign M_AXI_AWADDR = axi_awaddr;
   assign M_AXI_AWVALID = axi_awvalid;

   // w
   logic [AXI_DATA_WIDTH-1:0]          axi_wdata;
   logic [AXI_DATA_WIDTH/8-1:0]        axi_wstrb;
   logic                               axi_wvalid;
// logic                               axi_awid;
   logic                               axi_wlast;
   assign M_AXI_WSTRB = axi_wstrb;
   assign M_AXI_WVALID = axi_wvalid;
   assign M_AXI_WDATA = axi_wdata;
// assign M_AXI_AWID = axi_awid;
   assign M_AXI_WLAST = axi_wlast;
   assign M_AXI_AWID = 'b0;

   // b
   logic                               axi_bready;
   logic                               axi_berror;
// logic                               axi_bid;
   assign M_AXI_BREADY = axi_bready;
// assign M_AXI_BID = axi_bid;
   assign M_AXI_BID = 'b0;

   // ar
   logic [AXI_ADDR_WIDTH-1 0]          axi_araddr;
   logic                               axi_arvalid;
// logic                               axi_arid;
   assign M_AXI_ARADDR = axi_araddr;
   assign M_AXI_ARVALID = axi_arvalid;
// assign M_AXI_ARID = axi_arid;
   assign M_AXI_ARID = 'b0;  


   // r
   logic [AXI_DATA_WIDTH-1:0]          axi_rready;
   logic                               axi_rerror;
// logic                               axi_rid;
   assign M_AXI_RREADY = axi_rready;
// assign M_AXI_RID = axi_rid;
   assign M_AXI_RID = 'b0;


  
   
   logic                                 write_done;
   assign write_done = axi_bready & M_AXI_BVALID; 

   logic                                 read_done;
   assign read_done = axi_rready & M_AXI_RVALID; 

   logic stall_active;

   // Write interfaces
   logic                                 init_transaction_i;

   // edge detect on input_fsync
   always_ff @(posedge M_AXI_ACLK)
     begin
        init_transaction_i <= init_transaction;
     end

   // This is how we do an edge detect.
   // Init WAS low (the delayed version has ~) and NOW it is NOT (so it went from 0 to 1).
   // This is a 1cc edge detect
   logic start;
   assign start = (init_transaction & ~init_transaction_i) ? 1 : 0;


   logic                                 in_flight;
   logic                                 current_id = 0;
   logic                                 saved_addr;
   logic                                 saved_len;
   logic                                 saved_size;
   logic                                 beats_remaining;
   logic                                 beat_index;
   logic                                 data_ptr;
   logic                                 line_buffer;
   logic                                 req_latched;                               


   // State machine
   // write to registers
   typedef enum {IDLE, SEND_AW, SEND_W, SEND_AR, WAIT_RESP}  my_state;

   my_state current_state, next_state;

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
               M_AXI_ARADDR = req_addr;
               M_AXI
            end


   endcase
   end

   always_ff @(posedge M_AXI_CLK or negedge M_AXI_ARESTEN) begin

   end

  


endmodule
