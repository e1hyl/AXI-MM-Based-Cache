`timescale 1ns / 1ps

module cache_tb;

    localparam int CLK_HALF = 5;
    localparam int TIMEOUT  = 300;

    localparam logic [1:0] FSM_IDLE         = 2'b00;
    localparam logic [1:0] FSM_WAIT_PENDING = 2'b01;
    localparam logic [1:0] FSM_STALL_FULL   = 2'b10;

    logic clk, rst_n;

    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid;
    logic [3:0]  s_axi_arid;
    logic [1:0]  s_axi_arburst;
    logic [2:0]  s_axi_arsize;
    logic [7:0]  s_axi_arlen;
    logic        s_axi_arready;

    logic [63:0] s_axi_rdata;
    logic        s_axi_rvalid;
    logic [3:0]  s_axi_rid;
    logic        s_axi_rlast;
    logic        s_axi_rready;

    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid;
    logic [3:0]  s_axi_awid;
    logic [1:0]  s_axi_awburst;
    logic [2:0]  s_axi_awsize;
    logic [7:0]  s_axi_awlen;
    logic        s_axi_awready;

    logic [63:0] s_axi_wdata;
    logic [7:0]  s_axi_wstrb;
    logic        s_axi_wvalid;
    logic        s_axi_wlast;
    logic        s_axi_wready;

    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic [3:0]  s_axi_bid;
    logic        s_axi_bready;

    int pass_cnt, fail_cnt;

    cache_top #(
        .AXI_ADDR_W (32),
        .AXI_DATA_W (64),
        .AXI_ID_W   (4),
        .FIFO_DEPTH (8),
        .MEM_DEPTH  (65536)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arid     (s_axi_arid),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rid      (s_axi_rid),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rready   (s_axi_rready),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awid     (s_axi_awid),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bid      (s_axi_bid),
        .s_axi_bready   (s_axi_bready)
    );

    covergroup fsm_states_cg @(posedge clk);
        cp_state: coverpoint dut.u_fsm.state {
            bins idle         = {FSM_IDLE};
            bins wait_pending = {FSM_WAIT_PENDING};
            bins stall_full   = {FSM_STALL_FULL};
        }
    endgroup

    covergroup fsm_transitions_cg @(posedge clk);
        cp_idle_to_wait_pending: coverpoint
            (dut.u_fsm.state == FSM_IDLE &&
             dut.u_fsm.next_state == FSM_WAIT_PENDING) {
            bins trans = {1'b1};
        }
        cp_wait_pending_to_idle: coverpoint
            (dut.u_fsm.state == FSM_WAIT_PENDING &&
             dut.u_fsm.next_state == FSM_IDLE) {
            bins trans = {1'b1};
        }
        cp_idle_to_stall_full: coverpoint
            (dut.u_fsm.state == FSM_IDLE &&
             dut.u_fsm.next_state == FSM_STALL_FULL) {
            bins trans = {1'b1};
        }
        cp_stall_full_to_idle: coverpoint
            (dut.u_fsm.state == FSM_STALL_FULL &&
             dut.u_fsm.next_state == FSM_IDLE) {
            bins trans = {1'b1};
        }
    endgroup

    covergroup read_scenarios_cg @(posedge clk);
        cp_true_hit: coverpoint
            (dut.arb_out_valid && !dut.arb_row &&
             dut.hd_hit && !dut.wb_hit) {
            bins hit = {1'b1};
        }
        cp_wb_forward: coverpoint
            (dut.arb_out_valid && !dut.arb_row && dut.wb_hit) {
            bins fwd = {1'b1};
        }
        cp_miss_alloc: coverpoint (dut.mshr_alloc_en) {
            bins alloc = {1'b1};
        }
        cp_pending_hit: coverpoint
            (dut.arb_out_valid && !dut.arb_row &&
             dut.hd_pending_hit && !dut.wb_hit) {
            bins phit = {1'b1};
        }
        cp_mshr_full_stall: coverpoint
            (dut.arb_out_valid && !dut.arb_row && dut.mshr_full) {
            bins stall = {1'b1};
        }
    endgroup

    covergroup write_scenarios_cg @(posedge clk);
        cp_write_hit: coverpoint
            (dut.wb_push_en && dut.arb_row && dut.hd_hit) {
            bins hit = {1'b1};
        }
        cp_write_miss: coverpoint
            (dut.wb_push_en && dut.arb_row &&
             !dut.hd_hit && !dut.hd_pending_hit) {
            bins miss = {1'b1};
        }
        cp_write_to_pending: coverpoint (dut.mshr_dealloc_en) {
            bins dealloc = {1'b1};
        }
        cp_wb_full_stall: coverpoint
            (dut.arb_out_valid && dut.arb_row && dut.wb_full) {
            bins stall = {1'b1};
        }
    endgroup

    covergroup plru_victim_cg @(posedge clk);
        cp_victim: coverpoint dut.plru_victim_way {
            bins way0 = {2'd0};
            bins way1 = {2'd1};
            bins way2 = {2'd2};
            bins way3 = {2'd3};
        }
    endgroup

    covergroup fill_cg @(posedge clk);
        cp_fill_received: coverpoint dut.mm_rcvd {
            bins rcvd = {1'b1};
        }
    endgroup

    covergroup rw_hit_cross_cg @(posedge clk);
        cp_req_type: coverpoint dut.arb_row {
            bins read  = {1'b0};
            bins write = {1'b1};
        }
        cp_hit_status: coverpoint dut.hd_hit {
            bins hit  = {1'b1};
            bins miss = {1'b0};
        }
        cx_rw_hit: cross cp_req_type, cp_hit_status;
    endgroup

    covergroup nonblocking_cg @(posedge clk);
        cp_fq_valid: coverpoint dut.fq_valid {
            bins active = {1'b1};
        }
        cp_pending_resolved: coverpoint dut.pending_resolved {
            bins resolved = {1'b1};
        }
    endgroup

    fsm_states_cg      cov_fsm_states = new();
    fsm_transitions_cg cov_fsm_trans  = new();
    read_scenarios_cg  cov_read       = new();
    write_scenarios_cg cov_write      = new();
    plru_victim_cg     cov_plru       = new();
    fill_cg            cov_fill       = new();
    rw_hit_cross_cg    cov_rw_cross   = new();
    nonblocking_cg     cov_nb         = new();

    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    task automatic idle_signals();
        s_axi_arvalid = 0; s_axi_araddr = '0; s_axi_arid = '0;
        s_axi_arburst = 2'b01; s_axi_arsize = 3'b011; s_axi_arlen = 8'd0;
        s_axi_rready  = 0;
        s_axi_awvalid = 0; s_axi_awaddr = '0; s_axi_awid = '0;
        s_axi_awburst = 2'b01; s_axi_awsize = 3'b011; s_axi_awlen = 8'd0;
        s_axi_wvalid  = 0; s_axi_wdata = '0; s_axi_wstrb = '0; s_axi_wlast = 0;
        s_axi_bready  = 1;
    endtask

    task automatic send_ar(input logic [31:0] addr, input logic [3:0] id);
        int tout;
        @(negedge clk);
        s_axi_araddr  = addr;
        s_axi_arid    = id;
        s_axi_arvalid = 1'b1;
        tout = 0;
        do begin
            @(posedge clk);
            tout++;
            if (tout >= TIMEOUT) begin
                $display("TIMEOUT waiting for arready, addr=%0h", addr);
                fail_cnt++;
                s_axi_arvalid = 0;
                disable send_ar;
            end
        end while (!s_axi_arready);
        @(negedge clk);
        s_axi_arvalid = 1'b0;
    endtask

    task automatic recv_r(output logic [63:0] rdata, output logic [3:0] rid);
        int tout;
        s_axi_rready = 1'b1;
        tout = 0;
        do begin
            @(posedge clk);
            tout++;
            if (tout >= TIMEOUT) begin
                $display("TIMEOUT waiting for rvalid");
                fail_cnt++;
                s_axi_rready = 0;
                disable recv_r;
            end
        end while (!s_axi_rvalid);
        rdata = s_axi_rdata;
        rid   = s_axi_rid;
        @(negedge clk);
        s_axi_rready = 1'b0;
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        input  logic [3:0]  id,
        output logic [63:0] rdata,
        output logic [3:0]  rid
    );
        send_ar(addr, id);
        recv_r(rdata, rid);
    endtask

    task automatic axi_write(
        input logic [31:0] addr,
        input logic [3:0]  id,
        input logic [63:0] data,
        input logic [7:0]  strb,
        input logic        wait_b
    );
        int tout;
        @(negedge clk);
        s_axi_awaddr  = addr;  s_axi_awid = id;
        s_axi_awburst = 2'b01; s_axi_awsize = 3'b011; s_axi_awlen = 8'd0;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = data;  s_axi_wstrb = strb;
        s_axi_wvalid  = 1'b1;  s_axi_wlast = 1'b1;
        tout = 0;
        do begin
            @(posedge clk);
            tout++;
            if (tout >= TIMEOUT) begin
                $display("TIMEOUT waiting for awready/wready, addr=%0h", addr);
                fail_cnt++;
                s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_wlast = 0;
                disable axi_write;
            end
        end while (!(s_axi_awready && s_axi_wready));
        @(negedge clk);
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_wlast   = 1'b0;
        if (wait_b) begin
            tout = 0;
            do begin
                @(posedge clk);
                tout++;
                if (tout >= TIMEOUT) begin
                    $display("TIMEOUT waiting for bvalid, addr=%0h", addr);
                    fail_cnt++;
                    disable axi_write;
                end
            end while (!s_axi_bvalid);
            @(negedge clk);
        end
    endtask

    task automatic check(input string name, input logic [63:0] got, input logic [63:0] exp);
        if (got === exp) begin
            $display("PASS  %s: got 0x%016h", name, got);
            pass_cnt++;
        end else begin
            $display("FAIL  %s: got 0x%016h, expected 0x%016h", name, got, exp);
            fail_cnt++;
        end
    endtask

    function automatic logic [31:0] make_addr(input int tag, input int set);
        return {10'(tag), 7'(set), 3'b000};
    endfunction

    function automatic int word_idx(input logic [31:0] addr);
        return addr[18:3];
    endfunction

    logic [63:0] rdata, rdata2;
    logic [3:0]  rid,   rid2;

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_signals();
        rst_n = 0;
        repeat (4) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        $display("\n--- TC1: Single read miss + hit ---");
        dut.u_mm.mem[word_idx(make_addr(0,0))] = 64'hCAFE_0001_DEAD_0001;
        axi_read(make_addr(0,0), 4'h1, rdata, rid);
        check("TC1 miss rdata", rdata, 64'hCAFE_0001_DEAD_0001);
        axi_read(make_addr(0,0), 4'h1, rdata, rid);
        check("TC1 hit rdata",  rdata, 64'hCAFE_0001_DEAD_0001);

        $display("\n--- TC2: Write then read ---");
        axi_write(make_addr(0,1), 4'h2, 64'hBEEF_0002_CAFE_0002, 8'hFF, 1'b1);
        axi_read(make_addr(0,1), 4'h2, rdata, rid);
        check("TC2 read after write", rdata, 64'hBEEF_0002_CAFE_0002);
        axi_read(make_addr(0,1), 4'h2, rdata, rid);
        check("TC2 hit after fill",   rdata, 64'hBEEF_0002_CAFE_0002);

        $display("\n--- TC3: 4 consecutive reads (same set, 4 tags) ---");
        dut.u_mm.mem[word_idx(make_addr(0,2))] = 64'hAAAA_0001_BBBB_0001;
        dut.u_mm.mem[word_idx(make_addr(1,2))] = 64'hAAAA_0002_BBBB_0002;
        dut.u_mm.mem[word_idx(make_addr(2,2))] = 64'hAAAA_0003_BBBB_0003;
        dut.u_mm.mem[word_idx(make_addr(3,2))] = 64'hAAAA_0004_BBBB_0004;
        axi_read(make_addr(0,2), 4'h3, rdata, rid);
        check("TC3 way0 miss", rdata, 64'hAAAA_0001_BBBB_0001);
        axi_read(make_addr(1,2), 4'h3, rdata, rid);
        check("TC3 way1 miss", rdata, 64'hAAAA_0002_BBBB_0002);
        axi_read(make_addr(2,2), 4'h3, rdata, rid);
        check("TC3 way2 miss", rdata, 64'hAAAA_0003_BBBB_0003);
        axi_read(make_addr(3,2), 4'h3, rdata, rid);
        check("TC3 way3 miss", rdata, 64'hAAAA_0004_BBBB_0004);
        axi_read(make_addr(0,2), 4'h3, rdata, rid);
        check("TC3 way0 hit",  rdata, 64'hAAAA_0001_BBBB_0001);
        axi_read(make_addr(2,2), 4'h3, rdata, rid);
        check("TC3 way2 hit",  rdata, 64'hAAAA_0003_BBBB_0003);

        $display("\n--- TC4: 4 consecutive writes ---");
        axi_write(make_addr(0,3), 4'h4, 64'h1111_2222_3333_4444, 8'hFF, 1'b1);
        $display("PASS  TC4 write0 B received");  pass_cnt++;
        axi_write(make_addr(1,3), 4'h4, 64'h5555_6666_7777_8888, 8'hFF, 1'b1);
        $display("PASS  TC4 write1 B received");  pass_cnt++;
        axi_write(make_addr(2,3), 4'h4, 64'h9999_AAAA_BBBB_CCCC, 8'hFF, 1'b1);
        $display("PASS  TC4 write2 B received");  pass_cnt++;
        axi_write(make_addr(3,3), 4'h4, 64'hDDDD_EEEE_FFFF_0000, 8'hFF, 1'b1);
        $display("PASS  TC4 write3 B received");  pass_cnt++;

        $display("\n--- TC5: 4 mixed read/write ---");
        dut.u_mm.mem[word_idx(make_addr(0,4))] = 64'hFACE_BABE_C0DE_5555;
        axi_read (make_addr(0,4), 4'h5, rdata, rid);
        check("TC5 read miss",  rdata, 64'hFACE_BABE_C0DE_5555);
        axi_write(make_addr(1,4), 4'h5, 64'hAAAA_5555_AAAA_5555, 8'hFF, 1'b1);
        $display("PASS  TC5 write0 B received");  pass_cnt++;
        axi_read (make_addr(0,4), 4'h5, rdata, rid);
        check("TC5 read hit",   rdata, 64'hFACE_BABE_C0DE_5555);
        axi_write(make_addr(2,4), 4'h5, 64'hDEAD_BEEF_DEAD_BEEF, 8'hFF, 1'b1);
        $display("PASS  TC5 write1 B received");  pass_cnt++;

        $display("\n--- TC6: RAW forwarding ---");
        dut.u_mm.mem[word_idx(make_addr(0,5))] = 64'hDEAD_DEAD_DEAD_DEAD;
        axi_write(make_addr(0,5), 4'h6, 64'hFEED_FACE_FEED_FACE, 8'hFF, 1'b0);
        axi_read (make_addr(0,5), 4'h6, rdata, rid);
        check("TC6 RAW forward", rdata, 64'hFEED_FACE_FEED_FACE);
        repeat (20) @(posedge clk);

        $display("\n--- TC7: Write hit ---");
        axi_write(make_addr(0,0), 4'h7, 64'hCAFE_BABE_1234_5678, 8'hFF, 1'b1);
        $display("PASS  TC7 write hit B received");  pass_cnt++;
        axi_read(make_addr(0,0), 4'h7, rdata, rid);
        check("TC7 read after write hit", rdata, 64'hCAFE_BABE_1234_5678);

        $display("\n--- TC8: Hit-under-miss ---");
        dut.u_mm.mem[word_idx(make_addr(0,20))] = 64'hF00D_CAFE_0008_0000;
        send_ar(make_addr(0,20), 4'hA);
        send_ar(make_addr(0,0),  4'hB);
        recv_r(rdata,  rid);
        check("TC8 hit-under-miss: hit data",  rdata,  64'hCAFE_BABE_1234_5678);
        recv_r(rdata2, rid2);
        check("TC8 hit-under-miss: fill data", rdata2, 64'hF00D_CAFE_0008_0000);

        $display("\n--- TC9: Two concurrent misses ---");
        dut.u_mm.mem[word_idx(make_addr(0,21))] = 64'hAAAA_BBBB_0009_0001;
        dut.u_mm.mem[word_idx(make_addr(0,22))] = 64'hCCCC_DDDD_0009_0002;
        send_ar(make_addr(0,21), 4'hC);
        send_ar(make_addr(0,22), 4'hD);
        recv_r(rdata,  rid);
        recv_r(rdata2, rid2);
        begin
            logic [63:0] r21, r22;
            if (rid == 4'hC) begin r21 = rdata;  r22 = rdata2; end
            else             begin r21 = rdata2; r22 = rdata;  end
            check("TC9 miss1 fill (set=21)", r21, 64'hAAAA_BBBB_0009_0001);
            check("TC9 miss2 fill (set=22)", r22, 64'hCCCC_DDDD_0009_0002);
        end

        $display("\n--- TC10: Pending-hit stall ---");
        dut.u_mm.mem[word_idx(make_addr(0,23))] = 64'hDEAD_C0DE_0010_BEEF;
        send_ar(make_addr(0,23), 4'hE);
        send_ar(make_addr(0,23), 4'hF);
        recv_r(rdata,  rid);
        recv_r(rdata2, rid2);
        check("TC10 original miss response",  rdata,  64'hDEAD_C0DE_0010_BEEF);
        check("TC10 pending-hit response",    rdata2, 64'hDEAD_C0DE_0010_BEEF);

        $display("\n========================================");
        $display("Results: %0d PASSED, %0d FAILED", pass_cnt, fail_cnt);
        $display("========================================");

        $display("\n=== FUNCTIONAL COVERAGE SUMMARY ===");
        $display("FSM State Coverage:          %0.1f%%", cov_fsm_states.get_coverage());
        $display("FSM Transition Coverage:     %0.1f%%", cov_fsm_trans.get_coverage());
        $display("Read Scenario Coverage:      %0.1f%%", cov_read.get_coverage());
        $display("Write Scenario Coverage:     %0.1f%%", cov_write.get_coverage());
        $display("PLRU Victim Coverage:        %0.1f%%", cov_plru.get_coverage());
        $display("Fill Completion Coverage:    %0.1f%%", cov_fill.get_coverage());
        $display("R/W x Hit/Miss Cross:        %0.1f%%", cov_rw_cross.get_coverage());
        $display("Non-blocking Coverage:       %0.1f%%", cov_nb.get_coverage());
        $display("=====================================\n");

        $finish;
    end

    initial begin
        #(CLK_HALF * 2 * 15000);
        $display("FATAL: global simulation timeout");
        $finish;
    end

    initial begin
        $dumpfile("cache_tb.vcd");
        $dumpvars(0, cache_tb);
    end

endmodule
