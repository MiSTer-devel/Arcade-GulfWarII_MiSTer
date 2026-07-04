module gw2_audio_mixer #(
    parameter int W0 = 16,
    parameter int W1 = 16,
    parameter int W2 = 16,
    parameter int W3 = 16,
    parameter int WOUT = 16
) (
    input  wire                         rst,
    input  wire                         clk,
    input  wire                         cen,
    input  wire signed [W0-1:0]         ch0,
    input  wire signed [W1-1:0]         ch1,
    input  wire signed [W2-1:0]         ch2,
    input  wire signed [W3-1:0]         ch3,
    input  wire        [7:0]            gain0,
    input  wire        [7:0]            gain1,
    input  wire        [7:0]            gain2,
    input  wire        [7:0]            gain3,
    output logic signed [WOUT-1:0]      mixed,
    output logic                        peak
);

localparam int ACCW = 32;
localparam signed [ACCW-1:0] OUT_MAX = (32'sd1 <<< (WOUT-1)) - 32'sd1;
localparam signed [ACCW-1:0] OUT_MIN = -(32'sd1 <<< (WOUT-1));

wire signed [ACCW-1:0] ch0_scaled = ($signed(ch0) * $signed({1'b0, gain0})) >>> 4;
wire signed [ACCW-1:0] ch1_scaled = ($signed(ch1) * $signed({1'b0, gain1})) >>> 4;
wire signed [ACCW-1:0] ch2_scaled = ($signed(ch2) * $signed({1'b0, gain2})) >>> 4;
wire signed [ACCW-1:0] ch3_scaled = ($signed(ch3) * $signed({1'b0, gain3})) >>> 4;
wire signed [ACCW-1:0] mix_sum = ch0_scaled + ch1_scaled + ch2_scaled + ch3_scaled;

always_ff @(posedge clk) begin
    if (rst) begin
        mixed <= '0;
        peak <= 1'b0;
    end else if (cen) begin
        if (mix_sum > OUT_MAX) begin
            mixed <= OUT_MAX[WOUT-1:0];
            peak <= 1'b1;
        end else if (mix_sum < OUT_MIN) begin
            mixed <= OUT_MIN[WOUT-1:0];
            peak <= 1'b1;
        end else begin
            mixed <= mix_sum[WOUT-1:0];
            peak <= 1'b0;
        end
    end
end

endmodule
