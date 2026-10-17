// HetSub M router — 5 ports (0=N,1=E,2=S,3=W,4=local), 64-bit flit, 2 VC/vnet,
// data VC depth 4, control VC depth 1. Wormhole, 2-stage pipeline, flops storage.
// Flit fields: dest [63:56] (x[63:60], y[59:56]), type [55:52] (0=head,1=body,
// 2=tail), vc [51:48], payload [47:0]. XY DOR.
module hetsub_m_router #(
    parameter MY_X = 2,
    parameter MY_Y = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [5*64-1:0] flit_in,
    input  wire [5-1:0]        valid_in,
    input  wire [5*2-1:0]      vc_in,
    input  wire [5*2-1:0]      type_in,
    input  wire [5*2-1:0]      credit_ret,
    output reg  [5*64-1:0] flit_out,
    output reg  [5-1:0]        valid_out,
    output reg  [5*2-1:0]      vc_out,
    output reg  [5*2-1:0]      type_out
);
    localparam NPORTS = 5;
    localparam NVC    = 2;
    localparam DEPTH0 = 4;   // data VC
    localparam DEPTH1 = 1;   // control VC

    reg [10*8-1:0]  vc_dest;    // entry i: vc_dest[i*8 +: 8]
    reg [10*3-1:0]  vc_port;    // entry i: vc_port[i*3 +: 3]
    reg [10-1:0]    vc_busy;

    reg [10*4*64-1:0] vbuf;     // slot (i,s): vbuf[(i*4+s)*64 +: 64]
    reg [10*2-1:0] headp, tailp; // entry i: headp[i*2 +: 2]
    reg [10*3-1:0] occ;          // entry i: occ[i*3 +: 3]
    reg [10*3-1:0] credit;        // entry i: credit[i*3 +: 3]

    wire [10-1:0]        accept;
    wire [5*5*2-1:0]     va_req, va_gnt;   // [oc*NPORTS*NVC + p*NVC + vc]
    wire [5*5-1:0]       sa_req, sa_gnt;
    reg  [5*5*2-1:0]     va_ptr;
    reg  [5*5-1:0]       sa_ptr;

    function [2:0] rc_port;
        input [3:0] x, y;
        begin
            if (y != MY_Y)      rc_port = (y > MY_Y) ? 2'd0 : 2'd2;
            else if (x != MY_X) rc_port = (x > MY_X) ? 2'd1 : 2'd3;
            else                rc_port = 3'd4;
        end
    endfunction

    function integer depth_of;
        input integer vc;
        depth_of = (vc == 0) ? DEPTH0 : DEPTH1;
    endfunction

    genvar p, vc, oc;
    generate
        for (p = 0; p < NPORTS; p = p + 1) begin : gp_acc
            for (vc = 0; vc < NVC; vc = vc + 1) begin : gv_acc
                assign accept[p*NVC+vc] = valid_in[p] && (vc_in[p*2 +: 2] == vc)
                    && (credit[(p*NVC+vc)*3 +: 3] > 0)
                    && (occ[(p*NVC+vc)*3 +: 3] < depth_of(vc));
                for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go_va
                    assign va_req[oc*NPORTS*NVC + p*NVC + vc] =
                        accept[p*NVC+vc] && (type_in[p*2 +: 2] == 2'd0)
                        && (rc_port(flit_in[p*64 + 63 -: 4], flit_in[p*64 + 59 -: 4]) == oc)
                        && !vc_busy[oc*NVC + vc];
                end
            end
            for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go_sa
                assign sa_req[oc*NPORTS + p] =
                    (occ[(p*NVC+0)*3 +: 3] > 0 && vc_port[(p*NVC+0)*3 +: 3] == oc) ||
                    (occ[(p*NVC+1)*3 +: 3] > 0 && vc_port[(p*NVC+1)*3 +: 3] == oc);
            end
        end
        for (oc = 0; oc < NPORTS; oc = oc + 1) begin : garb
            rr_arb #(.W(NPORTS*NVC)) u_va (
                .req(va_req[oc*NPORTS*NVC +: NPORTS*NVC]),
                .ptr(va_ptr[oc*NPORTS*NVC +: NPORTS*NVC]),
                .gnt(va_gnt[oc*NPORTS*NVC +: NPORTS*NVC]));
            rr_arb #(.W(NPORTS)) u_sa (
                .req(sa_req[oc*NPORTS +: NPORTS]),
                .ptr(sa_ptr[oc*NPORTS +: NPORTS]),
                .gnt(sa_gnt[oc*NPORTS +: NPORTS]));
        end
    endgenerate

    function [1:0] sel_vc;
        input integer p; input integer oc;
        integer v;
        begin
            sel_vc = 0;
            for (v = 0; v < NVC; v = v + 1)
                if (occ[(p*NVC+v)*3 +: 3] > 0 && vc_port[(p*NVC+v)*3 +: 3] == oc) sel_vc = v[1:0];
        end
    endfunction

    integer i, j, k, base;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vbuf <= 0; headp <= 0; tailp <= 0; occ <= 0;
            vc_dest <= 0; vc_port <= 0; vc_busy <= 0;
            va_ptr <= 0; sa_ptr <= 0;
            for (i = 0; i < NPORTS*NVC; i = i + 1)
                credit[i*3 +: 3] <= (i % NVC == 0) ? 3'd4 : 3'd1;
            flit_out <= 0; valid_out <= 0; vc_out <= 0; type_out <= 0;
        end else begin
            for (i = 0; i < NPORTS*NVC; i = i + 1) begin
                if (accept[i] && type_in[(i/NVC)*2 +: 2] == 2'd0) begin
                    for (j = 0; j < NPORTS; j = j + 1) begin
                        if (va_gnt[j*NPORTS*NVC + i]) begin
                            vc_dest[i*8 +: 8] <= flit_in[(i/NVC)*64 + 63 -: 4];
                            vc_port[i*3 +: 3] <= j;
                            vc_busy[j*NVC + (i % NVC)] <= 1'b1;
                            for (k = 0; k < NPORTS*NVC; k = k + 1)
                                va_ptr[j*NPORTS*NVC + k] <= 1'b0;
                            va_ptr[j*NPORTS*NVC + ((i + 1) % (NPORTS*NVC))] <= 1'b1;
                        end
                    end
                end
            end
            for (i = 0; i < NPORTS*NVC; i = i + 1) begin
                if (accept[i]) begin
                    base = i*4*64 + tailp[i*2 +: 2]*64;
                    vbuf[base +: 64] <= flit_in[(i/NVC)*64 +: 64];
                    tailp[i*2 +: 2] <= (tailp[i*2 +: 2] + 1) % depth_of(i % NVC);
                    occ[i*3 +: 3] <= occ[i*3 +: 3] + 1;
                    credit[i*3 +: 3] <= credit[i*3 +: 3] - 1;
                end
            end
            for (j = 0; j < NPORTS; j = j + 1) begin
                for (i = 0; i < NPORTS; i = i + 1) begin
                    if (sa_gnt[j*NPORTS + i]) begin
                        k = sel_vc(i, j);
                        base = ((i*NVC + k)*4 + headp[(i*NVC + k)*2 +: 2])*64;
                        vbuf[base +: 64] <= 0;
                        headp[(i*NVC + k)*2 +: 2] <= (headp[(i*NVC + k)*2 +: 2] + 1) % depth_of(k);
                        occ[(i*NVC + k)*3 +: 3] <= occ[(i*NVC + k)*3 +: 3] + accept[i*NVC + k] - 1;
                        if (occ[(i*NVC + k)*3 +: 3] == 1 && !accept[i*NVC + k])
                            vc_busy[j*NVC + k] <= 1'b0;
                        flit_out[j*64 +: 64] <= vbuf[base +: 64];
                        valid_out[j] <= 1'b1;
                        vc_out[j*2 +: 2] <= k;
                        type_out[j*2 +: 2] <= vbuf[base + 55 -: 4];
                        for (k = 0; k < NPORTS; k = k + 1)
                            sa_ptr[j*NPORTS + k] <= 1'b0;
                        sa_ptr[j*NPORTS + ((i + 1) % NPORTS)] <= 1'b1;
                    end
                end
            end
            for (i = 0; i < NPORTS*NVC; i = i + 1)
                if (credit_ret[i] && credit[i*3 +: 3] < depth_of(i % NVC))
                    credit[i*3 +: 3] <= credit[i*3 +: 3] + 1;
            for (j = 0; j < NPORTS; j = j + 1) begin
                if (!sa_gnt[j*NPORTS + 0] && !sa_gnt[j*NPORTS + 1] && !sa_gnt[j*NPORTS + 2] &&
                    !sa_gnt[j*NPORTS + 3] && !sa_gnt[j*NPORTS + 4]) valid_out[j] <= 1'b0;
            end
        end
    end
endmodule
