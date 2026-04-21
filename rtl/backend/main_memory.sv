module main_memory #(
    parameter int AXI_ADDR_W = 32,
    parameter int AXI_DATA_W = 64,
    parameter int AXI_ID_W   = 4,
    parameter int MEM_DEPTH  = 65536
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [AXI_ADDR_W-1:0]   s_axi_araddr,
    input  logic                    s_axi_arvalid,
    input  logic [AXI_ID_W-1:0]     s_axi_arid,
    output logic                    s_axi_arready,

    output logic [AXI_DATA_W-1:0]   s_axi_rdata,
    output logic                    s_axi_rvalid,
    output logic [AXI_ID_W-1:0]     s_axi_rid,
    output logic                    s_axi_rlast,
    input  logic                    s_axi_rready,

    input  logic [AXI_ADDR_W-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    input  logic [AXI_ID_W-1:0]     s_axi_awid,
    output logic                    s_axi_awready,

    input  logic [AXI_DATA_W-1:0]   s_axi_wdata,
    input  logic [AXI_DATA_W/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    input  logic                    s_axi_wlast,
    output logic                    s_axi_wready,

    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    output logic [AXI_ID_W-1:0]     s_axi_bid,
    input  logic                    s_axi_bready
);

    localparam int IDX_W = $clog2(MEM_DEPTH);

    logic [AXI_DATA_W-1:0] mem [MEM_DEPTH-1:0];

    function automatic logic [IDX_W-1:0] word_idx(input logic [AXI_ADDR_W-1:0] addr);
        return addr[IDX_W+2:3];
    endfunction

    assign s_axi_arready = 1'b1;

    logic                  r_valid_r;
    logic [AXI_DATA_W-1:0] r_data_r;
    logic [AXI_ID_W-1:0]   r_id_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_valid_r <= 1'b0;
            r_data_r  <= '0;
            r_id_r    <= '0;
        end else begin
            if (s_axi_rvalid && s_axi_rready)
                r_valid_r <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                r_valid_r <= 1'b1;
                r_data_r  <= mem[word_idx(s_axi_araddr)];
                r_id_r    <= s_axi_arid;
            end
        end
    end

    assign s_axi_rvalid = r_valid_r;
    assign s_axi_rdata  = r_data_r;
    assign s_axi_rid    = r_id_r;
    assign s_axi_rlast  = r_valid_r;

    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;

    logic                    aw_pend;
    logic [AXI_ADDR_W-1:0]   aw_addr_r;
    logic [AXI_ID_W-1:0]     aw_id_r;

    logic                    w_pend;
    logic [AXI_DATA_W-1:0]   w_data_r;
    logic [AXI_DATA_W/8-1:0] w_strb_r;

    logic              b_valid_r;
    logic [AXI_ID_W-1:0] b_id_r;

    logic                    c_this_aw, c_this_w;
    logic [AXI_ADDR_W-1:0]   c_commit_addr;
    logic [AXI_DATA_W-1:0]   c_commit_data;
    logic [AXI_DATA_W/8-1:0] c_commit_strb;
    logic [AXI_ID_W-1:0]     c_commit_id;

    always_comb begin
        c_this_aw     = aw_pend || (s_axi_awvalid && s_axi_awready);
        c_this_w      = w_pend  || (s_axi_wvalid  && s_axi_wready);
        c_commit_addr = aw_pend ? aw_addr_r : s_axi_awaddr;
        c_commit_data = w_pend  ? w_data_r  : s_axi_wdata;
        c_commit_strb = w_pend  ? w_strb_r  : s_axi_wstrb;
        c_commit_id   = aw_pend ? aw_id_r   : s_axi_awid;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_pend   <= 1'b0;
            aw_addr_r <= '0;
            aw_id_r   <= '0;
            w_pend    <= 1'b0;
            w_data_r  <= '0;
            w_strb_r  <= '0;
            b_valid_r <= 1'b0;
            b_id_r    <= '0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_pend   <= 1'b1;
                aw_addr_r <= s_axi_awaddr;
                aw_id_r   <= s_axi_awid;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_pend   <= 1'b1;
                w_data_r <= s_axi_wdata;
                w_strb_r <= s_axi_wstrb;
            end
            if (c_this_aw && c_this_w) begin
                for (int b = 0; b < AXI_DATA_W/8; b++) begin
                    if (c_commit_strb[b])
                        mem[word_idx(c_commit_addr)][b*8 +: 8] <= c_commit_data[b*8 +: 8];
                end
                aw_pend   <= 1'b0;
                w_pend    <= 1'b0;
                b_valid_r <= 1'b1;
                b_id_r    <= c_commit_id;
            end
            if (s_axi_bvalid && s_axi_bready)
                b_valid_r <= 1'b0;
        end
    end

    assign s_axi_bvalid = b_valid_r;
    assign s_axi_bid    = b_id_r;
    assign s_axi_bresp  = 2'b00;

endmodule
