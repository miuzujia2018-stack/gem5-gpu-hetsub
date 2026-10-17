// E1.1 test 1: Baseline router directed test.
// One head/body/tail group per output direction (N,E,S,W) and local, injected
// on distinct input ports. Router at (2,2) so all directions are reachable.
// Checks: VC allocation (per-group VC respected, control VC exercised), credit
// accounting, crossbar delivery order/content, conservation and drain.
`timescale 1ns/1ps

module tb_baseline;
    parameter FLIT_W = 128;
    parameter NPORTS = 5;
    parameter NVC    = 2;
    parameter DEPTH  = 4;

    reg clk = 0;
    reg rst = 1;

    reg [NPORTS*FLIT_W-1:0] flit_in;
    reg [NPORTS-1:0]        valid_in;
    reg [NPORTS*2-1:0]      vc_in;
    reg [NPORTS*2-1:0]      type_in;
    reg [NPORTS*NVC-1:0]    credit_ret;

    wire [NPORTS*FLIT_W-1:0] flit_out;
    wire [NPORTS-1:0]        valid_out;
    wire [NPORTS*2-1:0]      vc_out;
    wire [NPORTS*2-1:0]      type_out;

    baseline_router #(.MY_X(2), .MY_Y(2)) dut (
        .clk(clk), .rst(rst),
        .flit_in(flit_in), .valid_in(valid_in), .vc_in(vc_in), .type_in(type_in),
        .credit_ret(credit_ret),
        .flit_out(flit_out), .valid_out(valid_out), .vc_out(vc_out), .type_out(type_out)
    );

    always #5 clk = ~clk;

    // Group g: input port g, expected output port g.
    // dest per group: g0=(2,3)N, g1=(3,2)E, g2=(2,1)S, g3=(1,2)W, g4=(2,2)local
    reg [3:0] gx [0:NPORTS-1], gy [0:NPORTS-1];
    reg [1:0] gvc [0:NPORTS-1];

    reg [FLIT_W-1:0] exp_q [0:NPORTS-1][0:3];
    integer exp_n [0:NPORTS-1];
    integer delivered [0:NPORTS-1];
    integer injected_total = 0, delivered_total = 0;

    // Acceptance as settled by the DUT at the posedge following presentation.
    // Sampled on posedge so the negedge injection block sees a stable value.
    reg [NPORTS*NVC-1:0] acc_q;
    always @(posedge clk) if (!rst) acc_q <= dut.u_buf.accept;

    // Downstream model: return credit one cycle after each delivered flit
    reg [NPORTS*NVC-1:0] ret_d;

    function [FLIT_W-1:0] mkflit;
        input [3:0] x, y; input [1:0] t; input [1:0] v; input [111:0] pay;
        begin
            mkflit = {x, y, {2'b00, t}, {2'b00, v}, pay};   // 4+4+4+4+112 = 128
        end
    endfunction

    integer g, i;
    initial begin
        for (g = 0; g < NPORTS; g = g + 1) begin
            gx[g] = (g == 0) ? 2 : (g == 1) ? 3 : (g == 2) ? 2 : (g == 3) ? 1 : 2;
            gy[g] = (g == 0) ? 3 : (g == 1) ? 2 : (g == 2) ? 1 : (g == 3) ? 2 : 2;
            gvc[g] = (g == 4) ? 1 : 0;   // group 4 exercises the control VC
            exp_n[g] = 0;
            delivered[g] = 0;
            next_i[g] = 0; presented[g] = 0;
        end
        flit_in = 0; valid_in = 0; vc_in = 0; type_in = 0;
        credit_ret = 0; ret_d = 0; acc_q = 0;
    end

    integer inject_start = 10;
    integer cyc = 0;
    integer next_i [0:NPORTS-1];
    integer presented [0:NPORTS-1];

    // Single negedge block: inject (backpressure, hold until accepted), then
    // score, then return credits. Order within the block is deterministic.
    always @(negedge clk) begin
        if (!rst) begin
            cyc = cyc + 1;
            if (cyc >= inject_start) begin
                for (g = 0; g < NPORTS; g = g + 1) begin
                    // acc_q reflects acceptance of the flit presented last cycle
                    if (presented[g] && acc_q[g*NVC + gvc[g]]) begin
                        next_i[g] = next_i[g] + 1;
                        presented[g] = 0;
                    end
                    if (next_i[g] < 3) begin
                        flit_in[g*FLIT_W +: FLIT_W] = mkflit(gx[g], gy[g], next_i[g], gvc[g],
                                                             (g*8 + next_i[g]) << 40);
                        valid_in[g] = 1;
                        vc_in[g*2 +: 2] = gvc[g];
                        type_in[g*2 +: 2] = next_i[g];
                        if (!presented[g]) begin
                            exp_q[g][exp_n[g]] = mkflit(gx[g], gy[g], next_i[g], gvc[g],
                                                        (g*8 + next_i[g]) << 40);
                            exp_n[g] = exp_n[g] + 1;
                            injected_total = injected_total + 1;
                            presented[g] = 1;
                        end
                    end else begin
                        valid_in[g] = 0;   // group done: stop driving, no re-accept
                    end
                end
            end
            // Scoreboard + downstream credit model (after injection recorded exp_q)
            for (g = 0; g < NPORTS; g = g + 1) begin
                if (valid_out[g]) begin
                    delivered_total = delivered_total + 1;
                    if (delivered[g] >= exp_n[g]) begin
                        $display("FAIL: unexpected flit on output %0d", g);
                        $finish;
                    end
                    if (flit_out[g*FLIT_W +: FLIT_W] !== exp_q[g][delivered[g]]) begin
                        $display("FAIL: output %0d flit mismatch: got %h expect %h",
                                 g, flit_out[g*FLIT_W +: FLIT_W], exp_q[g][delivered[g]]);
                        $finish;
                    end
                    if (vc_out[g*2 +: 2] !== gvc[g]) begin
                        $display("FAIL: output %0d vc mismatch: got %0d expect %0d",
                                 g, vc_out[g*2 +: 2], gvc[g]);
                        $finish;
                    end
                    delivered[g] = delivered[g] + 1;
                    ret_d[g*NVC + gvc[g]] = 1;
                end
            end
            credit_ret = ret_d;
            ret_d = 0;
        end
    end

    // Drain + final checks
    initial begin
        #10;
        rst = 0;
        #200;   // plenty of time for 15 flits to drain
        if (injected_total != 15 || delivered_total != 15) begin
            $display("FAIL: conservation injected=%0d delivered=%0d", injected_total, delivered_total);
            $finish;
        end
        for (g = 0; g < NPORTS; g = g + 1) begin
            if (dut.u_buf.occ[(g*NVC + 0)*3 +: 3] != 0 || dut.u_buf.occ[(g*NVC + 1)*3 +: 3] != 0) begin
                $display("FAIL: port %0d not drained", g); $finish;
            end
            if (dut.u_table.vc_busy[g*NVC + 0] || dut.u_table.vc_busy[g*NVC + 1]) begin
                $display("FAIL: port %0d VC still busy", g); $finish;
            end
            if (dut.u_buf.credit[(g*NVC + 0)*3 +: 3] != 4 || dut.u_buf.credit[(g*NVC + 1)*3 +: 3] != 1) begin
                $display("FAIL: port %0d credits not restored: %0d/%0d",
                         g, dut.u_buf.credit[(g*NVC + 0)*3 +: 3], dut.u_buf.credit[(g*NVC + 1)*3 +: 3]); $finish;
            end
        end
        $display("PASS tb_baseline: injected=%0d delivered=%0d drained, credits restored",
                 injected_total, delivered_total);
        $finish;
    end
endmodule
