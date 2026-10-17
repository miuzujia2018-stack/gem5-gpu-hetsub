// HetSub tile area top: one tile = L router + M router + NI relay (tx/rx) +
// static long-link crossbar bypass + congestion sampling/hysteresis + PG state.
// Structural container for same-flow synthesis; Algorithm 2 is offline (no area),
// its config storage is the static cfg_* registers of the bypass.
module hetsub_tile_top (
    input  wire clk,
    input  wire rst,

    // NI side (128-bit words)
    input  wire [3*128-1:0] l_flit_in,
    input  wire [3-1:0]     l_valid_in,
    input  wire [3*2-1:0]   l_vc_in,
    input  wire [3*2-1:0]   l_type_in,
    input  wire [3-1:0]     l_credit_ret,
    output wire [3*128-1:0] l_flit_out,
    output wire [3-1:0]     l_valid_out,
    output wire [3*2-1:0]   l_vc_out,
    output wire [3*2-1:0]   l_type_out,
    output wire [127:0]     ni_word_out,
    output wire [4:0]       ni_bytes_out,
    output wire             ni_valid_out,
    output wire             ni_last_out,

    // M subnet side (64-bit beats), bypass-granted heads bypass the normal path
    input  wire [5*64-1:0]  m_flit_in,
    input  wire [5-1:0]     m_valid_in,
    input  wire [5*2-1:0]   m_vc_in,
    input  wire [5*2-1:0]   m_type_in,
    input  wire [5*2-1:0]   m_credit_ret,
    output wire [5*64-1:0]  m_flit_out,
    output wire [5-1:0]     m_valid_out,
    output wire [5*2-1:0]   m_vc_out,
    output wire [5*2-1:0]   m_type_out,
    output wire [5*64-1:0]  byp_flit,
    output wire [5-1:0]     byp_valid,
    output wire [5-1:0]     block,
    output wire [5-1:0]     exclusive,

    // Static config registers (Algorithm 2 storage)
    input  wire [5-1:0]     cfg_en,
    input  wire [5*3-1:0]   cfg_out,
    input  wire [5*2-1:0]   cfg_hop,

    // Congestion sampling + hysteresis + PG
    input  wire [7:0]       cong,
    input  wire [7:0]       th_hi,
    input  wire [7:0]       th_lo,
    input  wire [3:0]       wake_lat,
    input  wire             m_inflight,
    output wire             sel,
    output wire [1:0]       pg_state,
    output wire             m_enable
);
    // Relay: L-router output port 0 serializes to beats, deserialized back to a word.
    wire [63:0]  beat;
    wire [3:0]   beat_b;
    wire         beat_v, beat_l;
    wire         tx_ready, rx_ready;

    hetsub_l_router u_l (
        .clk(clk), .rst(rst),
        .flit_in(l_flit_in), .valid_in(l_valid_in), .vc_in(l_vc_in), .type_in(l_type_in),
        .credit_ret(l_credit_ret),
        .flit_out(l_flit_out), .valid_out(l_valid_out), .vc_out(l_vc_out), .type_out(l_type_out)
    );

    hetsub_relay_tx u_tx (
        .clk(clk), .rst(rst),
        .data_in(l_flit_out[127:0]), .bytes_in(5'd16), .valid_in(l_valid_out[0]), .last_in(1'b1),
        .ready_in(rx_ready),
        .data_out(beat), .bytes_out(beat_b), .valid_out(beat_v), .last_out(beat_l),
        .ready_out(tx_ready)
    );
    hetsub_relay_rx u_rx (
        .clk(clk), .rst(rst),
        .data_in(beat), .bytes_in(beat_b), .valid_in(beat_v), .last_in(beat_l),
        .ready_in(1'b1),
        .data_out(ni_word_out), .bytes_out(ni_bytes_out),
        .valid_out(ni_valid_out), .last_out(ni_last_out),
        .ready_out(rx_ready)
    );

    hetsub_bypass u_byp (
        .clk(clk), .rst(rst),
        .flit_in(m_flit_in), .valid_in(m_valid_in), .type_in(m_type_in),
        .cfg_en(cfg_en), .cfg_out(cfg_out), .cfg_hop(cfg_hop),
        .byp_flit(byp_flit), .byp_valid(byp_valid),
        .block(block), .exclusive(exclusive)
    );

    hetsub_m_router u_m (
        .clk(clk), .rst(rst),
        .flit_in(m_flit_in), .valid_in(m_valid_in), .vc_in(m_vc_in), .type_in(m_type_in),
        .credit_ret(m_credit_ret),
        .flit_out(m_flit_out), .valid_out(m_valid_out), .vc_out(m_vc_out), .type_out(m_type_out)
    );

    hetsub_select_pg u_pg (
        .clk(clk), .rst(rst),
        .cong(cong), .th_hi(th_hi), .th_lo(th_lo), .wake_lat(wake_lat),
        .m_inflight(m_inflight),
        .sel(sel), .pg_state(pg_state), .m_enable(m_enable)
    );
endmodule
