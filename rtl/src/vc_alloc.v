// VC allocator — head-flit request + one round-robin arbiter per output port
// (Table 3 column: VA Unit).
module vc_alloc #(
    parameter NPORTS = 5,
    parameter NVC    = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*NVC-1:0] accept,
    input  wire [NPORTS*2-1:0] type_in,
    input  wire [NPORTS*3-1:0] rc,
    input  wire [NPORTS*NVC-1:0] vc_busy,
    output wire [NPORTS*NPORTS*NVC-1:0] va_gnt
);
    wire [NPORTS*NPORTS*NVC-1:0] va_req;
    reg  [NPORTS*NPORTS*NVC-1:0] va_ptr;

    genvar p, vc, oc;
    generate
        for (p = 0; p < NPORTS; p = p + 1) begin : gp
            for (vc = 0; vc < NVC; vc = vc + 1) begin : gv
                for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go
                    assign va_req[oc*NPORTS*NVC + p*NVC + vc] =
                        accept[p*NVC+vc] && (type_in[p*2 +: 2] == 2'd0)
                        && (rc[p*3 +: 3] == oc) && !vc_busy[oc*NVC + vc];
                end
            end
        end
        for (oc = 0; oc < NPORTS; oc = oc + 1) begin : garb
            rr_arb #(.W(NPORTS*NVC)) u_va (
                .req(va_req[oc*NPORTS*NVC +: NPORTS*NVC]),
                .ptr(va_ptr[oc*NPORTS*NVC +: NPORTS*NVC]),
                .gnt(va_gnt[oc*NPORTS*NVC +: NPORTS*NVC]));
        end
    endgenerate

    integer j, k;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            va_ptr <= 0;
        end else begin
            for (j = 0; j < NPORTS; j = j + 1) begin
                for (k = 0; k < NPORTS*NVC; k = k + 1) begin
                    if (va_gnt[j*NPORTS*NVC + k]) begin
                        // rotate pointer past the granted candidate
                        va_ptr[j*NPORTS*NVC +: NPORTS*NVC] <= 0;
                        va_ptr[j*NPORTS*NVC + ((k + 1) % (NPORTS*NVC))] <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
