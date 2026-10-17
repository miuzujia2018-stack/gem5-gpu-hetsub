// RC unit — XY dimension-ordered routing (Table 3 column: RC Unit).
// xy[p*8 +: 8] is the dest field of input port p: x = [7:4], y = [3:0].
module rc_xy #(
    parameter NPORTS = 5,
    parameter MY_X   = 2,
    parameter MY_Y   = 2
)(
    input  wire [NPORTS*8-1:0] xy,
    output reg  [NPORTS*3-1:0] rc
);
    integer p;
    always @* begin
        for (p = 0; p < NPORTS; p = p + 1) begin
            if (xy[p*8 + 3 -: 4] != MY_Y)      rc[p*3 +: 3] = (xy[p*8 + 3 -: 4] > MY_Y) ? 2'd0 : 2'd2; // N / S
            else if (xy[p*8 + 7 -: 4] != MY_X) rc[p*3 +: 3] = (xy[p*8 + 7 -: 4] > MY_X) ? 2'd1 : 2'd3; // E / W
            else                               rc[p*3 +: 3] = 3'd4;                                     // local
        end
    end
endmodule
