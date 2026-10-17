// HetSub static long-link crossbar bypass (Algorithm 1 consumer).
// Static config per input port: enable, output port, hop budget (1..2).
// Legality: monotonic continuation only (no backtracking); local injection free.
// Exclusivity: one input per output; conflict rejected. A granted input is
// blocked from the normal M RC/VA path. Hop budget decrements per bypassed head.
module hetsub_bypass (
    input  wire clk,
    input  wire rst,
    input  wire [5*64-1:0] flit_in,
    input  wire [5-1:0]    valid_in,
    input  wire [5*2-1:0]  type_in,
    input  wire [5-1:0]    cfg_en,
    input  wire [5*3-1:0]  cfg_out,
    input  wire [5*2-1:0]  cfg_hop,
    output reg  [5*64-1:0] byp_flit,
    output reg  [5-1:0]    byp_valid,
    output reg  [5-1:0]    block,      // normal RC/VA path blocked for this input
    output reg  [5-1:0]    exclusive   // output port held exclusively by bypass
);
    // Hop budget storage. Equivalent formulation: keep the consumed count in
    // plain async-reset-to-0 FFs and derive the remaining budget combinationally
    // (hop = cfg_hop - used). The direct form (reset loads cfg_hop) needs an
    // async-load DFF, which Nangate45 does not provide, leaving FFs unmapped
    // (unknown area). This form maps every FF to a library DFF with identical
    // observable behavior: reset => used=0 (hop=cfg_hop), grant => used+1.
    reg [5*2-1:0] used;

    function legal;
        input integer p; input integer oc;
        begin
            if (p == 4) legal = 1;
            else if (p == 0) legal = (oc == 2 || oc == 4);
            else if (p == 1) legal = (oc == 3 || oc == 4);
            else if (p == 2) legal = (oc == 0 || oc == 4);
            else if (p == 3) legal = (oc == 1 || oc == 4);
            else legal = 0;
        end
    endfunction

    integer p, q, oc, cnt;
    reg [5-1:0] req, grant;
    always @* begin
        for (p = 0; p < 5; p = p + 1)
            req[p] = cfg_en[p] && used[p*2 +: 2] < cfg_hop[p*2 +: 2] && valid_in[p]
                && type_in[p*2 +: 2] == 2'd0 && legal(p, cfg_out[p*3 +: 3]);
        for (p = 0; p < 5; p = p + 1) begin
            oc = cfg_out[p*3 +: 3];
            cnt = 0;
            for (q = 0; q < 5; q = q + 1)
                if (req[q] && cfg_out[q*3 +: 3] == oc) cnt = cnt + 1;
            grant[p] = req[p] && cnt == 1;
        end
        for (p = 0; p < 5; p = p + 1) block[p] = grant[p];
        for (oc = 0; oc < 5; oc = oc + 1) begin
            exclusive[oc] = 0;
            byp_valid[oc] = 0;
            byp_flit[oc*64 +: 64] = 0;
            for (p = 0; p < 5; p = p + 1)
                if (grant[p] && cfg_out[p*3 +: 3] == oc) begin
                    exclusive[oc] = 1;
                    byp_valid[oc] = valid_in[p];
                    byp_flit[oc*64 +: 64] = flit_in[p*64 +: 64];
                end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (p = 0; p < 5; p = p + 1) used[p*2 +: 2] <= 2'd0;
        end else begin
            for (p = 0; p < 5; p = p + 1)
                if (grant[p]) used[p*2 +: 2] <= used[p*2 +: 2] + 1;
        end
    end
endmodule
