// HetSub congestion-driven subnet selection + PG state machine.
// Hysteresis: sel=M when cong >= th_hi; sel=L when cong < th_lo; hold otherwise.
// PG states: OFF(0) -> WAKING(1) -> ON(2), wake latency counted in cycles.
// Safety: ON->OFF only when sel=L and no in-flight; m_enable (isolation control)
// is 0 unless ON, so M outputs stay isolated during OFF/WAKING.
module hetsub_select_pg (
    input  wire clk,
    input  wire rst,
    input  wire [7:0] cong,
    input  wire [7:0] th_hi,
    input  wire [7:0] th_lo,
    input  wire [3:0] wake_lat,
    input  wire m_inflight,
    output reg  sel,            // 0 = L subnet, 1 = M subnet
    output reg  [1:0] pg_state, // 0=OFF, 1=WAKING, 2=ON
    output reg  m_enable        // isolation: 1 only when ON
);
    reg [3:0] wake_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sel <= 1'b0; pg_state <= 2'd0; m_enable <= 1'b0; wake_cnt <= 0;
        end else begin
            if (cong >= th_hi) sel <= 1'b1;
            else if (cong < th_lo) sel <= 1'b0;
            if (pg_state == 2'd0) begin
                if (sel) begin
                    pg_state <= 2'd1;
                    wake_cnt <= 4'd0;
                end
            end else if (pg_state == 2'd1) begin
                if (wake_cnt >= wake_lat) pg_state <= 2'd2;
                else wake_cnt <= wake_cnt + 1;
            end else begin
                if (!sel && !m_inflight) pg_state <= 2'd0;
            end
            m_enable <= (pg_state == 2'd2);
        end
    end
endmodule
