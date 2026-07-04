`default_nettype none

module gulfwar2_palette_ram
(
    input  wire        clk,
    input  wire        reset,

    input  wire [23:0] cpu_addr,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire        palette_cs,
    input  wire        upper_sel,
    input  wire        lower_sel,
    input  wire [15:0] cpu_dout,
    output reg  [15:0] cpu_din,

    input  wire [10:0] render_addr,
    output reg  [15:0] render_data,
    output wire [23:0] render_rgb
);

localparam [10:0] PALETTE_WORDS = 11'd1792;

reg [15:0] palette_ram [0:1791];

wire [10:0] cpu_word_addr = cpu_addr[11:1];
wire        cpu_addr_valid = cpu_word_addr < PALETTE_WORDS;
wire        render_addr_valid = render_addr < PALETTE_WORDS;

function [15:0] merge_word;
    input [15:0] old_word;
    input [15:0] new_word;
    input        upper_en;
    input        lower_en;
    begin
        merge_word = old_word;
        if (upper_en) merge_word[15:8] = new_word[15:8];
        if (lower_en) merge_word[7:0] = new_word[7:0];
    end
endfunction

always @(posedge clk) begin
    if (reset) begin
        render_data <= 16'd0;
    end else begin
        if (cpu_write && palette_cs && cpu_addr_valid) begin
            palette_ram[cpu_word_addr] <= merge_word(palette_ram[cpu_word_addr], cpu_dout, upper_sel, lower_sel);
        end

        render_data <= render_addr_valid ? palette_ram[render_addr] : 16'd0;
    end
end

always @* begin
    cpu_din = 16'd0;
    if (cpu_read && palette_cs && cpu_addr_valid) cpu_din = palette_ram[cpu_word_addr];
end

// MAME models this RAM as xBGR_555: bit 15 unused, then B/G/R.
assign render_rgb = {
    render_data[4:0],   render_data[4:2],
    render_data[9:5],   render_data[9:7],
    render_data[14:10], render_data[14:12]
};

endmodule

`default_nettype wire
