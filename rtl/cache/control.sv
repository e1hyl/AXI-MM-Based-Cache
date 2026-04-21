module control_fsm #(
    parameter int SET_INDEX = 128,
    parameter int SET_WAY   = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic        req_valid,
    input  logic        req_type,
    input  logic [6:0]  req_set,
    output logic        stall,

    input  logic        true_hit,
    input  logic        pending_hit,
    input  logic [1:0]  hit_way,
    input  logic [1:0]  pending_way,

    input  logic        wb_hit,
    input  logic        wb_full,

    input  logic [1:0]  victim_way,
    output logic        plru_update_en,
    output logic [1:0]  plru_accessed_way,

    input  logic        mshr_full,
    output logic        mshr_alloc_en,
    output logic [1:0]  mshr_alloc_way,
    output logic        mshr_dealloc_en,
    output logic [1:0]  mshr_dealloc_way,
    output logic [6:0]  mshr_dealloc_set,

    input  logic        mm_rcvd,
    input  logic [1:0]  mm_rcvd_way,
    input  logic [6:0]  mm_rcvd_set,

    output logic        wb_push_en,

    output logic        resp_en,
    output logic        fwd_sel,

    output logic        status_wr_en,
    output logic [6:0]  status_wr_set,
    output logic [1:0]  status_wr_way,
    output logic [1:0]  status_wr_data,

    output logic        tag_wr_en,
    output logic [1:0]  tag_wr_way,

    output logic        cpu_data_wr_en,
    output logic        fill_data_wr_en,

    output logic        pending_resolved
);

    localparam logic [1:0] INVALID = 2'b00;
    localparam logic [1:0] VALID   = 2'b01;
    localparam logic [1:0] PENDING = 2'b10;

    typedef enum logic [1:0] { IDLE, WAIT_PENDING, STALL_FULL } fsm_t;
    fsm_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
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
        pending_resolved   = 1'b0;

        case (state)

            IDLE: begin
                if (req_valid) begin

                    if (!req_type) begin
                        if (wb_hit) begin
                            resp_en = 1'b1;
                            fwd_sel = 1'b1;

                        end else if (true_hit) begin
                            resp_en           = 1'b1;
                            plru_update_en    = 1'b1;
                            plru_accessed_way = hit_way;

                        end else if (pending_hit) begin
                            if (mm_rcvd && mm_rcvd_set == req_set) begin
                                pending_resolved = 1'b1;
                            end else begin
                                stall      = 1'b1;
                                next_state = WAIT_PENDING;
                            end

                        end else begin
                            if (mshr_full) begin
                                stall      = 1'b1;
                                next_state = STALL_FULL;

                            end else if (mm_rcvd) begin
                                stall = 1'b1;

                            end else begin
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

                    end else begin
                        if (wb_full) begin
                            stall = 1'b1;

                        end else begin
                            wb_push_en = 1'b1;

                            if (true_hit) begin
                                cpu_data_wr_en    = 1'b1;
                                plru_update_en    = 1'b1;
                                plru_accessed_way = hit_way;

                            end else if (pending_hit) begin
                                mshr_dealloc_en  = 1'b1;
                                mshr_dealloc_way = pending_way;
                                mshr_dealloc_set = req_set;
                                status_wr_en     = 1'b1;
                                status_wr_set    = req_set;
                                status_wr_way    = pending_way;
                                status_wr_data   = INVALID;
                            end
                        end
                    end
                end
            end

            WAIT_PENDING: begin
                stall = 1'b1;
                if (mm_rcvd && mm_rcvd_set == req_set) begin
                    next_state       = IDLE;
                    stall            = 1'b0;
                    pending_resolved = 1'b1;
                end
            end

            STALL_FULL: begin
                stall = 1'b1;
                if (!mshr_full && !mm_rcvd) begin
                    next_state     = IDLE;
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

        if (mm_rcvd) begin
            status_wr_en    = 1'b1;
            status_wr_set   = mm_rcvd_set;
            status_wr_way   = mm_rcvd_way;
            status_wr_data  = VALID;
            fill_data_wr_en = 1'b1;
        end

    end

endmodule
