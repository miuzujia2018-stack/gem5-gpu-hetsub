// Input VC buffers + credit counters (Table 3 column: Flit Buffer/Logic).
// Register-array storage (flops), no memory blackbox. Entry i = p*NVC+vc.
// block[p] gates acceptance so bypass-granted inputs never enter the normal path.
module vc_buffer #(
    parameter NPORTS = 5,
    parameter NVC    = 2,
    parameter DEPTH0 = 4,   // data VC
    parameter DEPTH1 = 1,   // control VC
    parameter FLIT_W = 128
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*FLIT_W-1:0] flit_in,
    input  wire [NPORTS-1:0]        valid_in,
    input  wire [NPORTS*2-1:0]      vc_in,
    input  wire [NPORTS-1:0]        block,
    input  wire [NPORTS*NVC-1:0]    credit_ret,
    input  wire [NPORTS*NVC-1:0]    rd_en,      // crossbar read (switch grant)
    output wire [NPORTS*NVC-1:0]    accept,
    output reg  [NPORTS*NVC*3-1:0]  occ,
    output reg  [NPORTS*NVC*2-1:0]  headp,
    output reg  [NPORTS*NVC*3-1:0]  credit,
    output wire [NPORTS*NVC-1:0]    single,     // occ == 1
    output reg  [NPORTS*NVC-1:0]    drained,    // entry empties this edge (registered, race-free)
    output wire [NPORTS*NVC*FLIT_W-1:0] head_data
);
    reg [NPORTS*NVC*DEPTH0*FLIT_W-1:0] vbuf;   // slot (i,s): vbuf[(i*DEPTH0+s)*FLIT_W +: FLIT_W]
    reg [NPORTS*NVC*2-1:0] tailp;

    function integer depth_of;
        input integer vc;
        depth_of = (vc == 0) ? DEPTH0 : DEPTH1;
    endfunction

    genvar i;
    generate
        for (i = 0; i < NPORTS*NVC; i = i + 1) begin : g_ent
            assign accept[i] = valid_in[i/NVC] && (vc_in[(i/NVC)*2 +: 2] == (i % NVC))
                && !block[i/NVC]
                && (credit[i*3 +: 3] > 0)
                && (occ[i*3 +: 3] < depth_of(i % NVC));
            assign single[i] = (occ[i*3 +: 3] == 1);
            assign head_data[i*FLIT_W +: FLIT_W] =
                vbuf[(i*DEPTH0 + headp[i*2 +: 2])*FLIT_W +: FLIT_W];
        end
    endgenerate

    integer k, base;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vbuf <= 0; headp <= 0; tailp <= 0; occ <= 0; drained <= 0;
            for (k = 0; k < NPORTS*NVC; k = k + 1)
                credit[k*3 +: 3] <= (k % NVC == 0) ? 3'd4 : 3'd1;
        end else begin
            // Write on acceptance
            for (k = 0; k < NPORTS*NVC; k = k + 1) begin
                if (accept[k]) begin
                    base = k*DEPTH0*FLIT_W + tailp[k*2 +: 2]*FLIT_W;
                    vbuf[base +: FLIT_W] <= flit_in[(k/NVC)*FLIT_W +: FLIT_W];
                    tailp[k*2 +: 2] <= (tailp[k*2 +: 2] + 1) % depth_of(k % NVC);
                    occ[k*3 +: 3] <= occ[k*3 +: 3] + 1;
                    credit[k*3 +: 3] <= credit[k*3 +: 3] - 1;
                end
            end
            // Read on switch grant
            for (k = 0; k < NPORTS*NVC; k = k + 1) begin
                if (rd_en[k]) begin
                    base = k*DEPTH0*FLIT_W + headp[k*2 +: 2]*FLIT_W;
                    vbuf[base +: FLIT_W] <= 0;
                    headp[k*2 +: 2] <= (headp[k*2 +: 2] + 1) % depth_of(k % NVC);
                    occ[k*3 +: 3] <= occ[k*3 +: 3] + accept[k] - 1;
                end
                // Entry empties this edge: read of a single-occupancy entry with no
                // simultaneous accept. Evaluated from pre-edge occ (race-free).
                drained[k] <= rd_en[k] && (occ[k*3 +: 3] == 1) && !accept[k];
            end
            // Credit return from downstream
            for (k = 0; k < NPORTS*NVC; k = k + 1)
                if (credit_ret[k] && credit[k*3 +: 3] < depth_of(k % NVC))
                    credit[k*3 +: 3] <= credit[k*3 +: 3] + 1;
        end
    end
endmodule
