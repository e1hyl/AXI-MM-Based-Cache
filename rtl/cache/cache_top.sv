`timescale 1ns / 1ps

module cache_top #(
    parameter int AXI_ADDR_W = 32,
    parameter int AXI_DATA_W = 64,
    parameter int AXI_ID_W   = 4,
    parameter int FIFO_DEPTH = 8,
    parameter int MEM_DEPTH  = 65536
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [AXI_ADDR_W-1:0]   s_axi_araddr,
    input  logic                     s_axi_arvalid,
    input  logic [AXI_ID_W-1:0]     s_axi_arid,
    input  logic [1:0]               s_axi_arburst,
    input  logic [2:0]               s_axi_arsize,
    input  logic [7:0]               s_axi_arlen,
    output logic                     s_axi_arready,

    output logic [AXI_DATA_W-1:0]   s_axi_rdata,
    output logic                     s_axi_rvalid,
    output logic [AXI_ID_W-1:0]     s_axi_rid,
    output logic                     s_axi_rlast,
    input  logic                     s_axi_rready,

    input  logic [AXI_ADDR_W-1:0]   s_axi_awaddr,
    input  logic                     s_axi_awvalid,
    input  logic [AXI_ID_W-1:0]     s_axi_awid,
    input  logic [1:0]               s_axi_awburst,
    input  logic [2:0]               s_axi_awsize,
    input  logic [7:0]               s_axi_awlen,
    output logic                     s_axi_awready,

    input  logic [AXI_DATA_W-1:0]   s_axi_wdata,
    input  logic [AXI_DATA_W/8-1:0] s_axi_wstrb,
    input  logic                     s_axi_wvalid,
    input  logic                     s_axi_wlast,
    output logic                     s_axi_wready,

    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    output logic [AXI_ID_W-1:0]     s_axi_bid,
    input  logic                     s_axi_bready
);

    localparam int R_WIDTH = AXI_ADDR_W + AXI_ID_W + 2 + 3 + 8;
    localparam int W_WIDTH = AXI_ADDR_W + AXI_ID_W + 2 + 3 + 8
                           + AXI_DATA_W + AXI_DATA_W/8;

    logic                  rf_full, rf_empty;
    logic                  rf_pop_valid;
    logic                  arb_r_ready;
    logic [R_WIDTH-1:0]    rf_pop_data;

    logic                  wf_full, wf_empty;
    logic                  wf_pop_valid;
    logic                  arb_w_ready;
    logic [W_WIDTH-1:0]    wf_pop_data;

    logic wf_push_en;
    assign wf_push_en    = s_axi_awvalid && s_axi_wvalid && !wf_full;
    assign s_axi_awready = !wf_full;
    assign s_axi_wready  = !wf_full;

    logic [W_WIDTH-1:0]    arb_out_data;
    logic                  arb_out_valid;
    logic                  arb_row;

    logic [AXI_ADDR_W-1:0]   req_addr;
    logic [AXI_ID_W-1:0]     req_id;
    logic [AXI_DATA_W-1:0]   req_wdata;
    logic [AXI_DATA_W/8-1:0] req_wstrb;
    logic [21:0]              req_tag;
    logic [6:0]               req_set;

    always_comb begin
        if (arb_row) begin
            req_addr  = arb_out_data[120:89];
            req_id    = arb_out_data[88:85];
            req_wdata = arb_out_data[71:8];
            req_wstrb = arb_out_data[7:0];
        end else begin
            req_addr  = arb_out_data[48:17];
            req_id    = arb_out_data[16:13];
            req_wdata = '0;
            req_wstrb = '0;
        end
        req_tag = req_addr[31:10];
        req_set = req_addr[9:3];
    end

    logic [21:0] ts_tag0, ts_tag1, ts_tag2, ts_tag3;
    logic [1:0]  ss_way0, ss_way1, ss_way2, ss_way3;

    logic        hd_hit, hd_pending_hit;
    logic [1:0]  hd_hit_way, hd_pending_way;

    logic [1:0]  plru_victim_way;
    logic        plru_update_en;
    logic [1:0]  plru_accessed_way;

    logic        stall;
    logic        resp_en, fwd_sel;
    logic        wb_push_en;
    logic        status_wr_en;
    logic [6:0]  status_wr_set;
    logic [1:0]  status_wr_way;
    logic [1:0]  status_wr_data;
    logic        tag_wr_en;
    logic [1:0]  tag_wr_way;
    logic        cpu_data_wr_en;
    logic        fill_data_wr_en;
    logic        mshr_alloc_en;
    logic [1:0]  mshr_alloc_way;
    logic        mshr_dealloc_en;
    logic [1:0]  mshr_dealloc_way;
    logic [6:0]  mshr_dealloc_set;
    logic        pending_resolved;

    logic        mshr_full;
    logic        mm_rcvd;
    logic [1:0]  mm_rcvd_way;
    logic [6:0]  mm_rcvd_set;
    logic [AXI_ID_W-1:0]   mm_rcvd_id;
    logic [AXI_DATA_W-1:0] fill_data;

    logic [AXI_ADDR_W-1:0] mshr_araddr;
    logic                   mshr_arvalid;
    logic [AXI_ID_W-1:0]   mshr_arid;
    logic [7:0]             mshr_arlen;
    logic [2:0]             mshr_arsize;
    logic [1:0]             mshr_arburst;
    logic                   mm_arready;
    logic [AXI_DATA_W-1:0] mm_rdata;
    logic                   mm_rvalid;
    logic [AXI_ID_W-1:0]   mm_rid;
    logic                   mm_rlast;
    logic                   mshr_rready;

    logic        wb_full;
    logic        wb_hit;
    logic [AXI_DATA_W-1:0] wb_fwd_data;

    logic [AXI_ADDR_W-1:0]   wbuf_awaddr;
    logic                     wbuf_awvalid;
    logic [AXI_ID_W-1:0]     wbuf_awid;
    logic [7:0]               wbuf_awlen;
    logic [2:0]               wbuf_awsize;
    logic [1:0]               wbuf_awburst;
    logic                     mm_awready;
    logic [AXI_DATA_W-1:0]   wbuf_wdata;
    logic [AXI_DATA_W/8-1:0] wbuf_wstrb;
    logic                     wbuf_wvalid;
    logic                     wbuf_wlast;
    logic                     mm_wready;
    logic [1:0]               mm_bresp;
    logic                     mm_bvalid;
    logic [AXI_ID_W-1:0]     mm_bid;
    logic                     wbuf_bready;

    logic [1:0]           wb_cpu_bresp;
    logic                 wb_cpu_bvalid;
    logic [AXI_ID_W-1:0] wb_cpu_bid;

    logic [AXI_DATA_W-1:0] ds_rd_data;

    logic out_ready;
    assign out_ready = resp_en | wb_push_en | mshr_alloc_en | pending_resolved;

    logic                   rresp_valid;
    logic [AXI_DATA_W-1:0]  rresp_data;
    logic [AXI_ID_W-1:0]    rresp_id;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rresp_valid <= 1'b0;
            rresp_data  <= '0;
            rresp_id    <= '0;
        end else begin
            if (rresp_valid && s_axi_rready) begin
                rresp_valid <= 1'b0;
            end else if (resp_en && !arb_row) begin
                rresp_valid <= 1'b1;
                rresp_data  <= fwd_sel ? wb_fwd_data : ds_rd_data;
                rresp_id    <= req_id;
            end else if (pending_resolved) begin
                rresp_valid <= 1'b1;
                rresp_data  <= fill_data;
                rresp_id    <= req_id;
            end
        end
    end

    localparam int FQ_DEPTH = 4;
    logic [AXI_DATA_W+AXI_ID_W-1:0] fq_mem [FQ_DEPTH];
    logic [1:0] fq_wptr, fq_rptr;
    logic [2:0] fq_cnt;
    logic       fq_valid, fq_push, fq_pop;

    assign fq_valid = (fq_cnt != '0);
    assign fq_push  = mm_rcvd;
    assign fq_pop   = fq_valid && !rresp_valid && s_axi_rready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fq_wptr <= '0;
            fq_rptr <= '0;
            fq_cnt  <= '0;
            for (int i = 0; i < FQ_DEPTH; i++) fq_mem[i] <= '0;
        end else begin
            if (fq_push) begin
                fq_mem[fq_wptr] <= {mm_rcvd_id, fill_data};
                fq_wptr         <= fq_wptr + 1'b1;
            end
            if (fq_pop)
                fq_rptr <= fq_rptr + 1'b1;
            fq_cnt <= fq_cnt + fq_push - fq_pop;
        end
    end

    assign s_axi_rvalid = rresp_valid || fq_valid;
    assign s_axi_rdata  = rresp_valid ? rresp_data
                                      : fq_mem[fq_rptr][AXI_DATA_W-1:0];
    assign s_axi_rid    = rresp_valid ? rresp_id
                                      : fq_mem[fq_rptr][AXI_DATA_W+:AXI_ID_W];
    assign s_axi_rlast  = 1'b1;

    assign s_axi_bvalid = wb_cpu_bvalid;
    assign s_axi_bid    = wb_cpu_bid;
    assign s_axi_bresp  = wb_cpu_bresp;

    read_fifo #(
        .ADDR_WIDTH (AXI_ADDR_W),
        .ID_WIDTH   (AXI_ID_W),
        .DEPTH      (FIFO_DEPTH)
    ) u_rfifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .araddr       (s_axi_araddr),
        .arid         (s_axi_arid),
        .arburst      (s_axi_arburst),
        .arsize       (s_axi_arsize),
        .arlen        (s_axi_arlen),
        .push_arvalid (s_axi_arvalid),
        .push_arready (s_axi_arready),
        .pop_arvalid  (rf_pop_valid),
        .pop_arready  (arb_r_ready),
        .pop_data     (rf_pop_data),
        .full         (rf_full),
        .empty        (rf_empty)
    );

    write_fifo #(
        .ADDR_WIDTH (AXI_ADDR_W),
        .DATA_WIDTH (AXI_DATA_W),
        .ID_WIDTH   (AXI_ID_W),
        .DEPTH      (FIFO_DEPTH)
    ) u_wfifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .awaddr       (s_axi_awaddr),
        .awid         (s_axi_awid),
        .awburst      (s_axi_awburst),
        .awsize       (s_axi_awsize),
        .awlen        (s_axi_awlen),
        .wdata        (s_axi_wdata),
        .wstrb        (s_axi_wstrb),
        .push_awvalid (wf_push_en),
        .push_awready (),
        .pop_awvalid  (wf_pop_valid),
        .pop_awready  (arb_w_ready),
        .pop_data     (wf_pop_data),
        .full         (wf_full),
        .empty        (wf_empty)
    );

    rr_arbiter #(
        .ADDR_WIDTH (AXI_ADDR_W),
        .DATA_WIDTH (AXI_DATA_W),
        .ID_WIDTH   (AXI_ID_W),
        .DEPTH      (FIFO_DEPTH)
    ) u_arbiter (
        .clk           (clk),
        .rst           (rst_n),
        .rdata         (rf_pop_data),
        .wdata         (wf_pop_data),
        .r_valid       (rf_pop_valid),
        .w_valid       (wf_pop_valid),
        .out_ready     (out_ready),
        .out_data      (arb_out_data),
        .out_valid     (arb_out_valid),
        .read_or_write (arb_row),
        .r_ready       (arb_r_ready),
        .w_ready       (arb_w_ready)
    );

    tag_store u_tag (
        .clk         (clk),
        .index       (req_set),
        .write_en    (tag_wr_en),
        .write_index (req_set),
        .target_way  (tag_wr_way),
        .new_tag     (req_tag),
        .tags_out_0  (ts_tag0),
        .tags_out_1  (ts_tag1),
        .tags_out_2  (ts_tag2),
        .tags_out_3  (ts_tag3)
    );

    status_bits_store u_status (
        .clk          (clk),
        .rst_n        (rst_n),
        .rd_index     (req_set),
        .way_0_status (ss_way0),
        .way_1_status (ss_way1),
        .way_2_status (ss_way2),
        .way_3_status (ss_way3),
        .wr_en        (status_wr_en),
        .wr_index     (status_wr_set),
        .wr_way       (status_wr_way),
        .new_status   (status_wr_data)
    );

    hit_detector u_hit (
        .incoming_tag      (req_tag),
        .tags_out_0        (ts_tag0),
        .tags_out_1        (ts_tag1),
        .tags_out_2        (ts_tag2),
        .tags_out_3        (ts_tag3),
        .way_0_status      (ss_way0),
        .way_1_status      (ss_way1),
        .way_2_status      (ss_way2),
        .way_3_status      (ss_way3),
        .hit               (hd_hit),
        .pending_hit       (hd_pending_hit),
        .hit_way_index     (hd_hit_way),
        .pending_way_index (hd_pending_way)
    );

    plru_state_store u_plru (
        .clk          (clk),
        .rst_n        (rst_n),
        .index        (req_set),
        .update_en    (plru_update_en),
        .accessed_way (plru_accessed_way),
        .victim_way   (plru_victim_way)
    );

    data_store u_data (
        .clk          (clk),
        .rd_index     (req_set),
        .rd_way       (hd_hit_way),
        .rd_data      (ds_rd_data),
        .cpu_wr_en    (cpu_data_wr_en),
        .cpu_wr_index (req_set),
        .cpu_wr_way   (hd_hit_way),
        .cpu_wr_data  (req_wdata),
        .fill_wr_en   (fill_data_wr_en),
        .fill_wr_index(mm_rcvd_set),
        .fill_wr_way  (mm_rcvd_way),
        .fill_wr_data (fill_data)
    );

    control_fsm u_fsm (
        .clk               (clk),
        .rst_n             (rst_n),
        .req_valid         (arb_out_valid),
        .req_type          (arb_row),
        .req_set           (req_set),
        .stall             (stall),
        .true_hit          (hd_hit),
        .pending_hit       (hd_pending_hit),
        .hit_way           (hd_hit_way),
        .pending_way       (hd_pending_way),
        .wb_hit            (wb_hit),
        .wb_full           (wb_full),
        .victim_way        (plru_victim_way),
        .plru_update_en    (plru_update_en),
        .plru_accessed_way (plru_accessed_way),
        .mshr_full         (mshr_full),
        .mshr_alloc_en     (mshr_alloc_en),
        .mshr_alloc_way    (mshr_alloc_way),
        .mshr_dealloc_en   (mshr_dealloc_en),
        .mshr_dealloc_way  (mshr_dealloc_way),
        .mshr_dealloc_set  (mshr_dealloc_set),
        .mm_rcvd           (mm_rcvd),
        .mm_rcvd_way       (mm_rcvd_way),
        .mm_rcvd_set       (mm_rcvd_set),
        .wb_push_en        (wb_push_en),
        .resp_en           (resp_en),
        .fwd_sel           (fwd_sel),
        .status_wr_en      (status_wr_en),
        .status_wr_set     (status_wr_set),
        .status_wr_way     (status_wr_way),
        .status_wr_data    (status_wr_data),
        .tag_wr_en         (tag_wr_en),
        .tag_wr_way        (tag_wr_way),
        .cpu_data_wr_en    (cpu_data_wr_en),
        .fill_data_wr_en   (fill_data_wr_en),
        .pending_resolved  (pending_resolved)
    );

    mshr u_mshr (
        .clk          (clk),
        .rst_n        (rst_n),
        .alloc_en     (mshr_alloc_en),
        .alloc_way    (mshr_alloc_way),
        .alloc_set    (req_set),
        .alloc_tag    (req_tag),
        .alloc_id     (req_id),
        .dealloc_en   (mshr_dealloc_en),
        .dealloc_way  (mshr_dealloc_way),
        .dealloc_set  (mshr_dealloc_set),
        .mshr_full    (mshr_full),
        .mm_rcvd      (mm_rcvd),
        .mm_rcvd_way  (mm_rcvd_way),
        .mm_rcvd_set  (mm_rcvd_set),
        .mm_rcvd_id   (mm_rcvd_id),
        .fill_data    (fill_data),
        .m_axi_araddr  (mshr_araddr),
        .m_axi_arvalid (mshr_arvalid),
        .m_axi_arid    (mshr_arid),
        .m_axi_arlen   (mshr_arlen),
        .m_axi_arsize  (mshr_arsize),
        .m_axi_arburst (mshr_arburst),
        .m_axi_arready (mm_arready),
        .m_axi_rdata   (mm_rdata),
        .m_axi_rvalid  (mm_rvalid),
        .m_axi_rid     (mm_rid),
        .m_axi_rlast   (mm_rlast),
        .m_axi_rready  (mshr_rready)
    );

    write_buffer #(
        .DEPTH      (FIFO_DEPTH),
        .AXI_ADDR_W (AXI_ADDR_W),
        .AXI_DATA_W (AXI_DATA_W),
        .AXI_ID_W   (AXI_ID_W)
    ) u_wbuf (
        .clk           (clk),
        .rst_n         (rst_n),
        .push_en       (wb_push_en),
        .push_addr     (req_addr),
        .push_data     (req_wdata),
        .push_id       (req_id),
        .full          (wb_full),
        .rd_addr       (req_addr),
        .wb_hit        (wb_hit),
        .wb_fwd_data   (wb_fwd_data),
        .m_axi_awaddr  (wbuf_awaddr),
        .m_axi_awvalid (wbuf_awvalid),
        .m_axi_awid    (wbuf_awid),
        .m_axi_awlen   (wbuf_awlen),
        .m_axi_awsize  (wbuf_awsize),
        .m_axi_awburst (wbuf_awburst),
        .m_axi_awready (mm_awready),
        .m_axi_wdata   (wbuf_wdata),
        .m_axi_wstrb   (wbuf_wstrb),
        .m_axi_wvalid  (wbuf_wvalid),
        .m_axi_wlast   (wbuf_wlast),
        .m_axi_wready  (mm_wready),
        .m_axi_bresp   (mm_bresp),
        .m_axi_bvalid  (mm_bvalid),
        .m_axi_bid     (mm_bid),
        .m_axi_bready  (wbuf_bready),
        .cpu_bresp     (wb_cpu_bresp),
        .cpu_bvalid    (wb_cpu_bvalid),
        .cpu_bid       (wb_cpu_bid)
    );

    main_memory #(
        .AXI_ADDR_W (AXI_ADDR_W),
        .AXI_DATA_W (AXI_DATA_W),
        .AXI_ID_W   (AXI_ID_W),
        .MEM_DEPTH  (MEM_DEPTH)
    ) u_mm (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axi_araddr  (mshr_araddr),
        .s_axi_arvalid (mshr_arvalid),
        .s_axi_arid    (mshr_arid),
        .s_axi_arready (mm_arready),
        .s_axi_rdata   (mm_rdata),
        .s_axi_rvalid  (mm_rvalid),
        .s_axi_rid     (mm_rid),
        .s_axi_rlast   (mm_rlast),
        .s_axi_rready  (mshr_rready),
        .s_axi_awaddr  (wbuf_awaddr),
        .s_axi_awvalid (wbuf_awvalid),
        .s_axi_awid    (wbuf_awid),
        .s_axi_awready (mm_awready),
        .s_axi_wdata   (wbuf_wdata),
        .s_axi_wstrb   (wbuf_wstrb),
        .s_axi_wvalid  (wbuf_wvalid),
        .s_axi_wlast   (wbuf_wlast),
        .s_axi_wready  (mm_wready),
        .s_axi_bresp   (mm_bresp),
        .s_axi_bvalid  (mm_bvalid),
        .s_axi_bid     (mm_bid),
        .s_axi_bready  (wbuf_bready)
    );

endmodule
