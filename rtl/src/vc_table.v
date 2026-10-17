// VC table — stored dest and allocated output port per entry (Table 3 column: VC Table).
// Entry i = p*NVC+vc. vc_busy is indexed by (output port, vc).
module vc_table #(
    parameter NPORTS = 5,
    parameter NVC    = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire [NPORTS*NPORTS*NVC-1:0] va_gnt,   // [oc*NPORTS*NVC + p*NVC + vc]
    input  wire [NPORTS*NVC-1:0] clear_en,        // vc_buffer drained flag (registered)
    input  wire [NPORTS*8-1:0] dest,              // dest field per input port
    output reg  [NPORTS*NVC*3-1:0] vc_port,
    output reg  [NPORTS*NVC-1:0] vc_busy
);
    reg [NPORTS*NVC*8-1:0] vc_dest;

    integer i, j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vc_dest <= 0; vc_port <= 0; vc_busy <= 0;
        end else begin
            for (i = 0; i < NPORTS*NVC; i = i + 1) begin
                for (j = 0; j < NPORTS; j = j + 1) begin
                    if (va_gnt[j*NPORTS*NVC + i]) begin
                        vc_dest[i*8 +: 8] <= dest[(i/NVC)*8 +: 8];
                        vc_port[i*3 +: 3] <= j;
                        vc_busy[j*NVC + (i % NVC)] <= 1'b1;
                    end
                end
            end
            // Entry drained: release its output-port VC
            for (i = 0; i < NPORTS*NVC; i = i + 1)
                if (clear_en[i])
                    vc_busy[vc_port[i*3 +: 3]*NVC + (i % NVC)] <= 1'b0;
        end
    end
endmodule
