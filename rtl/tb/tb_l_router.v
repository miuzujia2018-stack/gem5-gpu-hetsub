// E2.1 test: HetSub L router (3-port, 128-bit, 1 VC, depth 4).
// One head/body/tail group per port: g0->N, g1->E, g2->local. Router at (2,2).
// Checks: VC allocation, credit accounting, delivery order/content,
// conservation, drain, credit restoration.
`timescale 1ns/1ps

module tb_l_router;
    parameter FLIT_W = 128;
    parameter NPORTS = 3;

    reg clk = 0;
    reg rst = 1;

    reg [NPORTS*FLIT_W-1:0] flit_in;
    reg [NPORTS-1:0]        valid_in;
    reg [NPORTS*2-1:0]      vc_in;
    reg [NPORTS*2-1:0]      type_in;
    reg [NPORTS-1:0]        credit_ret;

    wire [NPORTS*FLIT_W-1:0] flit_out;
    wire [NPORTS-1:0]        valid_out;
    wire [NPORTS*2-1:0]      vc_out;
    wire [NPORTS*2-1:0]      type_out;

    hetsub_l_router #(.MY_X(2), .MY_Y(2)) dut (
        .clk(clk), .rst(rst),
        .flit_in(flit_in), .valid_in(valid_in), .vc_in(vc_in), .type_in(type_in),
        .credit_ret(credit_ret),
        .flit_out(flit_out), .valid_out(valid_out), .vc_out(vc_out), .type_out(type_out)
    );

    always #5 clk = ~clk;

    reg [3:0] gx [0:NPORTS-1], gy [0:NPORTS-1];
    reg [FLIT_W-1:0] exp_q [0:NPORTS-1][0:3];
    integer exp_n [0:NPORTS-1];
    integer delivered [0:NPORTS-1];
    integer injected_total = 0, delivered_total = 0;

    reg [NPORTS-1:0] acc_q;
    always @(posedge clk) if (!rst) acc_q <= dut.u_buf.accept;

    reg [NPORTS-1:0] ret_d;

    function [FLIT_W-1:0] mkflit;
        input [3:0] x, y; input [1:0] t; input [111:0] pay;
        begin
            mkflit = {x, y, {2'b00, t}, {2'b00, 2'b00}, pay};
        end
    endfunction

    integer g;
    initial begin
        gx[0] = 2; gy[0] = 3;          // N
        gx[1] = 3; gy[1] = 2;          // E
        gx[2] = 2; gy[2] = 2;          // local
        for (g = 0; g < NPORTS; g = g + 1) begin
            exp_n[g] = 0; delivered[g] = 0; next_i[g] = 0; presented[g] = 0;
        end
        flit_in = 0; valid_in = 0; vc_in = 0; type_in = 0;
        credit_ret = 0; ret_d = 0; acc_q = 0;
    end

    integer inject_start = 10;
    integer cyc = 0;
    integer next_i [0:NPORTS-1];
    integer presented [0:NPORTS-1];

    always @(negedge clk) begin
        if (!rst) begin
            cyc = cyc + 1;
            if (cyc >= inject_start) begin
                for (g = 0; g < NPORTS; g = g + 1) begin
                    if (presented[g] && acc_q[g]) begin
                        next_i[g] = next_i[g] + 1;
                        presented[g] = 0;
                    end
                    if (next_i[g] < 3) begin
                        flit_in[g*FLIT_W +: FLIT_W] = mkflit(gx[g], gy[g], next_i[g], (g*8 + next_i[g]) << 40);
                        valid_in[g] = 1;
                        vc_in[g*2 +: 2] = 2'd0;
                        type_in[g*2 +: 2] = next_i[g];
                        if (!presented[g]) begin
                            exp_q[g][exp_n[g]] = mkflit(gx[g], gy[g], next_i[g], (g*8 + next_i[g]) << 40);
                            exp_n[g] = exp_n[g] + 1;
                            injected_total = injected_total + 1;
                            presented[g] = 1;
                        end
                    end else begin
                        valid_in[g] = 0;
                    end
                end
            end
            for (g = 0; g < NPORTS; g = g + 1) begin
                if (valid_out[g]) begin
                    delivered_total = delivered_total + 1;
                    if (delivered[g] >= exp_n[g]) begin
                        $display("FAIL: unexpected flit on output %0d", g); $finish;
                    end
                    if (flit_out[g*FLIT_W +: FLIT_W] !== exp_q[g][delivered[g]]) begin
                        $display("FAIL: output %0d flit mismatch: got %h expect %h",
                                 g, flit_out[g*FLIT_W +: FLIT_W], exp_q[g][delivered[g]]); $finish;
                    end
                    if (vc_out[g*2 +: 2] !== 2'd0) begin
                        $display("FAIL: output %0d vc mismatch", g); $finish;
                    end
                    delivered[g] = delivered[g] + 1;
                    ret_d[g] = 1;
                end
            end
            credit_ret = ret_d;
            ret_d = 0;
        end
    end

    initial begin
        #10;
        rst = 0;
        #200;
        if (injected_total != 9 || delivered_total != 9) begin
            $display("FAIL: conservation injected=%0d delivered=%0d", injected_total, delivered_total); $finish;
        end
        for (g = 0; g < NPORTS; g = g + 1) begin
            if (dut.u_buf.occ[g*3 +: 3] != 0) begin
                $display("FAIL: port %0d not drained", g); $finish;
            end
            if (dut.u_table.vc_busy[g]) begin
                $display("FAIL: port %0d VC still busy", g); $finish;
            end
            if (dut.u_buf.credit[g*3 +: 3] != 4) begin
                $display("FAIL: port %0d credits not restored: %0d", g, dut.u_buf.credit[g*3 +: 3]); $finish;
            end
        end
        $display("PASS tb_l_router: injected=%0d delivered=%0d drained, credits restored",
                 injected_total, delivered_total);
        $finish;
    end
endmodule
