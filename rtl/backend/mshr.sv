module mshr #(
    parameter int NUM_ENTRIES  = 4,
    parameter int TAG_W        = 22,
    parameter int AXI_ADDR_W   = 32,
    parameter int AXI_DATA_W   = 64,
    parameter int AXI_ID_W     = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic                  alloc_en,
    input  logic [1:0]            alloc_way,
    input  logic [6:0]            alloc_set,
    input  logic [TAG_W-1:0]      alloc_tag,
    input  logic [AXI_ID_W-1:0]   alloc_id,

    input  logic                  dealloc_en,
    input  logic [1:0]            dealloc_way,
    input  logic [6:0]            dealloc_set,

    output logic                  mshr_full,

    output logic                  mm_rcvd,
    output logic [1:0]            mm_rcvd_way,
    output logic [6:0]            mm_rcvd_set,
    output logic [AXI_ID_W-1:0]   mm_rcvd_id,

    output logic [AXI_DATA_W-1:0] fill_data,

    output logic [AXI_ADDR_W-1:0] m_axi_araddr,
    output logic                  m_axi_arvalid,
    output logic [AXI_ID_W-1:0]   m_axi_arid,
    output logic [7:0]            m_axi_arlen,
    output logic [2:0]            m_axi_arsize,
    output logic [1:0]            m_axi_arburst,
    input  logic                  m_axi_arready,

    input  logic [AXI_DATA_W-1:0] m_axi_rdata,
    input  logic                  m_axi_rvalid,
    input  logic [AXI_ID_W-1:0]   m_axi_rid,
    input  logic                  m_axi_rlast,
    output logic                  m_axi_rready
);

    logic              valid  [NUM_ENTRIES-1:0];
    logic              zombie [NUM_ENTRIES-1:0];
    logic              ar_sent[NUM_ENTRIES-1:0];
    logic [1:0]        e_way  [NUM_ENTRIES-1:0];
    logic [6:0]        e_set  [NUM_ENTRIES-1:0];
    logic [TAG_W-1:0]  e_tag  [NUM_ENTRIES-1:0];
    logic [AXI_ID_W-1:0] e_id [NUM_ENTRIES-1:0];

    logic [1:0] free_idx;
    always_comb begin
        free_idx = 2'd0;
        for (int i = NUM_ENTRIES-1; i >= 0; i--)
            if (!valid[i] && !zombie[i]) free_idx = 2'(i);
    end

    assign mshr_full = &{ (valid[3]|zombie[3]),
                          (valid[2]|zombie[2]),
                          (valid[1]|zombie[1]),
                          (valid[0]|zombie[0]) };

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

    assign m_axi_arvalid = ar_pending;
    assign m_axi_araddr  = { e_tag[ar_idx], e_set[ar_idx], 3'b000 };
    assign m_axi_arid    = AXI_ID_W'(ar_idx);
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'b011;
    assign m_axi_arburst = 2'b01;
    assign m_axi_rready  = 1'b1;

    logic [1:0] rcvd_idx;
    assign rcvd_idx = m_axi_rid[1:0];

    assign mm_rcvd     = m_axi_rvalid && m_axi_rlast &&  valid[rcvd_idx]
                                                      && !zombie[rcvd_idx];
    assign mm_rcvd_way = e_way[rcvd_idx];
    assign mm_rcvd_set = e_set[rcvd_idx];
    assign mm_rcvd_id  = e_id [rcvd_idx];
    assign fill_data   = m_axi_rdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                valid  [i] <= 1'b0;
                zombie [i] <= 1'b0;
                ar_sent[i] <= 1'b0;
                e_way  [i] <= 2'd0;
                e_set  [i] <= 7'd0;
                e_tag  [i] <= '0;
                e_id   [i] <= '0;
            end
        end else begin
            if (alloc_en) begin
                valid  [free_idx] <= 1'b1;
                ar_sent[free_idx] <= 1'b0;
                e_way  [free_idx] <= alloc_way;
                e_set  [free_idx] <= alloc_set;
                e_tag  [free_idx] <= alloc_tag;
                e_id   [free_idx] <= alloc_id;
            end

            if (m_axi_arvalid && m_axi_arready)
                ar_sent[ar_idx] <= 1'b1;

            for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (dealloc_en && valid[i]
                    && e_way[i] == dealloc_way
                    && e_set[i] == dealloc_set)
                begin
                    valid[i] <= 1'b0;
                    if (ar_sent[i])
                        zombie[i] <= 1'b1;
                end
            end

            if (m_axi_rvalid && m_axi_rlast) begin
                valid  [rcvd_idx] <= 1'b0;
                zombie [rcvd_idx] <= 1'b0;
                ar_sent[rcvd_idx] <= 1'b0;
            end
        end
    end

endmodule
