// Cache Control FSM
//
// Policy  : write-through, no-write-allocate, PLRU replacement
// Stall   : read miss with all MSHR entries occupied, OR
//           read miss that coincides with mm_rcvd (one-cycle deferral)
// Writes  : never stall — posted write-through, no cache allocation on miss
//
// Cache line states live in status_bits_store (external).
// This module owns only the FSM state register.
//
// mm_rcvd handling
//   mm_rcvd always takes priority for the status write port.
//   It is processed at the END of always_comb so its assignments
//   override anything set by the case statement.
//   If a read miss coincides with mm_rcvd the miss is deferred by
//   asserting stall for one cycle (without entering STALL state).
//
// Connections to other modules
//   hit_detector  : true_hit, pending_hit, hit_way, pending_way
//   plru_store    : victim_way (in), update_en + accessed_way (out)
//   tag_store     : tag_wr_en + tag_wr_way  (index/new_tag from decoder)
//   status_store  : status_wr_en/set/way/data
//   data_store    : cpu_data_wr_en, fill_data_wr_en
//   MSHR          : mshr_full (in), alloc/dealloc signals (out)
//   MM            : mm_rcvd/way/set (in), mm_rd_req/mm_wr_req (out)

module control_fsm #(
    parameter int SET_INDEX = 128,
    parameter int SET_WAY   = 4
)(
    input  logic clk,
    input  logic rst_n,

    // ----------------------------------------------------------------
    // CPU / pipeline request
    // ----------------------------------------------------------------
    input  logic        req_valid,
    input  logic        req_type,           // 0=read  1=write
    input  logic [6:0]  req_set,
    output logic        stall,

    // ----------------------------------------------------------------
    // Hit detector outputs (pre-qualified against status bits)
    // ----------------------------------------------------------------
    input  logic        true_hit,           // tag match on a VALID way
    input  logic        pending_hit,        // tag match on a PENDING way
    input  logic [1:0]  hit_way,            // hit_way_index from hit_detector
    input  logic [1:0]  pending_way,        // pending_way_index from hit_detector

    // ----------------------------------------------------------------
    // PLRU state store
    // ----------------------------------------------------------------
    input  logic [1:0]  victim_way,         // LRU way for req_set
    output logic        plru_update_en,
    output logic [1:0]  plru_accessed_way,

    // ----------------------------------------------------------------
    // MSHR
    // ----------------------------------------------------------------
    input  logic        mshr_full,
    output logic        mshr_alloc_en,
    output logic [1:0]  mshr_alloc_way,
    output logic        mshr_dealloc_en,
    output logic [1:0]  mshr_dealloc_way,

    // ----------------------------------------------------------------
    // Main memory fill response (one cycle pulse)
    // ----------------------------------------------------------------
    input  logic        mm_rcvd,
    input  logic [1:0]  mm_rcvd_way,
    input  logic [6:0]  mm_rcvd_set,

    // ----------------------------------------------------------------
    // Main memory requests
    // ----------------------------------------------------------------
    output logic        mm_rd_req,          // fetch line on read miss
    output logic        mm_wr_req,          // write-through write

    // ----------------------------------------------------------------
    // Response to CPU / AXI response block
    // ----------------------------------------------------------------
    output logic        resp_en,            // read hit: data is ready

    // ----------------------------------------------------------------
    // Status bits store write port
    // (read port driven directly from decoder index; hits go to hit_detector)
    // ----------------------------------------------------------------
    output logic        status_wr_en,
    output logic [6:0]  status_wr_set,
    output logic [1:0]  status_wr_way,
    output logic [1:0]  status_wr_data,

    // ----------------------------------------------------------------
    // Tag store write port
    // (write_index and new_tag come directly from decoder)
    // ----------------------------------------------------------------
    output logic        tag_wr_en,
    output logic [1:0]  tag_wr_way,

    // ----------------------------------------------------------------
    // Data store write enables
    // (addresses and data come from their respective sources)
    // ----------------------------------------------------------------
    output logic        cpu_data_wr_en,     // write hit: CPU data → cache
    output logic        fill_data_wr_en     // mm_rcvd:   MM data  → cache
);

    // ------------------------------------------------------------------
    // Line state encoding (shared with status_bits_store and hit_detector)
    // ------------------------------------------------------------------
    localparam logic [1:0] INVALID = 2'b00;
    localparam logic [1:0] VALID   = 2'b01;
    localparam logic [1:0] PENDING = 2'b10;

    // ------------------------------------------------------------------
    // FSM state register
    // ------------------------------------------------------------------
    typedef enum logic { IDLE, STALL } fsm_t;
    fsm_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // ------------------------------------------------------------------
    // Combinational: outputs + next state
    //
    // Structure:
    //   1. Set all outputs to safe defaults
    //   2. case(state): IDLE / STALL
    //   3. mm_rcvd block AFTER case — overrides status and data write
    //      signals so the fill always wins the write port
    // ------------------------------------------------------------------
    always_comb begin
        // ---- defaults ------------------------------------------------
        next_state         = state;
        stall              = 1'b0;
        resp_en            = 1'b0;
        plru_update_en     = 1'b0;
        plru_accessed_way  = 2'd0;
        mshr_alloc_en      = 1'b0;
        mshr_alloc_way     = 2'd0;
        mshr_dealloc_en    = 1'b0;
        mshr_dealloc_way   = 2'd0;
        mm_rd_req          = 1'b0;
        mm_wr_req          = 1'b0;
        status_wr_en       = 1'b0;
        status_wr_set      = 7'd0;
        status_wr_way      = 2'd0;
        status_wr_data     = INVALID;
        tag_wr_en          = 1'b0;
        tag_wr_way         = 2'd0;
        cpu_data_wr_en     = 1'b0;
        fill_data_wr_en    = 1'b0;

        case (state)

            // ==========================================================
            IDLE: begin
                if (req_valid) begin

                    if (!req_type) begin
                        // ------------------------------------------
                        // READ
                        // ------------------------------------------
                        if (true_hit) begin
                            resp_en           = 1'b1;
                            plru_update_en    = 1'b1;
                            plru_accessed_way = hit_way;

                        end else begin
                            // Read miss (also covers pending_hit:
                            // still outstanding, treat as miss)
                            if (mshr_full) begin
                                stall      = 1'b1;
                                next_state = STALL;

                            end else if (mm_rcvd) begin
                                // Status write port busy this cycle.
                                // Hold pipeline for one cycle; do not
                                // change FSM state.
                                stall = 1'b1;

                            end else begin
                                // Allocate victim_way: evict silently
                                // (write-through → no dirty data),
                                // send fetch to MM, mark PENDING
                                mm_rd_req          = 1'b1;
                                mshr_alloc_en      = 1'b1;
                                mshr_alloc_way     = victim_way;
                                tag_wr_en          = 1'b1;
                                tag_wr_way         = victim_way;
                                status_wr_en       = 1'b1;
                                status_wr_set      = req_set;
                                status_wr_way      = victim_way;
                                status_wr_data     = PENDING;
                            end
                        end

                    end else begin
                        // ------------------------------------------
                        // WRITE  (write-through, no-write-allocate)
                        // ------------------------------------------
                        mm_wr_req = 1'b1;   // always push to MM

                        if (true_hit) begin
                            // Update cache copy and PLRU
                            cpu_data_wr_en    = 1'b1;
                            plru_update_en    = 1'b1;
                            plru_accessed_way = hit_way;

                        end else if (pending_hit) begin
                            // In-flight fill will return stale data.
                            // Cancel it to keep the cache coherent.
                            mshr_dealloc_en  = 1'b1;
                            mshr_dealloc_way = pending_way;
                            status_wr_en     = 1'b1;
                            status_wr_set    = req_set;
                            status_wr_way    = pending_way;
                            status_wr_data   = INVALID;
                        end
                        // Write miss: mm_wr_req set; no cache action
                    end
                end
            end

            // ==========================================================
            // STALL: pipeline held; req_valid/req_set/req_type are stable
            //
            // Guard on !mm_rcvd so the status write port is free when
            // we retry (even though in practice mm_rcvd targets a
            // different way, this avoids any aliasing risk).
            // ==========================================================
            STALL: begin
                stall = 1'b1;

                if (!mshr_full && !mm_rcvd) begin
                    next_state         = IDLE;
                    stall              = 1'b0;
                    mm_rd_req          = 1'b1;
                    mshr_alloc_en      = 1'b1;
                    mshr_alloc_way     = victim_way;
                    tag_wr_en          = 1'b1;
                    tag_wr_way         = victim_way;
                    status_wr_en       = 1'b1;
                    status_wr_set      = req_set;
                    status_wr_way      = victim_way;
                    status_wr_data     = PENDING;
                end
            end

        endcase

        // ==============================================================
        // mm_rcvd: PENDING -> VALID
        // Placed AFTER case so these assignments override anything set
        // above for the same signals.
        // fill_data_wr_en is safe to assert alongside cpu_data_wr_en
        // because they always target different ways (PENDING vs VALID).
        // ==============================================================
        if (mm_rcvd) begin
            status_wr_en    = 1'b1;
            status_wr_set   = mm_rcvd_set;
            status_wr_way   = mm_rcvd_way;
            status_wr_data  = VALID;
            fill_data_wr_en = 1'b1;
        end

    end

endmodule
