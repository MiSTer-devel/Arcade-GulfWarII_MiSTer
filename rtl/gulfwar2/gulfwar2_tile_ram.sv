`default_nettype none

module gulfwar2_tile_ram
(
    input  wire        clk,
    input  wire        reset,

    input  wire [23:0] cpu_addr,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire        upper_sel,
    input  wire        lower_sel,
    input  wire [15:0] cpu_dout,
    output wire [15:0] cpu_din,

    input  wire        tx_scroll_cs,
    input  wire        tx_offset_cs,
    input  wire        bg_scroll_cs,
    input  wire        bg_offset_cs,
    input  wire        fg_scroll_cs,
    input  wire        fg_offset_cs,
    input  wire        tx_vram_cs,
    input  wire        bg_vram_cs,
    input  wire        fg_vram_cs,
    input  wire        bg_ram_bank,

    output reg  [15:0] tx_scroll_x,
    output reg  [15:0] tx_scroll_y,
    output reg  [15:0] bg_scroll_x,
    output reg  [15:0] bg_scroll_y,
    output reg  [15:0] fg_scroll_x,
    output reg  [15:0] fg_scroll_y,

    input  wire [10:0] tx_scan_addr,
    output wire [15:0] tx_scan_data,
    input  wire [11:0] fg_scan_addr,
    output wire [15:0] fg_scan_data,
    input  wire [11:0] bg_scan_addr,
    output wire [15:0] bg_scan_data
);

reg [10:0] tx_offset;
reg [11:0] bg_offset;
reg [11:0] fg_offset;

wire [12:0] bg_cpu_addr = {bg_ram_bank, bg_offset};
wire [12:0] bg_render_addr = {bg_ram_bank, bg_scan_addr};
wire [15:0] tx_cpu_q;
wire [15:0] fg_cpu_q;
wire [15:0] bg_cpu_q;

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

wire [15:0] tx_offset_next = merge_word({5'd0, tx_offset}, cpu_dout, upper_sel, lower_sel);
wire [15:0] bg_offset_next = merge_word({4'd0, bg_offset}, cpu_dout, upper_sel, lower_sel);
wire [15:0] fg_offset_next = merge_word({4'd0, fg_offset}, cpu_dout, upper_sel, lower_sel);
wire [15:0] tx_write_data = merge_word(tx_cpu_q, cpu_dout, upper_sel, lower_sel);
wire [15:0] fg_write_data = merge_word(fg_cpu_q, cpu_dout, upper_sel, lower_sel);
wire [15:0] bg_write_data = merge_word(bg_cpu_q, cpu_dout, upper_sel, lower_sel);

always @(posedge clk) begin
    if (reset) begin
        tx_offset <= 11'd0;
        bg_offset <= 12'd0;
        fg_offset <= 12'd0;
        tx_scroll_x <= 16'd0;
        tx_scroll_y <= 16'd0;
        bg_scroll_x <= 16'd0;
        bg_scroll_y <= 16'd0;
        fg_scroll_x <= 16'd0;
        fg_scroll_y <= 16'd0;
    end else if (cpu_write) begin
        if (tx_offset_cs) tx_offset <= tx_offset_next[10:0];
        if (bg_offset_cs) bg_offset <= bg_offset_next[11:0];
        if (fg_offset_cs) fg_offset <= fg_offset_next[11:0];

        if (tx_scroll_cs && !cpu_addr[1]) tx_scroll_x <= merge_word(tx_scroll_x, cpu_dout, upper_sel, lower_sel);
        if (tx_scroll_cs &&  cpu_addr[1]) tx_scroll_y <= merge_word(tx_scroll_y, cpu_dout, upper_sel, lower_sel);
        if (bg_scroll_cs && !cpu_addr[1]) bg_scroll_x <= merge_word(bg_scroll_x, cpu_dout, upper_sel, lower_sel);
        if (bg_scroll_cs &&  cpu_addr[1]) bg_scroll_y <= merge_word(bg_scroll_y, cpu_dout, upper_sel, lower_sel);
        if (fg_scroll_cs && !cpu_addr[1]) fg_scroll_x <= merge_word(fg_scroll_x, cpu_dout, upper_sel, lower_sel);
        if (fg_scroll_cs &&  cpu_addr[1]) fg_scroll_y <= merge_word(fg_scroll_y, cpu_dout, upper_sel, lower_sel);
    end
end

assign cpu_din =
    (!cpu_read)  ? 16'd0 :
    tx_vram_cs  ? tx_cpu_q :
    bg_vram_cs  ? bg_cpu_q :
    fg_vram_cs  ? fg_cpu_q :
                   16'd0;

dual_port_ram #(.LEN(2048), .DATA_WIDTH(16)) tx_ram (
    .clock_a(clk),
    .address_a(tx_offset),
    .wren_a(cpu_write & tx_vram_cs),
    .data_a(tx_write_data),
    .q_a(tx_cpu_q),

    .clock_b(clk),
    .address_b(tx_scan_addr),
    .data_b(16'd0),
    .wren_b(1'b0),
    .q_b(tx_scan_data)
);

dual_port_ram #(.LEN(4096), .DATA_WIDTH(16)) fg_ram (
    .clock_a(clk),
    .address_a(fg_offset),
    .wren_a(cpu_write & fg_vram_cs),
    .data_a(fg_write_data),
    .q_a(fg_cpu_q),

    .clock_b(clk),
    .address_b(fg_scan_addr),
    .data_b(16'd0),
    .wren_b(1'b0),
    .q_b(fg_scan_data)
);

dual_port_ram #(.LEN(8192), .DATA_WIDTH(16)) bg_ram (
    .clock_a(clk),
    .address_a(bg_cpu_addr),
    .wren_a(cpu_write & bg_vram_cs),
    .data_a(bg_write_data),
    .q_a(bg_cpu_q),

    .clock_b(clk),
    .address_b(bg_render_addr),
    .data_b(16'd0),
    .wren_b(1'b0),
    .q_b(bg_scan_data)
);

endmodule

`default_nettype wire
