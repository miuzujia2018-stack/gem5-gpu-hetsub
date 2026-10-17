// HetSub L router — 3 ports (0=N long-link, 1=E long-link, 2=local to M router),
// 128-bit flit, 1 VC/vnet, depth 4. Wormhole, 2-stage pipeline, flops storage.
// Structural wrapper over the Table 3 attribution units: vc_buffer, rc_mono,
// vc_table, vc_alloc, sw_alloc, crossbar.
//
// Flit fields: dest [127:120] (x[127:124], y[123:120]), type [119:116]
// (0=head,1=body,2=tail), vc [115:112] (must be 0), payload [111:0].
// Routing: static long-link path — forward on N/E until dest row/col reached,
// then local. Algorithm 1 legality (monotonic, no backtracking) is enforced by
// the bypass module; here RC is the monotonic XY order restricted to N/E/local.
module hetsub_l_router #(
    parameter MY_X = 2,
    parameter MY_Y = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [3*128-1:0] flit_in,
    input  wire [3-1:0]        valid_in,
    input  wire [3*2-1:0]      vc_in,
    input  wire [3*2-1:0]      type_in,
    input  wire [3-1:0]        credit_ret,
    output wire [3*128-1:0] flit_out,
    output wire [3-1:0]        valid_out,
    output wire [3*2-1:0]      vc_out,
    output wire [3*2-1:0]      type_out
);
    localparam NPORTS = 3;
    localparam NVC    = 1;
    localparam DEPTH  = 4;
    localparam FLIT_W = 128;

    wire [NPORTS*NVC-1:0] accept, rd_en, single, drained;
    wire [NPORTS*NVC*3-1:0] occ, vc_port;
    wire [NPORTS*NVC-1:0] vc_busy;
    wire [NPORTS*3-1:0] rc;
    wire [NPORTS*NPORTS*NVC-1:0] va_gnt;
    wire [NPORTS*NPORTS-1:0] sa_gnt;
    wire [NPORTS*NVC*FLIT_W-1:0] head_data;
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
    rc_mono #(.MY_X(MY_X), .MY_Y(MY_Y)) u_rc (.xy(dest), .rc(rc));
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
