// E2.3 test: static long-link crossbar bypass (Algorithm 1 consumer).
// Checks: legal monotonic grant, illegal turn rejected, non-head rejected,
// per-output conflict rejects both, block/exclusive asserted, hop budget exhausts.
// block is input-indexed; byp_valid/exclusive are output-indexed.
`timescale 1ns/1ps

module tb_bypass;
    reg clk = 0, rst = 1;

    reg [5*64-1:0] flit_in;
    reg [5-1:0]    valid_in;
    reg [5*2-1:0]  type_in;
    reg [5-1:0]    cfg_en;
    reg [5*3-1:0]  cfg_out;
    reg [5*2-1:0]  cfg_hop;

    wire [5*64-1:0] byp_flit;
    wire [5-1:0]    byp_valid;
    wire [5-1:0]    block;
    wire [5-1:0]    exclusive;

    hetsub_bypass dut (
        .clk(clk), .rst(rst),
        .flit_in(flit_in), .valid_in(valid_in), .type_in(type_in),
        .cfg_en(cfg_en), .cfg_out(cfg_out), .cfg_hop(cfg_hop),
        .byp_flit(byp_flit), .byp_valid(byp_valid),
        .block(block), .exclusive(exclusive)
    );

    always #5 clk = ~clk;

    function [63:0] mkflit;
        input [3:0] x, y; input [3:0] t;
        begin
            mkflit = {x, y, t, 4'd0, 48'h0};
        end
    endfunction

    integer fails = 0;

    task check;
        input [5-1:0] exp_block, exp_excl, exp_bypv;
        input integer tag;
        begin
            if (block !== exp_block || exclusive !== exp_excl || byp_valid !== exp_bypv) begin
                $display("FAIL tag %0d: block=%b excl=%b byp_valid=%b (expect %b/%b/%b)",
                         tag, block, exclusive, byp_valid, exp_block, exp_excl, exp_bypv);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        cfg_en  = 5'b11111;
        cfg_out = 15'd0;
        cfg_out[0*3 +: 3] = 2; cfg_out[1*3 +: 3] = 4; cfg_out[2*3 +: 3] = 3;
        cfg_out[3*3 +: 3] = 1; cfg_out[4*3 +: 3] = 4;
        cfg_hop = 10'd0;
        cfg_hop[0*2 +: 2] = 1; cfg_hop[1*2 +: 2] = 2; cfg_hop[2*2 +: 2] = 1;
        cfg_hop[3*2 +: 2] = 1; cfg_hop[4*2 +: 2] = 1;
        flit_in = 0; type_in = 0; valid_in = 0;
    end

    initial begin
        #10; rst = 0;

        // 1) p0 head, legal turn to out2: grant, block, exclusive, flit routed.
        flit_in[0*64 +: 64] = mkflit(2, 2, 0);
        valid_in = 5'b00001;
        #1;
        check(5'b00001, 5'b00100, 5'b00100, 1);
        if (byp_flit[2*64 +: 64] !== mkflit(2, 2, 0)) begin
            $display("FAIL tag 1: byp_flit mismatch"); fails = fails + 1; end
        @(posedge clk); #1;   // hop0: 1 -> 0

        // 2) p0 hop exhausted: rejected.
        check(5'b00000, 5'b00000, 5'b00000, 2);

        // 3) Illegal turn p2->out3 rejected; p3 legal grant to out1.
        flit_in[2*64 +: 64] = mkflit(2, 2, 0);
        flit_in[3*64 +: 64] = mkflit(2, 2, 0);
        valid_in = 5'b01100;
        #1;
        check(5'b01000, 5'b00010, 5'b00010, 3);
        @(posedge clk); #1;   // hop3: 1 -> 0
        check(5'b00000, 5'b00000, 5'b00000, 4);

        // 4) Non-head type on p1 rejected (hop1 untouched).
        type_in[1*2 +: 2] = 2'd1;
        valid_in = 5'b00010;
        #1;
        check(5'b00000, 5'b00000, 5'b00000, 5);
        type_in = 10'd0;

        // 5) Conflict: p1 and p4 both target out4 -> both rejected, no decrement.
        flit_in[4*64 +: 64] = mkflit(2, 2, 0);
        valid_in = 5'b10010;
        #1;
        check(5'b00000, 5'b00000, 5'b00000, 6);

        // 6) p1 hop budget 2: two grants, third rejected.
        valid_in = 5'b00010;
        #1;
        check(5'b00010, 5'b10000, 5'b10000, 7);
        @(posedge clk); #1;   // hop1: 2 -> 1
        check(5'b00010, 5'b10000, 5'b10000, 8);
        @(posedge clk); #1;   // hop1: 1 -> 0
        check(5'b00000, 5'b00000, 5'b00000, 9);

        if (fails == 0) $display("PASS tb_bypass: legality, exclusivity, block, hop budget");
        $finish;
    end
endmodule
