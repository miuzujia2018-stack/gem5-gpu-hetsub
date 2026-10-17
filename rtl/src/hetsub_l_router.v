// HetSub L router — 3 ports (0=N long-link, 1=E long-link, 2=local to M router),
// 128-bit flit, 1 VC/vnet, depth 4. Wormhole, 2-stage pipeline, flops storage.
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
    output reg  [3*128-1:0] flit_out,
    output reg  [3-1:0]        valid_out,
    output reg  [3*2-1:0]      vc_out,
    output reg  [3*2-1:0]      type_out
);
    localparam NPORTS = 3;
    localparam DEPTH  = 4;

    reg [3*8-1:0]   vc_dest;    // entry i: vc_dest[i*8 +: 8]
    reg [3*3-1:0]   vc_port;    // entry i: vc_port[i*3 +: 3]
    reg [3-1:0]     vc_busy;

    reg [3*4*128-1:0] vbuf;     // slot (i,s): vbuf[(i*4+s)*128 +: 128]
    reg [3*2-1:0] headp, tailp; // entry i: headp[i*2 +: 2]
    reg [3*3-1:0] occ;           // entry i: occ[i*3 +: 3]
    reg [3*3-1:0] credit;         // entry i: credit[i*3 +: 3]

    wire [3-1:0]        accept;
    wire [3*3-1:0]      va_req, va_gnt;   // [oc*NPORTS + p]
    wire [3*3-1:0]      sa_req, sa_gnt;
    reg  [3*3-1:0]      va_ptr;
    reg  [3*3-1:0]      sa_ptr;

    function [2:0] rc_port;
        input [3:0] x, y;
        begin
            if (y != MY_Y)      rc_port = (y > MY_Y) ? 2'd0 : 2'd2; // N; S illegal -> local fallback
            else if (x != MY_X) rc_port = (x > MY_X) ? 2'd1 : 2'd2; // E; W illegal -> local fallback
            else                rc_port = 2'd2;                     // local
        end
    endfunction

    genvar p, oc;
    generate
        for (p = 0; p < NPORTS; p = p + 1) begin : gp_acc
            assign accept[p] = valid_in[p] && (vc_in[p*2 +: 2] == 2'd0)
                && (credit[p*3 +: 3] > 0) && (occ[p*3 +: 3] < DEPTH);
            for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go_va
                assign va_req[oc*NPORTS + p] = accept[p]
                    && (type_in[p*2 +: 2] == 2'd0)
                    && (rc_port(flit_in[p*128 + 127 -: 4], flit_in[p*128 + 123 -: 4]) == oc)
                    && !vc_busy[oc];
                assign sa_req[oc*NPORTS + p] = (occ[p*3 +: 3] > 0) && (vc_port[p*3 +: 3] == oc);
            end
        end
        // One VA and one SA round-robin arbiter per output port
        for (oc = 0; oc < NPORTS; oc = oc + 1) begin : garb
            rr_arb #(.W(NPORTS)) u_va (
                .req(va_req[oc*NPORTS +: NPORTS]), .ptr(va_ptr[oc*NPORTS +: NPORTS]),
                .gnt(va_gnt[oc*NPORTS +: NPORTS]));
            rr_arb #(.W(NPORTS)) u_sa (
                .req(sa_req[oc*NPORTS +: NPORTS]), .ptr(sa_ptr[oc*NPORTS +: NPORTS]),
                .gnt(sa_gnt[oc*NPORTS +: NPORTS]));
        end
    endgenerate

    integer i, j, k, base;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vbuf <= 0; headp <= 0; tailp <= 0; occ <= 0;
            vc_dest <= 0; vc_port <= 0; vc_busy <= 0;
            va_ptr <= 0; sa_ptr <= 0;
            for (i = 0; i < NPORTS; i = i + 1) credit[i*3 +: 3] <= 3'd4;
            flit_out <= 0; valid_out <= 0; vc_out <= 0; type_out <= 0;
        end else begin
            for (i = 0; i < NPORTS; i = i + 1) begin
                if (accept[i] && type_in[(i)*2 +: 2] == 2'd0) begin
                    for (j = 0; j < NPORTS; j = j + 1) begin
                        if (va_gnt[j*NPORTS + i]) begin
                            vc_dest[i*8 +: 8] <= flit_in[i*128 + 127 -: 4];
                            vc_port[i*3 +: 3] <= j;
                            vc_busy[j] <= 1'b1;
                            for (k = 0; k < NPORTS; k = k + 1)
                                va_ptr[j*NPORTS + k] <= 1'b0;
                            va_ptr[j*NPORTS + ((i + 1) % NPORTS)] <= 1'b1;
                        end
                    end
                end
            end
            for (i = 0; i < NPORTS; i = i + 1) begin
                if (accept[i]) begin
                    base = i*4*128 + tailp[i*2 +: 2]*128;
                    vbuf[base +: 128] <= flit_in[i*128 +: 128];
                    tailp[i*2 +: 2] <= (tailp[i*2 +: 2] + 1) % DEPTH;
                    occ[i*3 +: 3] <= occ[i*3 +: 3] + 1;
                    credit[i*3 +: 3] <= credit[i*3 +: 3] - 1;
                end
            end
            for (j = 0; j < NPORTS; j = j + 1) begin
                for (i = 0; i < NPORTS; i = i + 1) begin
                    if (sa_gnt[j*NPORTS + i]) begin
                        base = (i*4 + headp[i*2 +: 2])*128;
                        vbuf[base +: 128] <= 0;
                        headp[i*2 +: 2] <= (headp[i*2 +: 2] + 1) % DEPTH;
                        occ[i*3 +: 3] <= occ[i*3 +: 3] + accept[i] - 1;
                        if (occ[i*3 +: 3] == 1 && !accept[i]) vc_busy[j] <= 1'b0;
                        flit_out[j*128 +: 128] <= vbuf[base +: 128];
                        valid_out[j] <= 1'b1;
                        vc_out[j*2 +: 2] <= 2'd0;
                        type_out[j*2 +: 2] <= vbuf[base + 119 -: 4];
                        for (k = 0; k < NPORTS; k = k + 1)
                            sa_ptr[j*NPORTS + k] <= 1'b0;
                        sa_ptr[j*NPORTS + ((i + 1) % NPORTS)] <= 1'b1;
                    end
                end
            end
            for (i = 0; i < NPORTS; i = i + 1)
                if (credit_ret[i] && credit[i*3 +: 3] < DEPTH)
                    credit[i*3 +: 3] <= credit[i*3 +: 3] + 1;
            for (j = 0; j < NPORTS; j = j + 1) begin
                if (!sa_gnt[j*NPORTS + 0] && !sa_gnt[j*NPORTS + 1] && !sa_gnt[j*NPORTS + 2])
                    valid_out[j] <= 1'b0;
            end
        end
    end
endmodule
