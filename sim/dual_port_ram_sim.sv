`timescale 1ns/1ps

module dual_port_ram
#(
    parameter int LEN = 256,
    parameter int DATA_WIDTH = 16
)
(
    input  wire                        clock_a,
    input  wire [$clog2(LEN)-1:0]      address_a,
    input  wire                        wren_a,
    input  wire [DATA_WIDTH-1:0]       data_a,
    output reg  [DATA_WIDTH-1:0]       q_a,

    input  wire                        clock_b,
    input  wire [$clog2(LEN)-1:0]      address_b,
    input  wire                        wren_b,
    input  wire [DATA_WIDTH-1:0]       data_b,
    output reg  [DATA_WIDTH-1:0]       q_b
);

reg [DATA_WIDTH-1:0] mem [0:LEN-1];

always @(posedge clock_a) begin
    if (wren_a) mem[address_a] <= data_a;
    q_a <= mem[address_a];
end

always @(posedge clock_b) begin
    if (wren_b) mem[address_b] <= data_b;
    q_b <= mem[address_b];
end

endmodule
