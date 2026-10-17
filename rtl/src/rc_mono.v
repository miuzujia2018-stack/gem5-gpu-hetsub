// RC unit — L subnet monotonic order (Table 3 column: RC Unit).
// Ports: 0=N long-link, 1=E long-link, 2=local. Illegal turns (S/W) fall back
// to local, matching the frozen L-router behavior.
module rc_mono #(
    parameter MY_X = 2,
    parameter MY_Y = 2
)(
    input  wire [3*8-1:0] xy,
    output reg  [3*3-1:0] rc
);
    integer p;
    always @* begin
        for (p = 0; p < 3; p = p + 1) begin
            if (xy[p*8 + 3 -: 4] != MY_Y)      rc[p*3 +: 3] = (xy[p*8 + 3 -: 4] > MY_Y) ? 2'd0 : 2'd2; // N; S illegal -> local
            else if (xy[p*8 + 7 -: 4] != MY_X) rc[p*3 +: 3] = (xy[p*8 + 7 -: 4] > MY_X) ? 2'd1 : 2'd2; // E; W illegal -> local
            else                               rc[p*3 +: 3] = 2'd2;                                     // local
        end
    end
endmodule
