// E2.4 test: congestion-driven subnet selection + PG state machine.
// Checks: hysteresis (th_hi/th_lo, hold band), wake latency, ON->OFF only when
// sel=L and no in-flight, isolation m_enable=0 during OFF/WAKING.
// NBA semantics: sel/state/m_enable reflect the posedge that just occurred.
`timescale 1ns/1ps

module tb_select_pg;
    reg clk = 0, rst = 1;

    reg [7:0] cong, th_hi, th_lo;
    reg [3:0] wake_lat;
    reg       m_inflight;

    wire       sel;
    wire [1:0] pg_state;
    wire       m_enable;

    hetsub_select_pg dut (
        .clk(clk), .rst(rst),
        .cong(cong), .th_hi(th_hi), .th_lo(th_lo), .wake_lat(wake_lat),
        .m_inflight(m_inflight),
        .sel(sel), .pg_state(pg_state), .m_enable(m_enable)
    );

    always #5 clk = ~clk;

    integer fails = 0;

    task check;
        input exp_sel; input [1:0] exp_state; input exp_en;
        input integer tag;
        begin
            if (sel !== exp_sel || pg_state !== exp_state || m_enable !== exp_en) begin
                $display("FAIL tag %0d: sel=%b state=%0d en=%b (expect %b/%0d/%b)",
                         tag, sel, pg_state, m_enable, exp_sel, exp_state, exp_en);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        th_hi = 10; th_lo = 5; wake_lat = 3;
        cong = 0; m_inflight = 0;
    end

    initial begin
        #10; rst = 0;

        // 1) Initial: OFF, sel=L, isolated.
        check(0, 2'd0, 0, 1);

        // 2) Hold band: cong=8 (>=th_lo, <th_hi) keeps sel=L.
        cong = 8;
        @(posedge clk); #1;
        check(0, 2'd0, 0, 2);

        // 3) cong >= th_hi: sel=M; state still OFF this cycle (NBA), WAKING next.
        cong = 12;
        @(posedge clk); #1;
        check(1, 2'd0, 0, 3);
        @(posedge clk); #1;
        check(1, 2'd1, 0, 4);   // WAKING, cnt=0, still isolated

        // 4) Wake latency: ON after wake_lat counted cycles.
        @(posedge clk); #1; check(1, 2'd1, 0, 5);   // cnt 1
        @(posedge clk); #1; check(1, 2'd1, 0, 6);   // cnt 2
        @(posedge clk); #1; check(1, 2'd1, 0, 7);   // cnt 3
        @(posedge clk); #1; check(1, 2'd2, 0, 8);   // ON; m_enable follows next cycle
        @(posedge clk); #1; check(1, 2'd2, 1, 10);   // enabled

        // 5) Hold band keeps sel=M and ON.
        cong = 8;
        @(posedge clk); #1;
        check(1, 2'd2, 1, 10);

        // 6) sel=L but in-flight: must stay ON.
        cong = 3;
        @(posedge clk); #1;
        check(0, 2'd2, 1, 12);
        m_inflight = 1;
        @(posedge clk); #1;
        check(0, 2'd2, 1, 12);

        // 7) sel=L, no in-flight: OFF; isolation drops the following cycle.
        m_inflight = 0;
        @(posedge clk); #1;
        check(0, 2'd0, 1, 13);   // state OFF, m_enable still 1 (NBA lag)
        @(posedge clk); #1;
        check(0, 2'd0, 0, 14);   // isolated again

        if (fails == 0) $display("PASS tb_select_pg: hysteresis, wake latency, in-flight safety, isolation");
        $finish;
    end
endmodule
