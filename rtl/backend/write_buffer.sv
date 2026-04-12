// Write Buffer
//
// Queues write-through writes from the cache and drains them to main
// memory over AXI.  Depth is parameterizable (default 8).
//
// RAW forwarding
//   On every cycle the buffer compares the current read address (from the
//   pipeline) against all valid entries, word-aligned (addr[31:3]).
//   If any entry matches, wb_hit is asserted and wb_fwd_data carries the
//   most-recently-written value for that address (scan newest → oldest).
//   The FSM checks wb_hit before declaring a cache miss so stale MM data
//   is never returned to the CPU.
//
// AXI write flow
//   AW and W are issued simultaneously (both valid in the same cycle).
//   Independent ready tracking handles the case where AWREADY and WREADY
//   arrive in different cycles.  A B response is awaited before the entry
//   is retired.  The B response is forwarded to the CPU so the original
//   write transaction can be acknowledged.
//
// Stall
//   full is asserted when all slots are occupied.  The FSM stalls write
//   requests when full is high.

module write_buffer #(
    parameter int DEPTH         = 8,
    parameter int AXI_ADDR_W    = 32,
    parameter int AXI_DATA_W    = 64,
    parameter int AXI_ID_W      = 4
)(
    input  logic clk,
    input  logic rst_n,

    // ----------------------------------------------------------------
    // Push interface — from FSM (wb_push_en) + decoder (data path)
    // ----------------------------------------------------------------
    input  logic                        push_en,
    input  logic [AXI_ADDR_W-1:0]       push_addr,
    input  logic [AXI_DATA_W-1:0]       push_data,
    input  logic [AXI_ID_W-1:0]         push_id,
    output logic                        full,

    // ----------------------------------------------------------------
    // RAW forwarding — combinational lookup against read address
    // ----------------------------------------------------------------
    input  logic [AXI_ADDR_W-1:0]       rd_addr,
    output logic                        wb_hit,
    output logic [AXI_DATA_W-1:0]       wb_fwd_data,

    // ----------------------------------------------------------------
    // AXI Write Master (AW + W + B channels) — to main memory
    // ----------------------------------------------------------------
    output logic [AXI_ADDR_W-1:0]       m_axi_awaddr,
    output logic                        m_axi_awvalid,
    output logic [AXI_ID_W-1:0]         m_axi_awid,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    input  logic                        m_axi_awready,

    output logic [AXI_DATA_W-1:0]       m_axi_wdata,
    output logic [AXI_DATA_W/8-1:0]     m_axi_wstrb,
    output logic                        m_axi_wvalid,
    output logic                        m_axi_wlast,
    input  logic                        m_axi_wready,

    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    input  logic [AXI_ID_W-1:0]         m_axi_bid,
    output logic                        m_axi_bready,

    // ----------------------------------------------------------------
    // B response forwarded to CPU
    // ----------------------------------------------------------------
    output logic [1:0]                  cpu_bresp,
    output logic                        cpu_bvalid,
    output logic [AXI_ID_W-1:0]         cpu_bid
);

    localparam int PTR_W = $clog2(DEPTH);

    // ------------------------------------------------------------------
    // FIFO storage
    // ------------------------------------------------------------------
    logic [AXI_ADDR_W-1:0]   buf_addr [DEPTH-1:0];
    logic [AXI_DATA_W-1:0]   buf_data [DEPTH-1:0];
    logic [AXI_ID_W-1:0]     buf_id   [DEPTH-1:0];
    logic                    buf_valid[DEPTH-1:0];

    logic [PTR_W-1:0] wr_ptr;   // next slot to write
    logic [PTR_W-1:0] rd_ptr;   // head: entry being drained to MM
    logic [PTR_W:0]   count;    // number of valid entries

    assign full = (count == DEPTH[PTR_W:0]);

    // ------------------------------------------------------------------
    // Head-entry drain state machine
    // States track whether AW and W handshakes have completed
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {
        WB_IDLE,   // nothing to send
        WB_SEND,   // AW+W in progress (neither accepted yet, or only one)
        WB_WAIT_B  // both AW and W done, waiting for B
    } wb_state_t;

    wb_state_t state, next_state;

    logic aw_done, w_done;  // handshake tracking within WB_SEND

    logic head_valid;
    assign head_valid = (count > 0);

    // ------------------------------------------------------------------
    // RAW forwarding — scan newest → oldest for most-recent match
    // Comparison on word-aligned bits [AXI_ADDR_W-1:3]
    // ------------------------------------------------------------------
    always_comb begin
        wb_hit      = 1'b0;
        wb_fwd_data = '0;
        // Scan from newest entry down to oldest
        for (int i = 0; i < DEPTH; i++) begin
            // Compute the slot index (wr_ptr-1-i) wrapping around
            automatic int idx = (DEPTH + wr_ptr - 1 - i) % DEPTH;
            if (buf_valid[idx] &&
                buf_addr[idx][AXI_ADDR_W-1:3] == rd_addr[AXI_ADDR_W-1:3])
            begin
                wb_hit      = 1'b1;
                wb_fwd_data = buf_data[idx];
                break;
            end
        end
    end

    // ------------------------------------------------------------------
    // AXI output (head entry)
    // ------------------------------------------------------------------
    always_comb begin
        m_axi_awvalid = 1'b0;
        m_axi_awaddr  = '0;
        m_axi_awid    = '0;
        m_axi_awlen   = 8'd0;
        m_axi_awsize  = 3'b011; // 8 bytes
        m_axi_awburst = 2'b01;  // INCR
        m_axi_wvalid  = 1'b0;
        m_axi_wdata   = '0;
        m_axi_wstrb   = '1;     // all byte-enables active
        m_axi_wlast   = 1'b1;   // single-beat
        m_axi_bready  = 1'b1;

        if (state == WB_SEND && head_valid) begin
            if (!aw_done) begin
                m_axi_awvalid = 1'b1;
                m_axi_awaddr  = buf_addr[rd_ptr];
                m_axi_awid    = buf_id  [rd_ptr];
            end
            if (!w_done) begin
                m_axi_wvalid = 1'b1;
                m_axi_wdata  = buf_data[rd_ptr];
            end
        end
    end

    // ------------------------------------------------------------------
    // B response forward to CPU
    // ------------------------------------------------------------------
    assign cpu_bvalid = m_axi_bvalid;
    assign cpu_bid    = m_axi_bid;
    assign cpu_bresp  = m_axi_bresp;

    // ------------------------------------------------------------------
    // Sequential: FIFO management + drain FSM
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            state  <= WB_IDLE;
            aw_done <= 1'b0;
            w_done  <= 1'b0;
            for (int i = 0; i < DEPTH; i++)
                buf_valid[i] <= 1'b0;
        end else begin

            // Push new entry
            if (push_en && !full) begin
                buf_addr [wr_ptr] <= push_addr;
                buf_data [wr_ptr] <= push_data;
                buf_id   [wr_ptr] <= push_id;
                buf_valid[wr_ptr] <= 1'b1;
                wr_ptr <= wr_ptr + 1'b1;
                count  <= count + 1'b1;
            end

            // Drain FSM
            case (state)
                WB_IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (head_valid) state <= WB_SEND;
                end

                WB_SEND: begin
                    if (m_axi_awvalid && m_axi_awready) aw_done <= 1'b1;
                    if (m_axi_wvalid  && m_axi_wready)  w_done  <= 1'b1;

                    // Both done (may happen in same cycle)
                    if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done  || (m_axi_wvalid  && m_axi_wready)))
                    begin
                        state   <= WB_WAIT_B;
                        aw_done <= 1'b0;
                        w_done  <= 1'b0;
                    end
                end

                WB_WAIT_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        // Retire head entry
                        buf_valid[rd_ptr] <= 1'b0;
                        rd_ptr <= rd_ptr + 1'b1;
                        count  <= count  - 1'b1;
                        state  <= (count > 1) ? WB_SEND : WB_IDLE;
                        aw_done <= 1'b0;
                        w_done  <= 1'b0;
                    end
                end
            endcase

        end
    end

endmodule
