// Combinational round-robin arbiter with rotating pointer.
// Static-index formulation of the rotated-priority scan: equivalent to the
// original dynamic part-select version, but synthesis yields plain
// comparators instead of $shiftx cells (whose internal names corrupt the
// written netlist and break OpenSTA linking).
// Latch-free: each output bit gets an unconditional base assignment per
// iteration, and the rotated-rank comparison is evaluated inline — no
// intermediate regs that synthesis would turn into proc_dlatch cells.
module rr_arb #(parameter W = 5)(
    input  wire [W-1:0] req,
    input  wire [W-1:0] ptr,
    output reg  [W-1:0] gnt
);
    integer i, j;
    always @* begin
        for (i = 0; i < W; i = i + 1) begin
            gnt[i] = req[i];
            for (j = 0; j < W; j = j + 1) begin
                if (j != i && req[j] &&
                    ((j < ptr) ? (j + W - ptr) : (j - ptr)) <
                    ((i < ptr) ? (i + W - ptr) : (i - ptr)))
                    gnt[i] = 1'b0;
            end
        end
    end
endmodule
