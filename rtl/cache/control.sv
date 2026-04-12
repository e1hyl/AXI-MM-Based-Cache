// Cache Control FSM
//
// Policy  : write-through, no-write-allocate, PLRU replacement
//
// Stall conditions
//   - Read miss  + MSHR full                     → enter STALL state
//   - Read miss  + mm_rcvd same cycle             → one-cycle deferral
//   - Write      + write buffer full              → stall (no state change)
//
// RAW forwarding
//   The write buffer performs a combinational address lookup on every
//   request.  If wb_hit is asserted the FSM treats the request as a hit
//   and sets fwd_sel=1 so the data mux upstream selects the write-buffer
//   value instead of the cache data array output.  No cache allocation
//   or PLRU update occurs on a forwarding hit.
//
// mm_rcvd priority
//   The mm_rcvd block sits AFTER the case statement so its status-write
//   and fill-data-write signals override anything the case statement set
//   in the same cycle.  In normal operation mm_rcvd and FSM writes target
//   different ways (PENDING vs VALID/INVALID) so there is no conflict.
//
// Module boundaries
//   hit_detector  → true_hit, pending_hit, hit_way, pending_way
//   plru_store    → victim_way (in),  update_en + accessed_way (out)
//   tag_store     → tag_wr_en + tag_wr_way  (index/new_tag wired from decoder)
//   status_store  → status_wr_en/set/way/data
//   data_store    → cpu_data_wr_en, fill_data_wr_en
//   mshr          → mshr_full + mm_rcvd/way/set (in), alloc/dealloc (out)
//   write_buffer  → wb_hit + wb_full (in), wb_push_en (out)

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
    // Hit detector (pre-qualified against status bits)
    // ----------------------------------------------------------------
    input  logic        true_hit,           // tag match on a VALID way
    input  logic        pending_hit,        // tag match on a PENDING way
    input  logic [1:0]  hit_way,
    input  logic [1:0]  pending_way,

    // ----------------------------------------------------------------
    // Write buffer — RAW forwarding + back-pressure
    // ----------------------------------------------------------------
    input  logic        wb_hit,             // forwarding match found
    input  logic        wb_full,            // write buffer saturated

    // ----------------------------------------------------------------
    // PLRU state store
    // ----------------------------------------------------------------
    input  logic [1:0]  victim_way,
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
    output logic [6:0]  mshr_dealloc_set,  // req_set forwarded to MSHR

    // ----------------------------------------------------------------
    // Main memory fill response (one-cycle pulse from MSHR)
    // ----------------------------------------------------------------
    input  logic        mm_rcvd,
    input  logic [1:0]  mm_rcvd_way,
    input  logic [6:0]  mm_rcvd_set,

    // ----------------------------------------------------------------
    // Write buffer push — FSM enables, decoder provides addr/data/id
    // ----------------------------------------------------------------
    output logic        wb_push_en,

    // ----------------------------------------------------------------
    // Response to CPU
    // ----------------------------------------------------------------
    output logic        resp_en,            // data ready (hit or forward)
    output logic        fwd_sel,            // 1=use wb_fwd_data, 0=cache data

    // ----------------------------------------------------------------
    // Status bits store — write port
    // ----------------------------------------------------------------
    output logic        status_wr_en,
    output logic [6:0]  status_wr_set,
    output logic [1:0]  status_wr_way,
    output logic [1:0]  status_wr_data,

    // ----------------------------------------------------------------
    // Tag store — write port control
    // (write_index and new_tag wired from decoder at top level)
    // ----------------------------------------------------------------
    output logic        tag_wr_en,
    output logic [1:0]  tag_wr_way,

    // ----------------------------------------------------------------
    // Data store — write enables
    // ----------------------------------------------------------------
    output logic        cpu_data_wr_en,     // write hit  → CPU data → cache
    output logic        fill_data_wr_en     // mm_rcvd    → MM data  → cache
);

    localparam logic [1:0] INVALID = 2'b00;
    localparam logic [1:0] VALID   = 2'b01;
    localparam logic [1:0] PENDING = 2'b10;

    typedef enum logic { IDLE, STALL } fsm_t;
    fsm_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        // ---- safe defaults -------------------------------------------
        next_state         = state;
        stall              = 1'b0;
        resp_en            = 1'b0;
        fwd_sel            = 1'b0;
        plru_update_en     = 1'b0;
        plru_accessed_way  = 2'd0;
        mshr_alloc_en      = 1'b0;
        mshr_alloc_way     = 2'd0;
        mshr_dealloc_en    = 1'b0;
        mshr_dealloc_way   = 2'd0;
        mshr_dealloc_set   = 7'd0;
        wb_push_en         = 1'b0;
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
                        // Priority: true_hit > wb_hit > miss
                        // ------------------------------------------
                        if (true_hit) begin
                            resp_en           = 1'b1;
                            plru_update_en    = 1'b1;
                            plru_accessed_way = hit_way;

                        end else if (wb_hit) begin
                            // RAW forward: return write-buffer data
                            resp_en = 1'b1;
                            fwd_sel = 1'b1;
                            // No cache allocation, no PLRU update

                        end else begin
                            // True cache miss (includes pending_hit)
                            if (mshr_full) begin
                                stall      = 1'b1;
                                next_state = STALL;

                            end else if (mm_rcvd) begin
                                // Status write port busy; defer one cycle
                                stall = 1'b1;

                            end else begin
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
                        if (wb_full) begin
                            stall = 1'b1;   // back-pressure from WB

                        end else begin
                            wb_push_en = 1'b1;  // push to write buffer

                            if (true_hit) begin
                                cpu_data_wr_en    = 1'b1;
                                plru_update_en    = 1'b1;
                                plru_accessed_way = hit_way;

                            end else if (pending_hit) begin
                                // Cancel in-flight fill to prevent
                                // stale MM data overwriting our write
                                mshr_dealloc_en  = 1'b1;
                                mshr_dealloc_way = pending_way;
                                mshr_dealloc_set = req_set;
                                status_wr_en     = 1'b1;
                                status_wr_set    = req_set;
                                status_wr_way    = pending_way;
                                status_wr_data   = INVALID;
                            end
                            // Write miss: push only, no cache action
                        end
                    end
                end
            end

            // ==========================================================
            // STALL: all signals stable (pipeline frozen).
            // Retry when MSHR has space AND status write port is free.
            // ==========================================================
            STALL: begin
                stall = 1'b1;

                if (!mshr_full && !mm_rcvd) begin
                    next_state     = IDLE;
                    stall          = 1'b0;
                    mshr_alloc_en  = 1'b1;
                    mshr_alloc_way = victim_way;
                    tag_wr_en      = 1'b1;
                    tag_wr_way     = victim_way;
                    status_wr_en   = 1'b1;
                    status_wr_set  = req_set;
                    status_wr_way  = victim_way;
                    status_wr_data = PENDING;
                end
            end

        endcase

        // ==============================================================
        // mm_rcvd — placed AFTER case so these override the case outputs.
        // fill_data_wr_en is safe alongside cpu_data_wr_en: PENDING vs
        // VALID ways are always distinct.
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
