`default_nettype none

module gulfwar2_addr_decode
(
    input  wire [23:0] addr,
    input  wire        as_n,
    input  wire        uds_n,
    input  wire        lds_n,
    input  wire        rw,

    output wire        bus_cycle,
    output wire        bus_read,
    output wire        bus_write,
    output wire        upper_sel,
    output wire        lower_sel,

    output wire        rom_cs,
    output wire        mainram_cs,
    output wire        spriteram_cs,
    output wire        palette_cs,
    output wire        crtc_addr_cs,
    output wire        crtc_data_cs,

    output wire        tx_scroll_cs,
    output wire        tx_offset_cs,
    output wire        bg_scroll_cs,
    output wire        bg_offset_cs,
    output wire        fg_scroll_cs,
    output wire        fg_offset_cs,
    output wire        ex_scroll_cs,

    output wire        dswa_cs,
    output wire        dswb_cs,
    output wire        p1_cs,
    output wire        p2_cs,
    output wire        vblank_cs,
    output wire        coinlatch_fshark_cs,
    output wire        mainlatch_gulfwar2_cs,

    output wire        z80_shared_cs,
    output wire        tx_vram_cs,
    output wire        bg_vram_cs,
    output wire        fg_vram_cs
);

assign bus_cycle = !as_n;
assign upper_sel = bus_cycle && !uds_n;
assign lower_sel = bus_cycle && !lds_n;
assign bus_read  = bus_cycle && rw;
assign bus_write = bus_cycle && !rw;

wire [23:1] word_addr = addr[23:1];
wire        odd_byte  = addr[0];

assign rom_cs     = bus_cycle && (addr >= 24'h000000) && (addr <= 24'h02ffff);
assign mainram_cs = bus_cycle && (addr >= 24'h030000) && (addr <= 24'h033fff);
assign spriteram_cs = bus_cycle && (addr >= 24'h040000) && (addr <= 24'h040fff);
assign palette_cs   = bus_cycle && (addr >= 24'h050000) && (addr <= 24'h050dff);

assign crtc_addr_cs = bus_write && lower_sel && (addr == 24'h060001);
assign crtc_data_cs = bus_write && lower_sel && (addr == 24'h060003);

assign tx_scroll_cs = bus_write && (addr >= 24'h070000) && (addr <= 24'h070003);
assign tx_offset_cs = bus_write && (word_addr == 23'h038002);
assign bg_scroll_cs = bus_write && (addr >= 24'h072000) && (addr <= 24'h072003);
assign bg_offset_cs = bus_write && (word_addr == 23'h039002);
assign fg_scroll_cs = bus_write && (addr >= 24'h074000) && (addr <= 24'h074003);
assign fg_offset_cs = bus_write && (word_addr == 23'h03a002);
assign ex_scroll_cs = bus_write && (addr >= 24'h076000) && (addr <= 24'h076003);

assign dswa_cs   = bus_read && (word_addr == 23'h03c000);
assign dswb_cs   = bus_read && (word_addr == 23'h03c001);
assign p1_cs     = bus_read && (word_addr == 23'h03c002);
assign p2_cs     = bus_read && (word_addr == 23'h03c003);
assign vblank_cs = bus_read && (word_addr == 23'h03c004);

assign coinlatch_fshark_cs   = bus_write && lower_sel && odd_byte && (addr == 24'h07800b);
assign mainlatch_gulfwar2_cs = bus_write && lower_sel && odd_byte && (addr == 24'h07800d);

assign z80_shared_cs = bus_cycle && (addr >= 24'h07a000) && (addr <= 24'h07afff);
assign tx_vram_cs    = bus_cycle && (word_addr == 23'h03f000);
assign bg_vram_cs    = bus_cycle && (word_addr == 23'h03f001);
assign fg_vram_cs    = bus_cycle && (word_addr == 23'h03f002);

endmodule

`default_nettype wire
