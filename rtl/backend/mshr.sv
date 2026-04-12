// Miss Status Holding Register (MSHR)
//
// Tracks up to NUM_ENTRIES (4) outstanding read-miss requests.
// Each entry stores the target way, set, and tag so the AXI AR address
// can be reconstructed and the fill can be routed back to the right line.
//
// Entry lifecycle
//   EMPTY   : valid=0, zombie=0
//   ACTIVE  : valid=1, zombie=0  — AR not yet sent or waiting for R
//   ZOMBIE  : valid=0, zombie=1  — dealloc'd by FSM (write-to-pending cancel)
//             but AR was already accepted; must wait for R to drain cleanly
//
// AXI AR
//   The MSHR uses the entry index (0-3) as ARID so it can match the R
//   response back to the correct entry.  Entries are issued lowest-index
//   first; at most one AR is in flight at a time (ARVALID deasserts after
//   ARREADY).  RREADY is permanently asserted — the memory model is
//   expected to be well-behaved.
//
// mm_rcvd
//   Fires for exactly one cycle when a valid (non-zombie) R response
//   completes.  The FSM uses this to update the status store and data
//   store.  Zombie fills are silently discarded.

module mshr #(
    parameter int NUM_ENTRIES  = 4,
    parameter int TAG_W        = 22,
    parameter int AXI_ADDR_W   = 32,
    parameter int AXI_DATA_W   = 64,
    parameter int AXI_ID_W     = 4
)(
    input  logic clk,
    input  logic rst_n,

    // ----------------------------------------------------------------
    // Alloc — driven by FSM on every read-miss allocation
    // alloc_set / alloc_tag come directly from the decoder (data path)
    // ----------------------------------------------------------------
    input  logic               alloc_en,
    input  logic [1:0]         alloc_way,
    input  logic [6:0]         alloc_set,
    input  logic [TAG_W-1:0]   alloc_tag,

    // ----------------------------------------------------------------
    // Dealloc — FSM cancels a pending fill (write-to-pending case)
    // ----------------------------------------------------------------
    input  logic               dealloc_en,
    input  logic [1:0]         dealloc_way,
    input  logic [6:0]         dealloc_set,

    // ----------------------------------------------------------------
    // Status to FSM
    // ----------------------------------------------------------------
    output logic               mshr_full,

    // ----------------------------------------------------------------
    // Fill-complete notification to FSM (one-cycle pulse)
    // ----------------------------------------------------------------
    output logic               mm_rcvd,
    output logic [1:0]         mm_rcvd_way,
    output logic [6:0]         mm_rcvd_set,

    // ----------------------------------------------------------------
    // Fill data to data_store (pure data path, bypasses FSM)
    // ----------------------------------------------------------------
    output logic [AXI_DATA_W-1:0] fill_data,

    // ----------------------------------------------------------------
    // AXI Read Master — to main memory
    // ----------------------------------------------------------------
    output logic [AXI_ADDR_W-1:0] m_axi_araddr,
    output logic                  m_axi_arvalid,
    output logic [AXI_ID_W-1:0]   m_axi_arid,
    output logic [7:0]            m_axi_arlen,    // always 0 (single beat)
    output logic [2:0]            m_axi_arsize,   // always 3 (8 bytes)
    output logic [1:0]            m_axi_arburst,  // always INCR
    input  logic                  m_axi_arready,

    input  logic [AXI_DATA_W-1:0] m_axi_rdata,
    input  logic                  m_axi_rvalid,
    input  logic [AXI_ID_W-1:0]   m_axi_rid,
    input  logic                  m_axi_rlast,
    output logic                  m_axi_rready
);

    // ------------------------------------------------------------------
    // Entry storage
    // ------------------------------------------------------------------
    logic              valid  [NUM_ENTRIES-1:0];
    logic              zombie [NUM_ENTRIES-1:0];
    logic              ar_sent[NUM_ENTRIES-1:0]; // AR accepted by memory
    logic [1:0]        e_way  [NUM_ENTRIES-1:0];
    logic [6:0]        e_set  [NUM_ENTRIES-1:0];
    logic [TAG_W-1:0]  e_tag  [NUM_ENTRIES-1:0];

    // ------------------------------------------------------------------
    // Free-entry finder (priority: lowest index)
    // ------------------------------------------------------------------
    logic [1:0] free_idx;
    always_comb begin
        free_idx = 2'd0;
        for (int i = NUM_ENTRIES-1; i >= 0; i--)
            if (!valid[i] && !zombie[i]) free_idx = 2'(i);
    end

    // Full when every slot is either valid or zombie (AR in flight)
    assign mshr_full = &{ (valid[3]|zombie[3]),
                          (valid[2]|zombie[2]),
                          (valid[1]|zombie[1]),
                          (valid[0]|zombie[0]) };

    // ------------------------------------------------------------------
    // AR arbitration — issue lowest pending entry (not yet sent)
    // ------------------------------------------------------------------
    logic [1:0] ar_idx;
    logic       ar_pending;
    always_comb begin
        ar_idx     = 2'd0;
        ar_pending = 1'b0;
        for (int i = NUM_ENTRIES-1; i >= 0; i--)
            if (valid[i] && !ar_sent[i]) begin
                ar_idx     = 2'(i);
                ar_pending = 1'b1;
            end
    end

    // AXI AR output — fixed burst/size for single-beat 64-bit transfers
    assign m_axi_arvalid = ar_pending;
    assign m_axi_araddr  = { e_tag[ar_idx], e_set[ar_idx], 3'b000 };
    assign m_axi_arid    = AXI_ID_W'(ar_idx);
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'b011;  // 8 bytes
    assign m_axi_arburst = 2'b01;   // INCR
    assign m_axi_rready  = 1'b1;

    // ------------------------------------------------------------------
    // R-response matching — RID carries the entry index
    // ------------------------------------------------------------------
    logic [1:0] rcvd_idx;
    assign rcvd_idx = m_axi_rid[1:0];

    // Fire mm_rcvd only for live (non-zombie) entries
    assign mm_rcvd     = m_axi_rvalid && m_axi_rlast &&  valid[rcvd_idx]
                                                      && !zombie[rcvd_idx];
    assign mm_rcvd_way = e_way[rcvd_idx];
    assign mm_rcvd_set = e_set[rcvd_idx];
    assign fill_data   = m_axi_rdata;

    // ------------------------------------------------------------------
    // Sequential entry management
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                valid  [i] <= 1'b0;
                zombie [i] <= 1'b0;
                ar_sent[i] <= 1'b0;
                e_way  [i] <= 2'd0;
                e_set  [i] <= 7'd0;
                e_tag  [i] <= '0;
            end
        end else begin

            // Alloc (FSM grants this only when !mshr_full)
            if (alloc_en) begin
                valid  [free_idx] <= 1'b1;
                ar_sent[free_idx] <= 1'b0;
                e_way  [free_idx] <= alloc_way;
                e_set  [free_idx] <= alloc_set;
                e_tag  [free_idx] <= alloc_tag;
            end

            // AR handshake — mark entry as AR-sent
            if (m_axi_arvalid && m_axi_arready)
                ar_sent[ar_idx] <= 1'b1;

            // Dealloc from FSM (write-to-pending cancel)
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (dealloc_en && valid[i]
                    && e_way[i] == dealloc_way
                    && e_set[i] == dealloc_set)
                begin
                    valid[i] <= 1'b0;
                    if (ar_sent[i])
                        zombie[i] <= 1'b1;  // AR in flight, must drain
                end
            end

            // R response received — free entry (valid or zombie)
            if (m_axi_rvalid && m_axi_rlast) begin
                valid  [rcvd_idx] <= 1'b0;
                zombie [rcvd_idx] <= 1'b0;
                ar_sent[rcvd_idx] <= 1'b0;
            end

        end
    end

endmodule
