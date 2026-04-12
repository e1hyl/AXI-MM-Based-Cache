// Data Store
//
// Stores the 64-bit cache line data for all sets and ways.
//
// Two independent write ports:
//   cpu_wr  — write hit path: CPU data (drWDATA) written to a VALID way
//   fill_wr — fill path: MM data (mRDATA) written to a PENDING way on mm_rcvd
//
// In normal operation these always target different ways (VALID vs PENDING),
// so there is no conflict. fill_wr is listed last in always_ff and wins if
// both ever address the same slot.
//
// Read port is combinational. An internal mux selects the way indicated by
// hit_way_index from the hit_detector, producing caRDATA.

module data_store #(
    parameter int SET_INDEX = 128,
    parameter int SET_WAY   = 4,
    parameter int DATA_W    = 64    // matches AXI_DATA_WIDTH
)(
    input  logic clk,

    // ----------------------------------------------------------------
    // Read port — combinational
    // rd_way comes from hit_detector's hit_way_index
    // ----------------------------------------------------------------
    input  logic [6:0]         rd_index,
    input  logic [1:0]         rd_way,
    output logic [DATA_W-1:0]  rd_data,     // caRDATA

    // ----------------------------------------------------------------
    // CPU write port — asserted on write hit (VALID way)
    // cpu_wr_data = drWDATA from decoder
    // ----------------------------------------------------------------
    input  logic               cpu_wr_en,
    input  logic [6:0]         cpu_wr_index,
    input  logic [1:0]         cpu_wr_way,
    input  logic [DATA_W-1:0]  cpu_wr_data,

    // ----------------------------------------------------------------
    // Fill write port — asserted on mm_rcvd (PENDING way)
    // fill_wr_data = mRDATA from main memory
    // ----------------------------------------------------------------
    input  logic               fill_wr_en,
    input  logic [6:0]         fill_wr_index,
    input  logic [1:0]         fill_wr_way,
    input  logic [DATA_W-1:0]  fill_wr_data
);

    logic [DATA_W-1:0] data_array [SET_INDEX-1:0][SET_WAY-1:0];

    always_ff @(posedge clk) begin
        if (cpu_wr_en)
            data_array[cpu_wr_index][cpu_wr_way] <= cpu_wr_data;
        if (fill_wr_en)     // listed last: wins on same-slot conflict
            data_array[fill_wr_index][fill_wr_way] <= fill_wr_data;
    end

    // Internal read mux: select the way matching the hit
    assign rd_data = data_array[rd_index][rd_way];

endmodule
