// Baseline NoC router — 5 ports (N,E,S,W,local), 128-bit flit, 2 VC/vnet,
// data VC depth 4, control VC depth 1, 2-stage wormhole pipeline.
// Components: input VC buffers, credit counters, RC (XY DOR), VC allocator,
// switch allocator, crossbar, VC table. All storage is flat register vectors
// (flops), no memory blackboxes.
//
// Flit fields: dest [127:120] (x[127:124], y[123:120]),
//            type [119:116] (0=head, 1=body, 2=tail),
//            vc   [115:112], payload [111:0].
// Ports: 0=N, 1=E, 2=S, 3=W, 4=local.
//
// Field indexing: all per-(port,vc) state lives in flat vectors; entry i =
// p*NVC+vc. Multi-bit fields are accessed with fixed-width part-selects.

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
    output reg  [NPORTS*FLIT_W-1:0] flit_out,
    output reg  [NPORTS-1:0]        valid_out,
    output reg  [NPORTS*2-1:0]      vc_out,
    output reg  [NPORTS*2-1:0]      type_out
);
    localparam DEPTH0 = 4;   // data VC
    localparam DEPTH1 = 1;   // control VC

    // VC table: stored dest and allocated output port per input (port,vc)
    reg [NPORTS*NVC*8-1:0] vc_dest;   // field i: vc_dest[i*8 +: 8]
    reg [NPORTS*NVC*3-1:0] vc_port;   // field i: vc_port[i*3 +: 3]
    reg [NPORTS*NVC-1:0]   vc_busy;

    // Input VC buffers (register array)
    reg [NPORTS*NVC*DEPTH*FLIT_W-1:0] vbuf;   // slot (i,s): vbuf[(i*DEPTH+s)*128 +: 128]
    reg [NPORTS*NVC*2-1:0] headp, tailp;      // field i: headp[i*2 +: 2]
    reg [NPORTS*NVC*3-1:0] occ;               // field i: occ[i*3 +: 3]
    reg [NPORTS*NVC*3-1:0] credit;            // field i: credit[i*3 +: 3]

    // Stage-1 combinational signals
    wire [NPORTS*NVC-1:0]        accept;
    wire [NPORTS*NPORTS*NVC-1:0] va_req, va_gnt;
    wire [NPORTS*NPORTS-1:0]     sa_req, sa_gnt;
    reg  [NPORTS*NPORTS*NVC-1:0] va_ptr;
    reg  [NPORTS*NPORTS-1:0]     sa_ptr;

    // RC: XY dimension-ordered routing. MY_X/MY_Y fixed per instance.
    function [2:0] rc_port;
        input [3:0] x, y;
        input integer my_x, my_y;
        begin
            if (y != my_y)      rc_port = (y > my_y) ? 2'd0 : 2'd2; // N / S
            else if (x != my_x) rc_port = (x > my_x) ? 2'd1 : 2'd3; // E / W
            else                rc_port = 3'd4;                     // local
        end
    endfunction

    function integer depth_of;
        input integer vc;
        depth_of = (vc == 0) ? DEPTH0 : DEPTH1;
    endfunction

    genvar p, vc, oc;
    generate
        // Acceptance: credit available and buffer not full
        for (p = 0; p < NPORTS; p = p + 1) begin : gp_acc
            for (vc = 0; vc < NVC; vc = vc + 1) begin : gv_acc
                assign accept[p*NVC+vc] = valid_in[p] && (vc_in[p*2 +: 2] == vc)
                    && (credit[(p*NVC+vc)*3 +: 3] > 0)
                    && (occ[(p*NVC+vc)*3 +: 3] < depth_of(vc));
            end
        end

        // VA request: head flit, per (output port, input port, vc)
        for (p = 0; p < NPORTS; p = p + 1) begin : gp_va
            for (vc = 0; vc < NVC; vc = vc + 1) begin : gv_va
                for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go_va
                    assign va_req[oc*NPORTS*NVC + p*NVC + vc] =
                        accept[p*NVC+vc] && (type_in[p*2 +: 2] == 2'd0)
                        && (rc_port(flit_in[p*FLIT_W + 127 -: 4],
                                    flit_in[p*FLIT_W + 123 -: 4], MY_X, MY_Y) == oc)
                        && !vc_busy[oc*NVC + vc];
                end
            end
        end

        // SA request: buffered flit whose VC-table entry targets output port oc
        for (p = 0; p < NPORTS; p = p + 1) begin : gp_sa
            for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go_sa
                assign sa_req[oc*NPORTS + p] =
                    (occ[(p*NVC+0)*3 +: 3] > 0 && vc_port[(p*NVC+0)*3 +: 3] == oc) ||
                    (occ[(p*NVC+1)*3 +: 3] > 0 && vc_port[(p*NVC+1)*3 +: 3] == oc);
            end
        end

        // One VA and one SA round-robin arbiter per output port
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

    // Which VC on input port p targets output port oc
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
            vbuf     <= 0; headp <= 0; tailp <= 0; occ <= 0;
            vc_dest <= 0; vc_port <= 0; vc_busy <= 0;
            va_ptr  <= 0; sa_ptr <= 0;
            for (i = 0; i < NPORTS*NVC; i = i + 1)
                credit[i*3 +: 3] <= (i % NVC == 0) ? 3'd4 : 3'd1;
            flit_out <= 0; valid_out <= 0; vc_out <= 0; type_out <= 0;
        end else begin
            // VC allocation: head flit grants
            for (i = 0; i < NPORTS*NVC; i = i + 1) begin
                if (accept[i] && type_in[(i/NVC)*2 +: 2] == 2'd0) begin
                    for (j = 0; j < NPORTS; j = j + 1) begin
                        if (va_gnt[j*NPORTS*NVC + i]) begin
                            vc_dest[i*8 +: 8] <= flit_in[(i/NVC)*FLIT_W + 127 -: 4];
                            vc_port[i*3 +: 3] <= j;
                            vc_busy[j*NVC + (i % NVC)] <= 1'b1;
                            // rotate VA pointer past the granted candidate
                            for (k = 0; k < NPORTS*NVC; k = k + 1)
                                va_ptr[j*NPORTS*NVC + k] <= 1'b0;
                            va_ptr[j*NPORTS*NVC + ((i + 1) % (NPORTS*NVC))] <= 1'b1;
                        end
                    end
                end
            end
            // Buffer write on acceptance
            for (i = 0; i < NPORTS*NVC; i = i + 1) begin
                if (accept[i]) begin
                    base = i*DEPTH*FLIT_W + tailp[i*2 +: 2]*FLIT_W;
                    vbuf[base +: 128] <= flit_in[(i/NVC)*FLIT_W +: 128];
                    tailp[i*2 +: 2] <= (tailp[i*2 +: 2] + 1) % depth_of(i % NVC);
                    occ[i*3 +: 3] <= occ[i*3 +: 3] + 1;
                    credit[i*3 +: 3] <= credit[i*3 +: 3] - 1;
                end
            end
            // Crossbar read on switch grant (stage 2)
            for (j = 0; j < NPORTS; j = j + 1) begin
                for (i = 0; i < NPORTS; i = i + 1) begin
                    if (sa_gnt[j*NPORTS + i]) begin
                        k = sel_vc(i, j);
                        base = ((i*NVC + k)*DEPTH + headp[(i*NVC + k)*2 +: 2])*FLIT_W;
                        vbuf[base +: 128] <= 0;
                        headp[(i*NVC + k)*2 +: 2] <= (headp[(i*NVC + k)*2 +: 2] + 1) % depth_of(k);
                        occ[(i*NVC + k)*3 +: 3] <= occ[(i*NVC + k)*3 +: 3] + accept[i*NVC + k] - 1;
                        if (occ[(i*NVC + k)*3 +: 3] == 1 && !accept[i*NVC + k])
                            vc_busy[j*NVC + k] <= 1'b0;
                        // output register
                        flit_out[j*FLIT_W +: FLIT_W] <= vbuf[base +: 128];
                        valid_out[j] <= 1'b1;
                        vc_out[j*2 +: 2] <= k;
                        type_out[j*2 +: 2] <= vbuf[base + 119 -: 4];
                        // rotate SA pointer
                        for (k = 0; k < NPORTS; k = k + 1)
                            sa_ptr[j*NPORTS + k] <= 1'b0;
                        sa_ptr[j*NPORTS + ((i + 1) % NPORTS)] <= 1'b1;
                    end
                end
            end
            // Credit return from downstream
            for (i = 0; i < NPORTS*NVC; i = i + 1)
                if (credit_ret[i] && credit[i*3 +: 3] < depth_of(i % NVC))
                    credit[i*3 +: 3] <= credit[i*3 +: 3] + 1;

            for (j = 0; j < NPORTS; j = j + 1)
                if (!sa_gnt[j*NPORTS + 0] && !sa_gnt[j*NPORTS + 1] &&
                    !sa_gnt[j*NPORTS + 2] && !sa_gnt[j*NPORTS + 3] &&
                    !sa_gnt[j*NPORTS + 4]) valid_out[j] <= 1'b0;
        end
    end
endmodule
