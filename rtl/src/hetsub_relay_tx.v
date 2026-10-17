// HetSub relay serializer: 128-bit flit word -> 64-bit beats (byte stream, MSB-first).
// Bounded context: one pending beat + one held half-word. A presented beat stays
// valid until the consumer accepts it (ready_in). Partial tail: bytes_in < 16 on
// the last word emits a short final beat.
module hetsub_relay_tx (
    input  wire clk,
    input  wire rst,
    input  wire [127:0] data_in,
    input  wire [4:0]   bytes_in,   // valid bytes in word, 1..16
    input  wire valid_in,
    input  wire last_in,
    input  wire ready_in,           // downstream beat consumer ready
    output reg  [63:0] data_out,
    output reg  [3:0]  bytes_out,
    output reg  valid_out,
    output reg  last_out,
    output wire ready_out           // accepts next word when context is empty
);
    reg [63:0] pending;
    reg [3:0]  pending_b;
    reg pending_valid, pending_last;
    reg [63:0] half;
    reg [3:0]  half_b;
    reg half_valid, half_last;

    assign ready_out = !pending_valid && !half_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending <= 0; pending_b <= 0; pending_valid <= 0; pending_last <= 0;
            half <= 0; half_b <= 0; half_valid <= 0; half_last <= 0;
            data_out <= 0; bytes_out <= 0; valid_out <= 0; last_out <= 0;
        end else if (pending_valid) begin
            // Beat stays presented until the consumer accepts it.
            if (ready_in) begin
                if (half_valid) begin
                    pending <= half; pending_b <= half_b;
                    pending_last <= half_last; half_valid <= 1'b0;
                end else begin
                    pending_valid <= 1'b0;
                end
            end
        end else if (valid_in) begin
            pending <= data_in[127:64];
            pending_b <= (bytes_in > 5'd8) ? 4'd8 : bytes_in[3:0];
            pending_last <= last_in;
            pending_valid <= 1'b1;
            if (bytes_in > 5'd8) begin
                half <= data_in[63:0]; half_b <= bytes_in - 5'd8;
                half_last <= last_in; half_valid <= 1'b1;
            end
        end
    end

    // Outputs present the pending beat (registered copy, held until accepted).
    always @* begin
        data_out = pending;
        bytes_out = pending_b;
        last_out = pending_last;
        valid_out = pending_valid;
    end
endmodule
