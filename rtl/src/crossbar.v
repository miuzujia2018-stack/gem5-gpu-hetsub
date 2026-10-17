// Crossbar — switch-grant datapath from buffer head slots to output registers
// (Table 3 column: Crossbar). rd_en drives the buffer read; clear_en drives the
// VC-table release.
module crossbar #(
    parameter NPORTS = 5,
    parameter NVC    = 2,
    parameter FLIT_W = 128
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*NPORTS-1:0] sa_gnt,
    input  wire [NPORTS*NVC*3-1:0] occ,
    input  wire [NPORTS*NVC*3-1:0] vc_port,
    input  wire [NPORTS*NVC*FLIT_W-1:0] head_data,
    output reg  [NPORTS*NVC-1:0] rd_en,
    output reg  [NPORTS*FLIT_W-1:0] flit_out,
    output reg  [NPORTS-1:0]        valid_out,
    output reg  [NPORTS*2-1:0]      vc_out,
    output reg  [NPORTS*2-1:0]      type_out
);
    function [1:0] sel_vc;
        input integer p; input integer oc;
        integer v;
        begin
            sel_vc = 0;
            for (v = 0; v < NVC; v = v + 1)
                if (occ[(p*NVC+v)*3 +: 3] > 0 && vc_port[(p*NVC+v)*3 +: 3] == oc) sel_vc = v[1:0];
        end
    endfunction

    integer j, q, e, g;
    always @* begin
        rd_en = 0;
        for (q = 0; q < NPORTS; q = q + 1)
            for (j = 0; j < NPORTS; j = j + 1)
                if (sa_gnt[j*NPORTS + q]) rd_en[q*NVC + sel_vc(q, j)] = 1'b1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flit_out <= 0; valid_out <= 0; vc_out <= 0; type_out <= 0;
        end else begin
            for (j = 0; j < NPORTS; j = j + 1) begin
                g = 0;
                for (q = 0; q < NPORTS; q = q + 1) begin
                    if (sa_gnt[j*NPORTS + q]) begin
                        g = g + 1;
                        e = q*NVC + sel_vc(q, j);
                        flit_out[j*FLIT_W +: FLIT_W] <= head_data[e*FLIT_W +: FLIT_W];
                        valid_out[j] <= 1'b1;
                        vc_out[j*2 +: 2] <= sel_vc(q, j);
                        type_out[j*2 +: 2] <= head_data[e*FLIT_W + (FLIT_W-9) -: 4];
                    end
                end
                if (g == 0) valid_out[j] <= 1'b0;
            end
        end
    end
endmodule
