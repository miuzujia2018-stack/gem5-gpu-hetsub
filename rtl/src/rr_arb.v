// Combinational round-robin arbiter with rotating pointer.
module rr_arb #(parameter W = 5)(
    input  wire [W-1:0] req,
    input  wire [W-1:0] ptr,
    output reg  [W-1:0] gnt
);
    integer i;
    reg found;
    always @* begin
        gnt   = {W{1'b0}};
        found = 1'b0;
        for (i = 0; i < W; i = i + 1) begin
            if (!found && req[(ptr + i) % W]) begin
                gnt[(ptr + i) % W] = 1'b1;
                found = 1'b1;
            end
        end
    end
endmodule
