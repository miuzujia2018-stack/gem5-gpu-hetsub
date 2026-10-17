// Baseline NoC router — 5 ports (N,E,S,W,local), 128-bit flit, 2 VC/vnet,
// data VC depth 4, control VC depth 1, 2-stage wormhole pipeline.
// Structural wrapper over the Table 3 attribution units: vc_buffer, rc_xy,
// vc_table, vc_alloc, sw_alloc, crossbar. All storage is register arrays.
//
// Flit fields: dest [127:120] (x[127:124], y[123:120]),
//            type [119:116] (0=head, 1=body, 2=tail),
//            vc   [115:112], payload [111:0].
// Ports: 0=N, 1=E, 2=S, 3=W, 4=local.

module baseline_router #(
    parameter FLIT_W = 128,
    parameter NPORTS = 5,
    parameter NVC    = 2,
    parameter DEPTH  = 4,
    parameter MY_X   = 2,
    parameter MY_Y   = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*FLIT_W-1:0] flit_in,
    input  wire [NPORTS-1:0]        valid_in,
    input  wire [NPORTS*2-1:0]      vc_in,
    input  wire [NPORTS*2-1:0]      type_in,
    input  wire [NPORTS*NVC-1:0]    credit_ret,
    output wire [NPORTS*FLIT_W-1:0] flit_out,
    output wire [NPORTS-1:0]        valid_out,
    output wire [NPORTS*2-1:0]      vc_out,
    output wire [NPORTS*2-1:0]      type_out
);
    wire [NPORTS*NVC-1:0] accept, rd_en, drained;
    wire [NPORTS*NVC*3-1:0] occ, vc_port;
    wire [NPORTS*NVC-1:0] vc_busy;
    wire [NPORTS*3-1:0] rc;
    wire [NPORTS*NPORTS*NVC-1:0] va_gnt;
    wire [NPORTS*NPORTS-1:0] sa_gnt;
    wire [NPORTS*NVC*FLIT_W-1:0] head_data;
    wire [NPORTS*NVC-1:0] single;
    wire [NPORTS*8-1:0] dest;

    genvar p;
    generate
        for (p = 0; p < NPORTS; p = p + 1) begin : gd
            assign dest[p*8 +: 8] = flit_in[p*FLIT_W + (FLIT_W-8) +: 8];
        end
    endgenerate

    vc_buffer #(.NPORTS(NPORTS), .NVC(NVC), .DEPTH0(DEPTH), .DEPTH1(1), .FLIT_W(FLIT_W)) u_buf (
        .clk(clk), .rst(rst),
        .flit_in(flit_in), .valid_in(valid_in), .vc_in(vc_in), .block(0),
        .credit_ret(credit_ret), .rd_en(rd_en),
        .accept(accept), .occ(occ), .headp(), .credit(), .single(single), .drained(drained), .head_data(head_data)
    );
    rc_xy #(.NPORTS(NPORTS), .MY_X(MY_X), .MY_Y(MY_Y)) u_rc (.xy(dest), .rc(rc));
    vc_table #(.NPORTS(NPORTS), .NVC(NVC)) u_table (
        .clk(clk), .rst(rst), .va_gnt(va_gnt), .clear_en(drained),
        .dest(dest), .vc_port(vc_port), .vc_busy(vc_busy)
    );
    vc_alloc #(.NPORTS(NPORTS), .NVC(NVC)) u_va (
        .clk(clk), .rst(rst), .accept(accept), .type_in(type_in), .rc(rc),
        .vc_busy(vc_busy), .va_gnt(va_gnt)
    );
    sw_alloc #(.NPORTS(NPORTS), .NVC(NVC)) u_sa (
        .clk(clk), .rst(rst), .occ(occ), .vc_port(vc_port), .exclusive(0), .sa_gnt(sa_gnt)
    );
    crossbar #(.NPORTS(NPORTS), .NVC(NVC), .FLIT_W(FLIT_W)) u_xbar (
        .clk(clk), .rst(rst), .sa_gnt(sa_gnt), .occ(occ), .vc_port(vc_port),
        .head_data(head_data), .rd_en(rd_en),
        .flit_out(flit_out), .valid_out(valid_out), .vc_out(vc_out), .type_out(type_out)
    );
endmodule
