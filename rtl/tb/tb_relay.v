// E2.2 test: relay 128->64 (tx) chained to 64->128 (rx).
// Vectors: full words, partial tail (12 bytes), single-beat partial tail (5 bytes).
// Backpressure: rx ready_in stalls every 6th cycle mid-stream.
// Checks: byte-exact reconstruction, bounded context drains, conservation.
`timescale 1ns/1ps

module tb_relay;
    reg clk = 0, rst = 1;

    reg [127:0] w_in;
    reg [4:0]   b_in;
    reg         v_in, l_in;
    reg         stall;

    wire [63:0] beat;
    wire [3:0]  beat_b;
    wire        beat_v, beat_l, tx_ready;

    wire [127:0] w_out;
    wire [4:0]   b_out;
    wire         v_out, l_out, rx_ready;

    hetsub_relay_tx dut_tx (
        .clk(clk), .rst(rst),
        .data_in(w_in), .bytes_in(b_in), .valid_in(v_in), .last_in(l_in),
        .ready_in(stall && rx_ready),
        .data_out(beat), .bytes_out(beat_b), .valid_out(beat_v), .last_out(beat_l),
        .ready_out(tx_ready)
    );
    hetsub_relay_rx dut_rx (
        .clk(clk), .rst(rst),
        .data_in(beat), .bytes_in(beat_b), .valid_in(beat_v), .last_in(beat_l),
        .ready_in(stall),
        .data_out(w_out), .bytes_out(b_out), .valid_out(v_out), .last_out(l_out),
        .ready_out(rx_ready)
    );

    always #5 clk = ~clk;

    reg [127:0] W [0:3];
    reg [4:0]   B [0:3];
    integer next_w = 0, checked = 0, cyc = 0, i;
    integer beats_seen = 0, beats_held = 0;

    // Events are sampled at posedge from the values the DUT actually used.
    reg beat_consumed, beat_held, word_consumed;
    reg [127:0] word_q;
    reg [4:0]   bytes_q;
    reg last_q;

    always @(posedge clk) begin
        if (!rst) begin
            beat_consumed = beat_v && stall;
            beat_held = dut_tx.pending_valid && !stall;
            // Word assembled at this posedge (pre-edge rx state).
            if (beat_v && stall) begin
                if (dut_rx.acc_valid) begin
                    word_consumed = 1;
                    word_q = {dut_rx.acc, beat};
                    bytes_q = dut_rx.acc_bytes + beat_b;
                    last_q = beat_l;
                end else if (beat_l && beat_b <= 4'd8) begin
                    word_consumed = 1;
                    word_q = {beat, 64'b0};
                    bytes_q = {1'b0, beat_b};
                    last_q = 1;
                end else begin
                    word_consumed = 0;
                end
            end else begin
                word_consumed = 0;
            end
        end
    end

    initial begin
        W[0] = 128'hAABBCCDDEEFF00112233445566778899; B[0] = 16;
        W[1] = 128'h112233445566778899AABBCCDDEEFF00; B[1] = 16;
        W[2] = 128'hDEADBEEFCAFEBABE0123456789ABCDEF; B[2] = 12;  // partial tail, 2 beats
        W[3] = 128'h0F0E0D0C0B0A09080706050403020100; B[3] = 5;   // partial tail, 1 beat
        w_in = 0; b_in = 0; v_in = 0; l_in = 0; stall = 1;
    end

    always @(negedge clk) begin
        if (!rst) begin
            cyc = cyc + 1;
            if (word_consumed) begin
                checked = checked + 1;
                if (bytes_q !== B[checked - 1]) begin
                    $display("FAIL: word %0d bytes %0d != %0d", checked, bytes_q, B[checked - 1]); $finish;
                end
                for (i = 0; i < bytes_q; i = i + 1)
                    if (word_q[127 - 8*i -: 8] !== W[checked - 1][127 - 8*i -: 8]) begin
                        $display("FAIL: word %0d byte %0d mismatch: got %h expect %h",
                                 checked, i, word_q[127 - 8*i -: 8], W[checked - 1][127 - 8*i -: 8]); $finish;
                    end
                if (checked == 4 && !last_q) begin
                    $display("FAIL: last flag lost on final word"); $finish;
                end
            end
            if (beat_consumed) beats_seen = beats_seen + 1;
            if (beat_held) beats_held = beats_held + 1;

            stall = (cyc % 6) != 5;
            if (next_w < 4 && tx_ready && stall && rx_ready) begin
                w_in = W[next_w]; b_in = B[next_w];
                l_in = (next_w == 3); v_in = 1;
                next_w = next_w + 1;
            end else begin
                v_in = 0;
            end
        end
    end

    initial begin
        #10; rst = 0;
        #200;
        if (checked != 4) begin
            $display("FAIL: words checked=%0d", checked); $finish;
        end
        if (beats_seen < 7 || beats_held == 0) begin
            $display("FAIL: backpressure not exercised (beats=%0d held=%0d)",
                     beats_seen, beats_held); $finish;
        end
        if (dut_tx.pending_valid || dut_tx.half_valid || dut_rx.acc_valid) begin
            $display("FAIL: relay context not drained"); $finish;
        end
        $display("PASS tb_relay: 4 words byte-exact, beats=%0d (held %0d), context drained",
                 beats_seen, beats_held);
        $finish;
    end
endmodule
