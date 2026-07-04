`default_nettype none

module gulfwar2_sprite_ram
(
    input  wire        clk,
    input  wire        reset,

    input  wire [23:0] cpu_addr,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire        spriteram_cs,
    input  wire        upper_sel,
    input  wire        lower_sel,
    input  wire [15:0] cpu_dout,
    output reg  [15:0] cpu_din,

    input  wire        vblank_rise,
    output reg         copy_busy,

    input  wire [10:0] render_addr,
    output reg  [15:0] render_data
);

reg [15:0] live_ram [0:2047];
reg [15:0] buffered_ram [0:2047];
reg [10:0] copy_addr;

wire [10:0] cpu_word_addr = cpu_addr[11:1];

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
        copy_busy <= 1'b0;
        copy_addr <= 11'd0;
    end else begin
        if (cpu_write && spriteram_cs) begin
            live_ram[cpu_word_addr] <= merge_word(live_ram[cpu_word_addr], cpu_dout, upper_sel, lower_sel);
        end

        if (vblank_rise) begin
            copy_busy <= 1'b1;
            copy_addr <= 11'd0;
        end else if (copy_busy) begin
            buffered_ram[copy_addr] <= live_ram[copy_addr];
            copy_addr <= copy_addr + 11'd1;
            if (copy_addr == 11'h7ff) copy_busy <= 1'b0;
        end
    end
end

always @* begin
    cpu_din = 16'd0;
    if (cpu_read && spriteram_cs) cpu_din = live_ram[cpu_word_addr];
end

always @(posedge clk) begin
    render_data <= buffered_ram[render_addr];
end

endmodule

`default_nettype wire
