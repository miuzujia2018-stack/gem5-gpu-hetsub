// HetSub relay deserializer: 64-bit beats -> 128-bit flit word (byte stream, MSB-first).
// Bounded context: at most one half-word. Backpressure via ready_in/ready_out.
// Partial tail: a short final beat completes the word with zero padding.
module hetsub_relay_rx (
    input  wire clk,
    input  wire rst,
    input  wire [63:0] data_in,
    input  wire [3:0]  bytes_in,
    input  wire valid_in,
    input  wire last_in,
    input  wire ready_in,
    output reg  [127:0] data_out,
    output reg  [4:0]   bytes_out,
    output reg  valid_out,
    output reg  last_out,
    output wire ready_out
);
    reg [63:0] acc;
    reg [3:0]  acc_bytes;
    reg acc_valid, acc_last;

    // rx accepts any beat when its downstream word output is ready:
    // it either stores the first half or completes the word, so readiness
    // passes through to the tx handshake.
    assign ready_out = ready_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc <= 0; acc_bytes <= 0; acc_valid <= 0; acc_last <= 0;
            data_out <= 0; bytes_out <= 0; valid_out <= 0; last_out <= 0;
        end else if (valid_in && ready_in) begin
            if (!acc_valid) begin
                if (last_in && bytes_in <= 4'd8) begin
                    data_out <= {data_in, 64'b0};
                    bytes_out <= {1'b0, bytes_in};
                    last_out <= last_in;
                    valid_out <= 1'b1;
                end else begin
                    acc <= data_in; acc_bytes <= bytes_in;
                    acc_last <= last_in; acc_valid <= 1'b1;
                    valid_out <= 1'b0;
                end
            end else begin
                data_out <= {acc, data_in};
                bytes_out <= acc_bytes + bytes_in;
                last_out <= last_in;
                valid_out <= 1'b1;
                acc_valid <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule
