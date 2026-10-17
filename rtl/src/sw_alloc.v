// Switch allocator — buffered-flit request + one round-robin arbiter per output
// port (Table 3 column: SA Unit).
module sw_alloc #(
    parameter NPORTS = 5,
    parameter NVC    = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*NVC*3-1:0] occ,
    input  wire [NPORTS*NVC*3-1:0] vc_port,
    input  wire [NPORTS-1:0]       exclusive,   // output held by bypass: no normal grant
    output wire [NPORTS*NPORTS-1:0] sa_gnt
);
    wire [NPORTS*NPORTS-1:0] sa_req;
    reg  [NPORTS*NPORTS-1:0] sa_ptr;

    genvar p, oc;
    generate
        for (p = 0; p < NPORTS; p = p + 1) begin : gp
            for (oc = 0; oc < NPORTS; oc = oc + 1) begin : go
                if (NVC == 1) begin
                    assign sa_req[oc*NPORTS + p] =
                        (occ[p*3 +: 3] > 0 && vc_port[p*3 +: 3] == oc) && !exclusive[oc];
                end else begin
                    assign sa_req[oc*NPORTS + p] =
                        ((occ[(p*NVC)*3 +: 3] > 0 && vc_port[(p*NVC)*3 +: 3] == oc) ||
                         (occ[(p*NVC+1)*3 +: 3] > 0 && vc_port[(p*NVC+1)*3 +: 3] == oc))
                        && !exclusive[oc];
                end
            end
        end
        for (oc = 0; oc < NPORTS; oc = oc + 1) begin : garb
            rr_arb #(.W(NPORTS)) u_sa (
                .req(sa_req[oc*NPORTS +: NPORTS]),
                .ptr(sa_ptr[oc*NPORTS +: NPORTS]),
                .gnt(sa_gnt[oc*NPORTS +: NPORTS]));
        end
    endgenerate

    integer j, k;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sa_ptr <= 0;
        end else begin
            for (j = 0; j < NPORTS; j = j + 1)
                for (k = 0; k < NPORTS; k = k + 1)
                    if (sa_gnt[j*NPORTS + k]) begin
                        sa_ptr[j*NPORTS +: NPORTS] <= 0;
                        sa_ptr[j*NPORTS + ((k + 1) % NPORTS)] <= 1'b1;
                    end
        end
    end
endmodule
