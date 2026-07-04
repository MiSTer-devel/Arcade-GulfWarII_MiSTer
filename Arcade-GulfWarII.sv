//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================


module emu
(
	`include "sys/emu_ports.vh"
);


assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
`ifndef MISTER_FB
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
`endif
assign VGA_F1 = 1'b0;
assign VGA_SCALER = 1'b0;
assign VGA_DISABLE = 1'b0;
assign HDMI_FREEZE = 1'b0;
assign HDMI_BLACKOUT = 1'b0;
assign HDMI_BOB_DEINT = 1'b0;
`ifdef MISTER_FB
assign FB_FORCE_BLANK = 0;
`ifdef MISTER_FB_PALETTE
assign {FB_PAL_CLK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;
`endif
`endif

assign AUDIO_MIX = 2'd0;
assign LED_USER = ioctl_download & cpu_a[0] & & tms_addr & & tms_dout & & tms_rom_addr & & tms_rom_dout ;
assign LED_DISK = 2'd0;
assign LED_POWER = 2'd0;
assign BUTTONS = 2'd0;

// Status Bit Map:
//              Upper Case                     Lower Case           
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X  XXXXXXXX    X   XXXX XXXXXXXX            XXXXXXX      XXXXXXXX

wire [1:0] aspect_ratio = status[9:8];
wire       orientation  = ~status[3];
wire [2:0] scan_lines   = status[6:4];
reg        refresh_mod = 1'b0;
reg        new_vmode = 1'b0;

always @(posedge clk_sys) begin
    if (refresh_mod != status[19]) begin
        refresh_mod <= status[19];
        new_vmode <= ~new_vmode;
    end
end

wire [3:0] hs_offset = status[27:24];
wire [3:0] vs_offset = status[31:28];
wire [3:0] hs_width  = status[59:56];
wire [3:0] vs_width  = status[63:60];
wire       main_cpu_legacy_10mhz = status[49];

assign VIDEO_ARX = (!aspect_ratio) ? (orientation  ? 8'd4 : 8'd3) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (orientation  ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
    "Gulf War II;;",
    "-;",
    "P1,Video Settings;",
    "P1-;",
    "P1O89,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
    "P1O3,Orientation,Horz,Vert;",
    "P1-;",
    "P1O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%,CRT 100%;",
    "P1OA,Force Scandoubler,Off,On;",
    "P1-;",
    "P1OJ,Refresh Rate,Native 55Hz,60Hz Safe;",
    "P1-;",
    "P1OOR,H-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1OSV,V-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1-;",
    "P1oOR,H-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1oSV,V-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1-;",
    "P2,Audio Settings;",
    "P2-;",
    "P2oBC,YM3812 Level,100%,75%,50%,0%;",
    "P2-;",
    "-;",
    "P3,Core Options;",
    "P3-;",
    "P3o0,Slow Scroll Button,Off,On;",
    "P3-;",
    "P3o6,Swap P1/P2 Joystick,Off,On;",
    "P3-;",
    "P3oH,Main CPU,MAME 7MHz,Legacy 10MHz;",
    "P3-;",
    "DIP;",
    "-;",
    "OK,Pause OSD,Off,When Open;",
    "OL,Dim Video,Off,10s;",
    "-;",
    "R0,Reset;",
    "V,v",`BUILD_DATE
};

wire hps_forced_scandoubler;
wire forced_scandoubler = hps_forced_scandoubler | status[10];

wire  [1:0] buttons;
wire [127:0] status;
wire [15:0] status_menumask = {15'd0, direct_video};
wire [10:0] ps2_key;
wire [31:0] joy0_full, joy1_full;
wire [15:0] joy0 = joy0_full[15:0];
wire [15:0] joy1 = joy1_full[15:0];

hps_io #(
    .CONF_STR(CONF_STR),
    .WIDE(0),
    .BLKSZ(1)
) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),

    .buttons(buttons),
    .ps2_key(ps2_key),
    .status(status),
    .status_menumask(status_menumask),
    .forced_scandoubler(hps_forced_scandoubler),
    .gamma_bus(gamma_bus),
    .new_vmode(new_vmode),
    .direct_video(direct_video),
    .video_rotated(video_rotated),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joy0_full),
    .joystick_1(joy1_full)
);

// INPUT

// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wait;
wire        rom_download_wait;
assign ioctl_wait = rom_download_wait;
wire        ioctl_wr;
wire [15:0] ioctl_index;
wire [26:0] ioctl_addr;
wire [7:0]  ioctl_dout;
wire [7:0]  ioctl_din = 8'd0;

wire        tile_priority_type;
wire [15:0] scroll_y_offset;

wire [21:0] gamma_bus;

//<buttons names="Shot,Bomb,P1 Start,P2 Start,Coin,Pause" default="A,B,Start,Select,L,R"/>
// Inputs tied to z80_din
reg [7:0] p1;
reg [7:0] p2;
reg [7:0] z80_dswa;
reg [7:0] z80_dswb;
reg [7:0] z80_tjump;
reg [7:0] system;

always @ (posedge clk_sys ) begin
    p1        <= { 2'b00, p1_buttons[1:0], p1_right, p1_left, p1_down, p1_up };
    p2        <= { 2'b00, p2_buttons[1:0], p2_right, p2_left, p2_down, p2_up };
    z80_dswa  <= sw[0];
    z80_dswb  <= sw[1];
    z80_tjump <= sw[2];

    if ( status[32] == 1 ) begin
        system    <= { 1'b0, start2 | p1_buttons[3], start1 | p1_buttons[3], coin_b, coin_a, service | status[32], key_tilt, key_service };
    end else begin
        system    <= { 1'b0, start2,                 start1,                 coin_b, coin_a, service,              key_tilt, key_service };
    end
end

reg        p1_swap;

reg        p1_right;
reg        p1_left;
reg        p1_down;
reg        p1_up;
reg [3:0]  p1_buttons;

reg        p2_right;
reg        p2_left;
reg        p2_down;
reg        p2_up;
reg [3:0]  p2_buttons;

reg start1;
reg start2;
reg coin_a;
reg coin_b;
reg b_pause;
reg service;

always @ * begin
    p1_swap <= status[38];

        if ( status[38] == 0 ) begin
        p1_right   <= joy0[0]   | key_p1_right;
        p1_left    <= joy0[1]   | key_p1_left;
        p1_down    <= joy0[2]   | key_p1_down;
        p1_up      <= joy0[3]   | key_p1_up;
        p1_buttons <= {2'b00, joy0[5:4]} | {1'b0, key_p1_c, key_p1_b, key_p1_a};

        p2_right   <= joy1[0]   | key_p2_right;
        p2_left    <= joy1[1]   | key_p2_left;
        p2_down    <= joy1[2]   | key_p2_down;
        p2_up      <= joy1[3]   | key_p2_up;
        p2_buttons <= {2'b00, joy1[5:4]} | {1'b0, key_p2_c, key_p2_b, key_p2_a};
    end else begin
        p2_right   <= joy0[0]   | key_p1_right;
        p2_left    <= joy0[1]   | key_p1_left;
        p2_down    <= joy0[2]   | key_p1_down;
        p2_up      <= joy0[3]   | key_p1_up;
        p2_buttons <= {2'b00, joy0[5:4]} | {1'b0, key_p1_c, key_p1_b, key_p1_a};

        p1_right   <= joy1[0]   | key_p2_right;
        p1_left    <= joy1[1]   | key_p2_left;
        p1_down    <= joy1[2]   | key_p2_down;
        p1_up      <= joy1[3]   | key_p2_up;
        p1_buttons <= {2'b00, joy1[5:4]} | {1'b0, key_p2_c, key_p2_b, key_p2_a};
    end
end

always @ * begin
        start1    <= joy0[6]  | joy1[6]  | key_start_1p;
        start2    <= joy0[7]  | joy1[7]  | key_start_2p;

        coin_a    <= joy0[8]  | joy1[8]  | key_coin_a;
        coin_b    <= key_coin_b;

        b_pause   <= joy0[9] | key_pause;
        service   <= key_test;
end

// Keyboard handler

reg key_start_1p, key_start_2p, key_coin_a, key_coin_b;
reg key_tilt, key_test, key_reset, key_service, key_pause;

reg key_p1_up, key_p1_left, key_p1_down, key_p1_right, key_p1_a, key_p1_b, key_p1_c;
reg key_p2_up, key_p2_left, key_p2_down, key_p2_right, key_p2_a, key_p2_b, key_p2_c;

wire pressed = ps2_key[9];

always @(posedge clk_sys) begin
    reg old_state;
    old_state <= ps2_key[10];
    if ( old_state ^ ps2_key[10] ) begin
        casex ( ps2_key[8:0] )
            'h016 :  key_start_1p   <= pressed;            // 1
            'h01E :  key_start_2p   <= pressed;            // 2
            'h02E :  key_coin_a     <= pressed;            // 5
            'h036 :  key_coin_b     <= pressed;            // 6
            'h006 :  key_test       <= key_test ^ pressed; // f2
            'h004 :  key_reset      <= pressed;            // f3
            'h046 :  key_service    <= pressed;            // 9
            'h02C :  key_tilt       <= pressed;            // t
            'h04D :  key_pause      <= pressed;            // p

            'h175 :  key_p1_up      <= pressed;            // up
            'h172 :  key_p1_down    <= pressed;            // down
            'h16B :  key_p1_left    <= pressed;            // left
            'h174 :  key_p1_right   <= pressed;            // right
            'h014 :  key_p1_a       <= pressed;            // lctrl
            'h011 :  key_p1_b       <= pressed;            // lalt
            'h029 :  key_p1_c       <= pressed;            // spacebar

            'h02D :  key_p2_up      <= pressed;            // r
            'h02B :  key_p2_down    <= pressed;            // f
            'h023 :  key_p2_left    <= pressed;            // d
            'h034 :  key_p2_right   <= pressed;            // g
            'h01C :  key_p2_a       <= pressed;            // a
            'h01B :  key_p2_b       <= pressed;            // s
            'h015 :  key_p2_c       <= pressed;            // q
        endcase
    end
end

wire pll_locked;

wire clk_sys;
wire turbo_68k = 1'b0;
reg  clk_3_5M, clk_7M, clk_10M, clk_14M, clk_14M_N;

wire  clk_70M;

pll pll
(
    .refclk(CLK_50M),
    .rst(1'b0),
    .outclk_0(clk_sys),
    .outclk_1(clk_70M),
    .locked(pll_locked)
);

assign    SDRAM_CLK = clk_70M;

localparam  CLKSYS=70;

reg [5:0] clk14_count = 6'd0;
reg [5:0] clk10_count = 6'd0;
reg [5:0] clk7_count = 6'd0;
reg [5:0] clk_3_5_count = 6'd0;

wire clk7_tick = (clk7_count == 0);

always @ (posedge clk_sys ) begin
    clk_10M <= 0;
    clk_14M <= 0;
    clk_14M_N <= 0;
    clk_3_5M <= 0;

    if ( pause_cpu == 0 ) begin
        if ( turbo_68k == 0 ) begin
            // standard speed 20MHz = 10MHz 68k
            case (clk10_count)
                1: clk_10M <= 1;
                3: clk_10M <= 1;
            endcase
            if ( clk10_count == 6 ) begin
                clk10_count <= 0;
            end else begin
                clk10_count <= clk10_count + 1;
            end
        end else begin
            // standard speed 35MHz = 17.5MHz 68k
            case (clk10_count)
                1: clk_10M <= 1;
            endcase
            if ( clk10_count == 1 ) begin
                clk10_count <= 0;
            end else begin
                clk10_count <= clk10_count + 1;
            end
        end

        clk_14M <= ( clk14_count == 0);
        clk_14M_N <= ( clk14_count == 2);
        if ( clk14_count == 4 ) begin
            clk14_count <= 0;
        end else begin
            clk14_count <= clk14_count + 1;
        end

        clk_3_5M <= ( clk_3_5_count == 0);
        if ( clk_3_5_count == 19 ) begin
            clk_3_5_count <= 0;
        end else begin
            clk_3_5_count <= clk_3_5_count + 1;
        end
    end

    clk_7M <= clk7_tick;
    if ( clk7_count == 9 ) begin
        clk7_count <= 0;
    end else begin
        clk7_count <= clk7_count + 1;
    end
end

wire reset_req = RESET | status[0] | (ioctl_download & !ioctl_index) | buttons[1] | key_reset | !pll_locked;
reg [15:0] reset_release_count = 16'hffff;

always @(posedge clk_sys) begin
    if (reset_req) begin
        reset_release_count <= 16'hffff;
    end else if (reset_release_count != 16'd0) begin
        reset_release_count <= reset_release_count - 16'd1;
    end
end

wire reset = reset_req | (reset_release_count != 16'd0);

//////////////////////////////////////////////////////////////////
wire rotate_ccw = 1'b1;
wire no_rotate = orientation | direct_video;
wire flip = 1'b0;
`ifdef MISTER_FB
wire video_rotated;
`else
wire video_rotated = 1'b0;
`endif

reg [23:0] rgb;

wire hbl;
wire vbl;

wire [8:0] hc;
wire [8:0] vc;

wire hsync;
wire vsync;


localparam [8:0] GW_MAME_H_LAST       = 9'd445; // total 446, ~54.9 Hz native/MAME raster
localparam [8:0] GW_MAME_V_LAST       = 9'd285; // total 286
localparam [8:0] GW_NTSC_H_LAST       = 9'd444; // total 445, ~60.0 Hz analog-safe raster
localparam [8:0] GW_NTSC_V_LAST       = 9'd261; // total 262
localparam [8:0] GW_MAME_VISIBLE_H    = 9'd320;
localparam [8:0] GW_MAME_VISIBLE_V    = 9'd240;
localparam [8:0] GW_MAME_HSYNC_START  = 9'd360;
localparam [8:0] GW_MAME_HSYNC_END    = 9'd384;
localparam [8:0] GW_MAME_VSYNC_START  = 9'd244;
localparam [8:0] GW_MAME_VSYNC_END    = 9'd247;

reg  [8:0] gw_raster_hc;
reg  [8:0] gw_raster_vc;

wire [8:0] gw_raster_h_last = refresh_mod ? GW_NTSC_H_LAST : GW_MAME_H_LAST;
wire [8:0] gw_raster_v_last = refresh_mod ? GW_NTSC_V_LAST : GW_MAME_V_LAST;
// Render raw line 0 as soon as vblank starts. Starting only at the last
// couple vblank lines leaves too little runway and can expose stale line-buffer
// contents at the top of the unrotated picture.
wire [8:0] gw_top_prerender_v = GW_MAME_VISIBLE_V;

wire signed [10:0] gw_hs_pos_adj   = {{7{hs_offset[3]}}, hs_offset};
wire signed [10:0] gw_vs_pos_adj   = {{7{vs_offset[3]}}, vs_offset};
wire signed [10:0] gw_hs_width_adj = {{7{hs_width[3]}},  hs_width};
wire signed [10:0] gw_vs_width_adj = {{7{vs_width[3]}},  vs_width};
wire signed [10:0] gw_hsync_start  = $signed({2'b00, GW_MAME_HSYNC_START}) + gw_hs_pos_adj;
wire signed [10:0] gw_hsync_end    = $signed({2'b00, GW_MAME_HSYNC_END}) + gw_hs_pos_adj + gw_hs_width_adj;
wire signed [10:0] gw_vsync_start  = $signed({2'b00, GW_MAME_VSYNC_START}) + gw_vs_pos_adj;
wire signed [10:0] gw_vsync_end    = $signed({2'b00, GW_MAME_VSYNC_END}) + gw_vs_pos_adj + gw_vs_width_adj;
wire signed [10:0] gw_raster_hc_s = {2'b00, gw_raster_hc};
wire signed [10:0] gw_raster_vc_s = {2'b00, gw_raster_vc};
wire       gw_raster_reset = RESET | buttons[1];

always @(posedge clk_sys) begin
    if (gw_raster_reset) begin
        gw_raster_hc <= 9'd0;
        gw_raster_vc <= 9'd0;
    end else if (clk_7M) begin
        if (gw_raster_hc >= gw_raster_h_last) begin
            gw_raster_hc <= 9'd0;
            gw_raster_vc <= (gw_raster_vc >= gw_raster_v_last) ? 9'd0 : (gw_raster_vc + 9'd1);
        end else begin
            gw_raster_hc <= gw_raster_hc + 9'd1;
        end
    end
end

wire gw_raster_hblank = gw_raster_hc >= GW_MAME_VISIBLE_H;
wire gw_raster_vblank = gw_raster_vc >= GW_MAME_VISIBLE_V;
wire gw_raster_hsync  = ~((gw_raster_hc_s >= gw_hsync_start) && (gw_raster_hc_s < gw_hsync_end));
wire gw_raster_vsync  = ~((gw_raster_vc_s >= gw_vsync_start) && (gw_raster_vc_s < gw_vsync_end));

assign hc    = gw_raster_hc;
assign vc    = gw_raster_vc;
assign hbl   = gw_raster_hblank;
assign vbl   = gw_raster_vblank;
assign hsync = gw_raster_hsync;
assign vsync = gw_raster_vsync;

// MAME only inverts Gulf War II's readable VBLANK input bit. The screen
// vblank callback still drives sprite buffering and IRQs on physical vblank.
wire cpu_vblank = gw_raster_vblank;
wire gulfwar2_vblank_port = ~gw_raster_vblank;
wire [15:0] gw_vblank_dout = {8'hff, gulfwar2_vblank_port, 7'h7f};

wire [8:0] video_hc = gw_raster_hc;
wire [8:0] video_vc = gw_raster_vc;

// PAUSE SYSTEM
wire    pause_cpu;
wire    hs_pause;

// 8 bits per colour, 70MHz sys clk
pause #(8,8,8,70) pause
(
    .clk_sys(clk_sys),
    .reset(reset),
    .user_button(b_pause),
    .pause_request(hs_pause),
    .options(status[21:20]),
    .pause_cpu(pause_cpu),
    .dim_video(dim_video),
    .OSD_STATUS(OSD_STATUS),
    .r(rgb[23:16]),
    .g(rgb[15:8]),
    .b(rgb[7:0]),
    .rgb_out(rgb_pause_out)
);

wire [23:0] rgb_pause_out;
wire dim_video;

wire video_hblank = hbl;
wire video_vblank = vbl;
wire video_hsync  = hsync;
wire video_vsync  = vsync;

wire [23:0] video_rgb_core = gw_display_on ? rgb : 24'd0;

wire [7:0] arcade_vga_r, arcade_vga_g, arcade_vga_b;
wire       arcade_vga_hs, arcade_vga_vs, arcade_vga_de;
wire [1:0] arcade_vga_sl;

arcade_video #(320,24) arcade_video
(
        .clk_video(clk_sys),
        .ce_pix(clk_7M),

        .RGB_in(video_rgb_core),
        .HBlank(video_hblank),
        .VBlank(video_vblank),
        .HSync(video_hsync),
        .VSync(video_vsync),

        .CLK_VIDEO(CLK_VIDEO),
        .CE_PIXEL(CE_PIXEL),
        .VGA_R(arcade_vga_r),
        .VGA_G(arcade_vga_g),
        .VGA_B(arcade_vga_b),
        .VGA_HS(arcade_vga_hs),
        .VGA_VS(arcade_vga_vs),
        .VGA_DE(arcade_vga_de),
        .VGA_SL(arcade_vga_sl),

        .gamma_bus(gamma_bus),
        .fx(scan_lines),
        .forced_scandoubler(forced_scandoubler)
);

assign VGA_R = arcade_vga_r;
assign VGA_G = arcade_vga_g;
assign VGA_B = arcade_vga_b;
assign VGA_HS = arcade_vga_hs;
assign VGA_VS = arcade_vga_vs;
assign VGA_DE = arcade_vga_de;
assign VGA_SL = arcade_vga_sl;

`ifdef MISTER_FB
screen_rotate screen_rotate
(
        .CLK_VIDEO(CLK_VIDEO),
        .CE_PIXEL(CE_PIXEL),

        .VGA_R(arcade_vga_r),
        .VGA_G(arcade_vga_g),
        .VGA_B(arcade_vga_b),
        .VGA_HS(arcade_vga_hs),
        .VGA_VS(arcade_vga_vs),
        .VGA_DE(arcade_vga_de),

        .rotate_ccw(rotate_ccw),
        .no_rotate(no_rotate),
        .flip(flip),
        .video_rotated(video_rotated),

        .FB_EN(FB_EN),
        .FB_FORMAT(FB_FORMAT),
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .FB_BASE(FB_BASE),
        .FB_STRIDE(FB_STRIDE),
        .FB_VBL(FB_VBL),
        .FB_LL(FB_LL),

        .DDRAM_CLK(DDRAM_CLK),
        .DDRAM_BUSY(DDRAM_BUSY),
        .DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),
        .DDRAM_DIN(DDRAM_DIN),
        .DDRAM_BE(DDRAM_BE),
        .DDRAM_WE(DDRAM_WE),
        .DDRAM_RD(DDRAM_RD)
);
`endif

wire [9:0] sprite_adj_x = 0;
wire [9:0] sprite_adj_y = 0;
wire bcu_flip_cs;
wire fcu_flip_cs;

reg [1:0] adj_layer;
reg [15:0] scroll_adj_x [3:0];
reg [15:0] scroll_adj_y [3:0];
reg layer_en [3:0];

reg ce_pix;

reg tile_flip;
reg sprite_flip;

//assign vc = vcx - vs_offset;

// ===============================================================
// 68000 CPU
// ===============================================================

// Run the modern fx68k on the system clock and feed it one-cycle phase
// enables matching the selected board CPU cadence.
reg fx68_phase = 1'b0;
reg cpu_halt_by_dsp;
wire fx68_phase_step = main_cpu_legacy_10mhz ? clk_10M : clk_14M;
// Upstream fx68k marks HALTn as single-step-only; pause the CPU by withholding
// phase enables while the DSP owns the protection bus or the core is paused.
wire fx68_cpu_enable = !cpu_halt_by_dsp && !pause_cpu;

always @(posedge clk_sys) begin
    if (reset) begin
        fx68_phase <= 1'b0;
    end else if (fx68_phase_step == 1'b1 && fx68_cpu_enable) begin
        fx68_phase <= ~fx68_phase;
    end
end

wire fx68_modern_phi1 = fx68_phase_step & ~fx68_phase & fx68_cpu_enable;
wire fx68_modern_phi2 = fx68_phase_step &  fx68_phase & fx68_cpu_enable;
wire fx68_phi1 = fx68_modern_phi1;
wire fx68_phi2 = fx68_modern_phi2;
wire fx68_clk  = clk_sys;

// CPU outputs
wire cpu_rw;        // Read = 1, Write = 0
wire cpu_as_n;      // Address strobe
wire cpu_lds_n;     // Lower byte strobe
wire cpu_uds_n;     // Upper byte strobe
wire cpu_E;
wire [2:0]cpu_fc;   // Processor state
wire cpu_reset_n_o; // Reset output signal
wire cpu_halted_n;  // Halt output

// CPU busses
wire [15:0] cpu_dout;
wire [23:0] cpu_a;
reg  [15:0] cpu_din;
wire        cpu_decode_a0 = !cpu_lds_n && cpu_uds_n;
wire [23:0] gw_cpu_decode_addr = { cpu_a[23:1], cpu_decode_a0 };
wire        cpu_byte_write = (!cpu_uds_n) ^ (!cpu_lds_n);
wire [7:0]  cpu_write_byte =
    cpu_byte_write ? (cpu_dout[15:8] | cpu_dout[7:0]) :
    cpu_decode_a0  ? cpu_dout[7:0] :
                     cpu_dout[15:8];

// CPU inputs
reg  dtack_n;    // Data transfer ack
reg  ipl2_n;
// Keep CPU-owned registers/RAM on the selected 68K phase step, but gate
// modern fx68k writes with a real active bus cycle.
wire cpu_bus_write_safe = !cpu_rw && !cpu_as_n && (!cpu_uds_n || !cpu_lds_n);
wire cpu_bus_write = cpu_bus_write_safe;
wire cpu_write_strobe = fx68_phase_step && cpu_bus_write && fx68_cpu_enable;

wire reset_n;
wire sound_reset_n = ~reset & reset_n & reset_z80_n;
wire vpa_n = ~ ( cpu_lds_n == 0 && cpu_fc == 3'b111 );    // from outzone schematic

// The 16-bit 68K bus does not drive A0; keep the inherited reset marker on the
// unused bit so existing address decode expressions stay stable.
assign cpu_a[0] = reset;

cc_shifter cc_reset (
    .clk_out(clk_sys),
    .i(reset_z80_n),
    .o(reset_n)
);

fx68k fx68k (
    // input
    .clk( fx68_clk ),
    .HALTn(1'b1),
    .enPhi1(fx68_phi1),
    .enPhi2(fx68_phi2),
    .extReset(reset),
    .pwrUp(reset),

    // output
    .eRWn(cpu_rw),
    .ASn( cpu_as_n),
    .LDSn(cpu_lds_n),
    .UDSn(cpu_uds_n),
//    .E(cpu_E),
//    .VMAn(),
    .FC0(cpu_fc[0]),
    .FC1(cpu_fc[1]),
    .FC2(cpu_fc[2]),
//    .BGn(),
    .oRESETn(cpu_reset_n_o),
    .oHALTEDn(cpu_halted_n),

    // input
    .VPAn( vpa_n ),
    .DTACKn(dtack_n ),
    .BERRn(1'b1),
    .BRn(1'b1),
    .BGACKn(1'b1),
    
    .IPL0n(1'b1),
    .IPL1n(1'b1),
    .IPL2n(ipl2_n),

    // busses
    .iEdb(cpu_din),
    .oEdb(cpu_dout),
    .eab(cpu_a[23:1])
);

always @ (posedge clk_sys) begin
    if (reset) begin
        dtack_n <= 1'b1;
        cpu_din <= 16'd0;
    end else if (fx68_phase_step == 1'b1) begin
        // tell 68k to wait for valid data. 0=ready 1=wait
        // always ack when it's not program rom
        dtack_n <= prog_rom_cs ? !prog_rom_data_valid : 1'b0;

        // select cpu data input based on what is active
        cpu_din <= prog_rom_cs ? prog_rom_data :
            ram_cs ? ram_dout :
            sprite_ram_cs ? sprite_rb_dout :
            tile_palette_cs ?  tile_palette_cpu_dout :
            sprite_palette_cs ?  sprite_palette_cpu_dout :
            shared_ram_cs ? { 8'hff, cpu_shared_dout[7:0] } :
            tile_ofs_cs ? curr_tile_ofs :
            sprite_ofs_cs ? curr_sprite_ofs :
            tile_attr_cs ? cpu_tile_dout_attr :
            tile_num_cs ? cpu_tile_dout_num :
            sprite_0_cs ? sprite_0_dout :
            sprite_1_cs ? sprite_1_dout :
            sprite_2_cs ? sprite_2_dout :
            sprite_3_cs ? sprite_3_dout :
            frame_done_cs ? { 16 { cpu_vblank } } : // get vblank state
            vblank_cs ? gw_vblank_dout :
            gw_dswa_cs ? { 8'hff, z80_dswa } :
            gw_dswb_cs ? { 8'hff, z80_dswb } :
            gw_p1_cs ? { 8'hff, p1 } :
            gw_p2_cs ? { 8'hff, p2 } :
            int_en_cs ? 16'hffff :
            16'd0;
    end
end

reg         tms_reset;
reg   [7:0] tms_reset_count;
reg         dsp_rom_loaded;
reg         dsp_active;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        tms_reset_count <= 0;
        tms_reset <= 1 ;
    end else begin
        if ( tms_reset_count < 50 ) begin
            tms_reset_count <= tms_reset_count + 1;
        end else begin
            tms_reset <= 0 ;
        end
    end
end

gulfwar2_ika32010_dsp
#(
    .ROM_ADDR_SWAP_A0_A1(1'b0)
)
dsp
(
    .CLK(clk_sys),
    .RST_N(~reset),
    .EN(dsp_rom_loaded && dsp_active),

    .CE_F(clk_14M),         // Phased clocks for chip enable
    .CE_R(clk_14M_N),       // Chip enable clock phase

    .RS_N(~tms_reset),  // (RS) Reset for initializing the device
    .INT_N(tms_int_n),  // (INT) External interrupt input
    .BIO_N(tms_bio),  // (BIO_N) active-low external polling input

    .A(tms_addr),
    .DI(tms_din),
    .DO(tms_dout),

    .PC(tms_rom_addr),
    .ROM_Q(tms_rom_dout),

    .WE_N(tms_we_n),        // (WE) output data valid for OUT instruction
    .DEN_N(tms_den_n),      // (DEN) data enable for IN instruction
    .MEN_N(tms_men_n)       // (MEN) program/data memory read
);

wire [11:0] tms_addr ;
reg  [15:0] tms_din ;
wire [15:0] tms_dout ;
wire        tms_we_n;
wire        tms_den_n;
wire        tms_men_n;
reg         tms_bio;        // active-low BIO_N value driven by DSP port 3
reg         tms_int_n;
reg  [2:0]  dsp_host_seg;
reg         dsp_execute;
reg         dsp_halt_released;
reg  [2:0]  dsp_int_delay;
wire [15:0] shared_dsp_ram_dout;
reg  [15:0] shared_dsp_ram_din;
reg  [13:0] shared_dsp_ram_addr;
reg         shared_dsp_ram_w;
reg         shared_dsp_sprite_w;
reg         shared_dsp_palette_w;

wire        dsp_host_main_selected    = (dsp_host_seg == 3'h3);
wire        dsp_host_sprite_selected  = (dsp_host_seg == 3'h4);
wire        dsp_host_palette_selected = (dsp_host_seg == 3'h5);
wire [8:0]  shared_dsp_sprite_slot    = shared_dsp_ram_addr[10:2];
wire [1:0]  shared_dsp_sprite_word    = shared_dsp_ram_addr[1:0];
wire [9:0]  shared_dsp_palette_addr   = shared_dsp_ram_addr[9:0];
wire        shared_dsp_palette_tile   = shared_dsp_ram_addr[10];
wire [15:0] shared_dsp_sprite_dout =
    (shared_dsp_sprite_word == 2'd0) ? sprite_0_dout :
    (shared_dsp_sprite_word == 2'd1) ? sprite_1_dout :
    (shared_dsp_sprite_word == 2'd2) ? sprite_2_dout :
                                       sprite_3_dout;
wire [15:0] shared_dsp_palette_dout =
    shared_dsp_palette_tile ? tile_palette_cpu_dout : sprite_palette_cpu_dout;
wire [15:0] gw_dsp_port1_din_mux =
    dsp_host_main_selected    ? shared_dsp_ram_dout :
    dsp_host_sprite_selected  ? shared_dsp_sprite_dout :
    dsp_host_palette_selected ? shared_dsp_palette_dout :
                                16'd0;
wire        gw_tms_we_raw       = (tms_we_n == 1'b0);
wire        gw_tms_den_raw      = (tms_den_n == 1'b0);
wire [2:0]  gw_tms_port         = tms_addr[2:0];
wire        gw_tms_port_wr      = gw_tms_we_raw;
wire        gw_tms_port_rd      = gw_tms_den_raw;
wire        gw_tms_port0_wr     = gw_tms_port_wr && (gw_tms_port == 3'h0);
wire        gw_tms_port1_wr     = gw_tms_port_wr && (gw_tms_port == 3'h1);
wire        gw_tms_port1_rd     = gw_tms_port_rd && (gw_tms_port == 3'h1);
wire        gw_tms_port3_wr     = gw_tms_port_wr && (gw_tms_port == 3'h3);
wire [2:0]  gw_tms_port0_seg    = tms_dout[15:13];
wire        dsp_host_sprite_access =
    (dsp_active && dsp_host_sprite_selected && gw_tms_port1_rd) | shared_dsp_sprite_w;
wire        dsp_host_palette_access =
    (dsp_active && dsp_host_palette_selected && gw_tms_port1_rd) | shared_dsp_palette_w;
wire        gw_dsp_execute_set  =
    gw_tms_port1_wr && dsp_host_main_selected &&
    (shared_dsp_ram_addr[12:0] <= 13'd1) && (tms_dout == 16'd0);
wire        gw_tms_bio_release  = gw_tms_port3_wr && (tms_dout == 16'd0);
wire        gw_dsp_release_now  = gw_tms_bio_release && dsp_execute;

wire [15:0] cpu_shared_dout;
assign cpu_shared_dout[15:8] = 8'hff;
wire  [7:0] z80_shared_dout;
reg  [15:0] z80_a;

wire [15:0] z80_addr;
reg   [7:0] z80_din;
wire  [7:0] z80_dout;

wire z80_wr_n;
wire z80_rd_n;
reg  z80_wait_n;

wire IORQ_n;
wire MREQ_n;

wire ym3812_access = z80_sound0_cs || z80_sound1_cs;
wire ym3812_write_active = !z80_wr_n && ym3812_access;
wire [7:0] opl_dout;
wire opl_irq_n;

localparam [7:0] YM3812_ADDR_BUSY_TICKS = 8'd12;
localparam [7:0] YM3812_DATA_BUSY_TICKS = 8'd84;
localparam [4:0] YM3812_WR_HOLD_SYS     = 5'd8;

logic [7:0] ym3812_busy_ctr;
logic       ym3812_write_captured;
wire        ym3812_write_ready = ym3812_write_active && !ym3812_write_captured && (ym3812_busy_ctr == 8'd0);
wire        ym3812_wait = ym3812_access && (ym3812_busy_ctr != 8'd0) && !ym3812_write_ready;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        z80_wait_n <= 0;
    end else if ( clk_3_5M == 1 ) begin
        z80_wait_n <= 1;
        if ( ioctl_download |
             ( z80_rd_n == 0 && sound_rom_1_data_valid == 0 && sound_rom_1_cs == 1 ) |
             ym3812_wait ) begin
            // wait if rom is selected and data is not yet available
            z80_wait_n <= 0;
        end
        if ( z80_rd_n == 0 ) begin
            if ( sound_rom_1_cs ) begin
                if ( sound_rom_1_data_valid ) begin
                    z80_din <= sound_rom_1_data;
                end else begin
                    z80_wait_n <= 0;
                end
            end else if ( sound_ram_1_cs ) begin
                z80_din <= z80_shared_dout;
            end else if ( z80_p1_cs ) begin
                z80_din <= p1;
            end else if ( z80_p2_cs ) begin
                z80_din <= p2;
            end else if ( z80_dswa_cs ) begin
                z80_din <= z80_dswa;
            end else if ( z80_dswb_cs ) begin
                z80_din <= z80_dswb;
            end else if ( z80_tjump_cs ) begin
                z80_din <= z80_tjump;
            end else if ( z80_system_cs ) begin
                z80_din <= system;
            end else if ( z80_sound0_cs ) begin
                z80_din <= opl_dout;
            end else begin
                z80_din <= 8'h00;
            end
        end
    end
end

logic signed [15:0] opl2_sample;
wire opl2_sample_clk;
logic [7:0] ym3812_din;
logic ym3812_addr;
logic ym3812_wr;
logic [4:0] ym3812_wr_hold;

assign AUDIO_S = 1'b1;

always_ff @(posedge clk_sys) begin
    if (!sound_reset_n) begin
        ym3812_busy_ctr <= 8'd0;
        ym3812_write_captured <= 1'b0;
        ym3812_din <= 8'd0;
        ym3812_addr <= 1'b0;
        ym3812_wr <= 1'b0;
        ym3812_wr_hold <= 5'd0;
    end else begin
        if (!ym3812_write_active) begin
            ym3812_write_captured <= 1'b0;
        end

        if (clk_3_5M && (ym3812_busy_ctr != 8'd0)) begin
            ym3812_busy_ctr <= ym3812_busy_ctr - 8'd1;
        end

        if (ym3812_wr_hold != 5'd0) begin
            ym3812_wr_hold <= ym3812_wr_hold - 5'd1;
        end
        ym3812_wr <= (ym3812_wr_hold != 5'd0);

        if (ym3812_write_ready) begin
            ym3812_din <= z80_dout;
            ym3812_addr <= z80_sound1_cs;
            ym3812_write_captured <= 1'b1;
            ym3812_busy_ctr <= z80_sound1_cs ? YM3812_DATA_BUSY_TICKS : YM3812_ADDR_BUSY_TICKS;
            ym3812_wr_hold <= YM3812_WR_HOLD_SYS;
            ym3812_wr <= 1'b1;
        end
    end
end

opl2_fpga u_ym3812 (
    .clk(clk_sys),
    .clk_host(clk_sys),
    .clk_dac(clk_sys),
    .ic_n(sound_reset_n),
    .cs_n(!ym3812_wr),
    .rd_n(1'b1),
    .wr_n(!ym3812_wr),
    .address(ym3812_addr),
    .din(ym3812_din),
    .dout(opl_dout),
    .sample_valid(opl2_sample_clk),
    .sample(opl2_sample),
    .led(),
    .irq_n(opl_irq_n)
);

logic signed [15:0] ym3812_sample_sys;
logic signed [15:0] ym3812_music_sample_sys;
logic signed [15:0] ym3812_sfx_sample_sys;
logic ym3812_sample_toggle_sys;

always_ff @(posedge clk_sys) begin
    if (!sound_reset_n) begin
        ym3812_sample_sys <= 16'sd0;
        ym3812_music_sample_sys <= 16'sd0;
        ym3812_sfx_sample_sys <= 16'sd0;
        ym3812_sample_toggle_sys <= 1'b0;
    end else if (opl2_sample_clk) begin
        ym3812_sample_sys <= opl2_sample;
        ym3812_music_sample_sys <= opl2_sample;
        ym3812_sfx_sample_sys <= 16'sd0;
        ym3812_sample_toggle_sys <= ~ym3812_sample_toggle_sys;
    end
end

logic [1:0] audio_reset_sync;
logic [1:0] audio_pause_sync;
logic [2:0] ym3812_sample_toggle_audio;
logic [5:0] ym3812_level_audio_meta;
logic [5:0] ym3812_level_audio;
logic ym3812_filter_valid;
logic signed [15:0] ym3812_sample_raw_audio;
logic signed [15:0] ym3812_sample_filtered_audio;
logic signed [15:0] ym3812_music_raw_audio;
logic signed [15:0] ym3812_music_filtered_audio;
logic signed [15:0] ym3812_sfx_raw_audio;
logic signed [15:0] ym3812_sfx_filtered_audio;
wire signed [16:0] ym3812_filter_sum =
    {ym3812_sample_sys[15], ym3812_sample_sys} +
    {ym3812_sample_raw_audio[15], ym3812_sample_raw_audio};
wire signed [16:0] ym3812_music_filter_sum =
    {ym3812_music_sample_sys[15], ym3812_music_sample_sys} +
    {ym3812_music_raw_audio[15], ym3812_music_raw_audio};
wire signed [16:0] ym3812_sfx_filter_sum =
    {ym3812_sfx_sample_sys[15], ym3812_sfx_sample_sys} +
    {ym3812_sfx_raw_audio[15], ym3812_sfx_raw_audio};

function automatic [7:0] ym3812_gain_from_level(input [1:0] level);
begin
    case (level)
        2'd0: ym3812_gain_from_level = 8'h10; // 100%
        2'd1: ym3812_gain_from_level = 8'h0c; // 75%
        2'd2: ym3812_gain_from_level = 8'h08; // 50%
        default: ym3812_gain_from_level = 8'h00; // 0%
    endcase
end
endfunction

wire [7:0] ym3812_master_gain = ym3812_gain_from_level(ym3812_level_audio[1:0]);
wire [7:0] ym3812_music_gain  = ym3812_gain_from_level(ym3812_level_audio[3:2]);
wire [7:0] ym3812_sfx_gain    = ym3812_gain_from_level(ym3812_level_audio[5:4]);
wire [15:0] ym3812_music_gain_product = ym3812_master_gain * ym3812_music_gain;
wire [15:0] ym3812_sfx_gain_product   = ym3812_master_gain * ym3812_sfx_gain;
wire [7:0] ym3812_music_mix_gain = ym3812_music_gain_product[11:4];
wire [7:0] ym3812_sfx_mix_gain   = ym3812_sfx_gain_product[11:4];
wire signed [15:0] ym3812_mixed_audio;
wire ym3812_mix_peak;

gw2_audio_mixer #(.W0(16), .W1(16), .WOUT(16)) u_ym3812_mix (
    .rst    ( reset || audio_reset_sync[1] ),
    .clk    ( CLK_AUDIO ),
    .cen    ( 1'b1 ),
    .ch0    ( ym3812_music_filtered_audio ),
    .ch1    ( ym3812_sfx_filtered_audio ),
    .ch2    ( 16'sd0 ),
    .ch3    ( 16'sd0 ),
    .gain0  ( ym3812_music_mix_gain ),
    .gain1  ( ym3812_sfx_mix_gain ),
    .gain2  ( 8'd0 ),
    .gain3  ( 8'd0 ),
    .mixed  ( ym3812_mixed_audio ),
    .peak   ( ym3812_mix_peak )
);

always_ff @(posedge CLK_AUDIO) begin
    if (reset) begin
        audio_reset_sync <= 2'b11;
    end else begin
        audio_reset_sync <= {audio_reset_sync[0], 1'b0};
    end

    if (reset || audio_reset_sync[1]) begin
        audio_pause_sync <= 2'b00;
        ym3812_sample_toggle_audio <= {3{ym3812_sample_toggle_sys}};
        ym3812_level_audio_meta <= 6'd0;
        ym3812_level_audio <= 6'd0;
        ym3812_filter_valid <= 1'b0;
        ym3812_sample_raw_audio <= 16'sd0;
        ym3812_sample_filtered_audio <= 16'sd0;
        ym3812_music_raw_audio <= 16'sd0;
        ym3812_music_filtered_audio <= 16'sd0;
        ym3812_sfx_raw_audio <= 16'sd0;
        ym3812_sfx_filtered_audio <= 16'sd0;
        AUDIO_L <= 16'sd0;
        AUDIO_R <= 16'sd0;
    end else begin
        audio_pause_sync <= {audio_pause_sync[0], pause_cpu};
        ym3812_sample_toggle_audio <= {ym3812_sample_toggle_audio[1:0], ym3812_sample_toggle_sys};
        ym3812_level_audio_meta <= {2'd3, 2'd0, status[44:43]};
        ym3812_level_audio <= ym3812_level_audio_meta;

        if (ym3812_sample_toggle_audio[2] ^ ym3812_sample_toggle_audio[1]) begin
            ym3812_sample_raw_audio <= ym3812_sample_sys;
            ym3812_sample_filtered_audio <= ym3812_filter_valid ? ym3812_filter_sum[16:1] : ym3812_sample_sys;
            ym3812_music_raw_audio <= ym3812_music_sample_sys;
            ym3812_music_filtered_audio <= ym3812_filter_valid ? ym3812_music_filter_sum[16:1] : ym3812_music_sample_sys;
            ym3812_sfx_raw_audio <= ym3812_sfx_sample_sys;
            ym3812_sfx_filtered_audio <= ym3812_filter_valid ? ym3812_sfx_filter_sum[16:1] : ym3812_sfx_sample_sys;
            ym3812_filter_valid <= 1'b1;
        end

        if (audio_pause_sync[1]) begin
            AUDIO_L <= 16'sd0;
            AUDIO_R <= 16'sd0;
        end else begin
            AUDIO_L <= ym3812_mixed_audio;
            AUDIO_R <= ym3812_mixed_audio;
        end
    end
end

T80pa u_cpu(
    .RESET_n    ( sound_reset_n ),
    .CLK        ( clk_sys ),
    .CEN_p      ( clk_3_5M ),
    .CEN_n      ( ~clk_3_5M ),

    .WAIT_n     ( z80_wait_n ), // don't wait if data is valid or rom access isn't selected
    .INT_n      ( opl_irq_n ),  // opl timer
    .NMI_n      ( 1'b1 ),
    .BUSRQ_n    ( 1'b1 ),
    .RD_n       ( z80_rd_n ),
    .WR_n       ( z80_wr_n ),
    .A          ( z80_addr ),
    .DI         ( z80_din  ),
    .DO         ( z80_dout ),
    // unused
    .DIRSET     ( 1'b0     ),
    .DIR        ( 212'b0   ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     ( IORQ_n ),
    .M1_n       (),
    .BUSAK_n    (),
    .HALT_n     (),
    .MREQ_n     ( MREQ_n ),
    .R800_mode  ( 1'b0 ),
    .REG        ()
);

// Chip select mux
wire prog_rom_cs;
wire scroll_ofs_x_cs;
wire scroll_ofs_y_cs;
wire ram_cs;
wire vblank_cs;
wire int_en_cs;
wire reset_z80_cs;
wire crtc_cs;
wire tile_ofs_cs;
wire tile_attr_cs;
wire tile_num_cs;
wire scroll_cs;
wire shared_ram_cs;
wire frame_done_cs; // word
wire tile_palette_cs;
wire sprite_palette_cs;
wire sprite_ofs_cs;
wire sprite_cs; // *** offset needs to be auto-incremented
wire sprite_ram_cs;

wire dsp_ctrl_cs;
wire dsp_addr_cs;
wire dsp_r_cs;
wire dsp_bio_cs;

//TMS32010 mapping may not be necessary here or the chipselect
//wire dsp_rom_1_cs;    // map(0x000, 0x7ff).rom();

wire z80_p1_cs;
wire z80_p2_cs;
wire z80_dswa_cs;
wire z80_dswb_cs;
wire z80_system_cs;
wire z80_tjump_cs;
wire z80_sound0_cs;
wire z80_sound1_cs;

wire gw_bus_cycle;
wire gw_bus_read;
wire gw_bus_write;
wire gw_upper_sel;
wire gw_lower_sel;
wire gw_rom_cs;
wire gw_mainram_cs;
wire gw_spriteram_cs;
wire gw_palette_cs;
wire gw_crtc_addr_cs;
wire gw_crtc_data_cs;
wire gw_tx_scroll_cs;
wire gw_tx_offset_cs;
wire gw_bg_scroll_cs;
wire gw_bg_offset_cs;
wire gw_fg_scroll_cs;
wire gw_fg_offset_cs;
wire gw_ex_scroll_cs;
wire gw_dswa_cs;
wire gw_dswb_cs;
wire gw_p1_cs;
wire gw_p2_cs;
wire gw_vblank_cs;
wire gw_coinlatch_fshark_cs;
wire gw_mainlatch_gulfwar2_cs;
wire gw_z80_shared_cs;
wire gw_tx_vram_cs;
wire gw_bg_vram_cs;
wire gw_fg_vram_cs;
wire gw_crtc_addr_eff_cs;
wire gw_crtc_data_eff_cs;

gulfwar2_addr_decode u_gulfwar2_addr_decode
(
    .addr(gw_cpu_decode_addr),
    .as_n(cpu_as_n),
    .uds_n(cpu_uds_n),
    .lds_n(cpu_lds_n),
    .rw(cpu_rw),

    .bus_cycle(gw_bus_cycle),
    .bus_read(gw_bus_read),
    .bus_write(gw_bus_write),
    .upper_sel(gw_upper_sel),
    .lower_sel(gw_lower_sel),

    .rom_cs(gw_rom_cs),
    .mainram_cs(gw_mainram_cs),
    .spriteram_cs(gw_spriteram_cs),
    .palette_cs(gw_palette_cs),
    .crtc_addr_cs(gw_crtc_addr_cs),
    .crtc_data_cs(gw_crtc_data_cs),

    .tx_scroll_cs(gw_tx_scroll_cs),
    .tx_offset_cs(gw_tx_offset_cs),
    .bg_scroll_cs(gw_bg_scroll_cs),
    .bg_offset_cs(gw_bg_offset_cs),
    .fg_scroll_cs(gw_fg_scroll_cs),
    .fg_offset_cs(gw_fg_offset_cs),
    .ex_scroll_cs(gw_ex_scroll_cs),

    .dswa_cs(gw_dswa_cs),
    .dswb_cs(gw_dswb_cs),
    .p1_cs(gw_p1_cs),
    .p2_cs(gw_p2_cs),
    .vblank_cs(gw_vblank_cs),
    .coinlatch_fshark_cs(gw_coinlatch_fshark_cs),
    .mainlatch_gulfwar2_cs(gw_mainlatch_gulfwar2_cs),

    .z80_shared_cs(gw_z80_shared_cs),
    .tx_vram_cs(gw_tx_vram_cs),
    .bg_vram_cs(gw_bg_vram_cs),
    .fg_vram_cs(gw_fg_vram_cs)
);

assign gw_crtc_addr_eff_cs      = gw_crtc_addr_cs;
assign gw_crtc_data_eff_cs      = gw_crtc_data_cs;
wire gw_coinlatch_eff_cs = gw_coinlatch_fshark_cs |
    (gw_bus_write && (gw_cpu_decode_addr[23:1] == 23'h03c005));
wire gw_mainlatch_eff_cs = gw_mainlatch_gulfwar2_cs |
    (gw_bus_write && (gw_cpu_decode_addr[23:1] == 23'h03c006));
wire [7:0] gw_latch_data =
    cpu_byte_write ? (cpu_dout[15:8] | cpu_dout[7:0]) : cpu_dout[7:0];

wire gw_z80_mem_read;
wire gw_z80_mem_write;
wire gw_z80_io_read;
wire gw_z80_io_write;
wire gw_z80_rom_cs;
wire gw_z80_shared_ram_cs;
wire gw_ym3812_cs;
wire gw_ym3812_addr;
wire gw_z80_system_cs;
wire gw_z80_coinlatch_cs;
wire gw_z80_dswa_cs;
wire gw_z80_dswb_cs;

gulfwar2_sound_decode u_gulfwar2_sound_decode
(
    .addr(z80_addr),
    .mreq_n(MREQ_n),
    .iorq_n(IORQ_n),
    .rd_n(z80_rd_n),
    .wr_n(z80_wr_n),

    .mem_read(gw_z80_mem_read),
    .mem_write(gw_z80_mem_write),
    .io_read(gw_z80_io_read),
    .io_write(gw_z80_io_write),

    .rom_cs(gw_z80_rom_cs),
    .shared_ram_cs(gw_z80_shared_ram_cs),
    .ym3812_cs(gw_ym3812_cs),
    .ym3812_addr(gw_ym3812_addr),
    .system_cs(gw_z80_system_cs),
    .coinlatch_cs(gw_z80_coinlatch_cs),
    .dswa_cs(gw_z80_dswa_cs),
    .dswb_cs(gw_z80_dswb_cs)
);

wire gw_mainlatch_write    = cpu_write_strobe && gw_mainlatch_eff_cs;
wire gw_coinlatch_write    = cpu_write_strobe && gw_coinlatch_eff_cs;
wire gw_z80_coinlatch_write = clk_3_5M && gw_z80_coinlatch_cs;

wire       gw_irq4_enable;
wire       gw_flip_screen;
wire       gw_bg_ram_bank;
wire       gw_fg_rom_bank;
wire       gw_dsp_int_gulfwar2;
wire       gw_display_on;
wire       gw_dsp_int_fshark;
wire       gw_coin_counter_1;
wire       gw_coin_counter_2;
wire       gw_coin_lockout_1;
wire       gw_coin_lockout_2;
wire [7:0] gw_main_latch_q;
wire [7:0] gw_coin_latch_q;

gulfwar2_latches u_gulfwar2_latches
(
    .clk(clk_sys),
    .reset(reset),

    .main_wr(gw_mainlatch_write),
    .coin_wr(gw_coinlatch_write | gw_z80_coinlatch_write),
    .data(gw_z80_coinlatch_cs ? z80_dout : gw_latch_data),

    .irq4_enable(gw_irq4_enable),
    .flip_screen(gw_flip_screen),
    .bg_ram_bank(gw_bg_ram_bank),
    .fg_rom_bank(gw_fg_rom_bank),
    .dsp_int_gulfwar2(gw_dsp_int_gulfwar2),
    .display_on(gw_display_on),

    .dsp_int_fshark(gw_dsp_int_fshark),
    .coin_counter_1(gw_coin_counter_1),
    .coin_counter_2(gw_coin_counter_2),
    .coin_lockout_1(gw_coin_lockout_1),
    .coin_lockout_2(gw_coin_lockout_2),

    .main_q(gw_main_latch_q),
    .coin_q(gw_coin_latch_q)
);

assign prog_rom_cs       = gw_rom_cs;
assign ram_cs            = gw_mainram_cs;
assign sprite_ram_cs     = gw_spriteram_cs;
assign tile_palette_cs   = gw_palette_cs & cpu_a[11];
assign sprite_palette_cs = gw_palette_cs & ~cpu_a[11];
assign crtc_cs           = gw_crtc_addr_eff_cs | gw_crtc_data_eff_cs;
assign vblank_cs         = gw_vblank_cs;
assign shared_ram_cs     = gw_z80_shared_cs;
assign int_en_cs         = gw_mainlatch_eff_cs | gw_coinlatch_eff_cs;

assign tile_ofs_cs       = gw_tx_offset_cs | gw_bg_offset_cs | gw_fg_offset_cs;
assign tile_attr_cs      = gw_tx_vram_cs | gw_bg_vram_cs | gw_fg_vram_cs;
assign tile_num_cs       = 1'b0;
assign scroll_cs         = gw_tx_scroll_cs | gw_bg_scroll_cs | gw_fg_scroll_cs | gw_ex_scroll_cs;
assign scroll_ofs_x_cs   = 1'b0;
assign scroll_ofs_y_cs   = 1'b0;
assign frame_done_cs     = 1'b0;
assign sprite_ofs_cs     = 1'b0;
assign sprite_cs         = 1'b0;

wire   gw_dsp_ctrl_write   = gw_mainlatch_write && (gw_latch_data[3:1] == 3'd6);
wire   gw_dsp_activate_cmd = gw_dsp_ctrl_write &&  gw_latch_data[0];
wire   gw_dsp_inhibit_cmd  = gw_dsp_ctrl_write && !gw_latch_data[0];
assign dsp_ctrl_cs       = gw_dsp_ctrl_write;
wire   dsp_latch_start   = gw_dsp_activate_cmd;
assign dsp_addr_cs       = 1'b0;
assign dsp_r_cs          = 1'b0;
assign dsp_bio_cs        = 1'b0;
assign reset_z80_cs      = 1'b0;
assign bcu_flip_cs       = gw_mainlatch_eff_cs;
assign fcu_flip_cs       = gw_mainlatch_eff_cs;
assign scroll_y_offset   = 16'd0;

assign z80_p1_cs         = 1'b0;
assign z80_p2_cs         = 1'b0;
assign z80_dswa_cs       = gw_z80_dswa_cs;
assign z80_dswb_cs       = gw_z80_dswb_cs;
assign z80_system_cs     = gw_z80_system_cs;
assign z80_tjump_cs      = 1'b0;
assign z80_sound0_cs     = gw_ym3812_cs & ~gw_ym3812_addr;
assign z80_sound1_cs     = gw_ym3812_cs &  gw_ym3812_addr;

wire sprite_0_cs      = ( curr_sprite_ofs[1:0] == 2'b00 ) & sprite_cs;
wire sprite_1_cs      = ( curr_sprite_ofs[1:0] == 2'b01 ) & sprite_cs;
wire sprite_2_cs      = ( curr_sprite_ofs[1:0] == 2'b10 ) & sprite_cs;
wire sprite_3_cs      = ( curr_sprite_ofs[1:0] == 2'b11 ) & sprite_cs;

wire [11:0] gw_sprite_ram_offset = gw_cpu_decode_addr[11:0];
wire  [1:0] gw_sprite_direct_word = gw_sprite_ram_offset[2:1];
wire  [8:0] gw_sprite_direct_slot = gw_sprite_ram_offset[11:3];
wire        gw_sprite_direct_full_write = sprite_ram_cs & cpu_write_strobe & gw_upper_sel & gw_lower_sel;
wire        gw_sprite_direct_byte_write = sprite_ram_cs & cpu_write_strobe & (gw_upper_sel ^ gw_lower_sel);
wire        gw_sprite_direct_attr_w = sprite_ram_cs & cpu_write_strobe;

reg reset_z80_n;
wire sound_rom_1_cs   = gw_z80_rom_cs;
wire sound_ram_1_cs   = gw_z80_shared_ram_cs;

reg int_en;
reg int_ack;

reg [1:0] vbl_sr;

// vblank interrupt on rising vbl
always @ (posedge clk_sys ) begin
    if ( reset == 1 ) begin
        ipl2_n <= 1;
        int_ack <= 0;
        vbl_sr <= 2'b00;
    end else begin
        vbl_sr <= { vbl_sr[0], cpu_vblank };
        // vbl_sr <= { vbl_sr[0], ( vc == 224 ) };
        if ( fx68_phase_step == 1'b1 ) begin
            int_ack <= ( cpu_as_n == 0 ) && ( cpu_fc == 3'b111 ); // cpu acknowledged the interrupt
        end
        if ( vbl_sr == 2'b01 ) begin// rising edge
            ipl2_n <= ~int_en;
        end else if ( int_ack == 1 || vbl_sr == 2'b10 ) begin
            ipl2_n <= 1;
        end
    end
end

reg [15:0] scroll_x [3:0];
reg [15:0] scroll_y [3:0];

reg [15:0] scroll_x_latch [3:0];
reg [15:0] scroll_y_latch [3:0];

reg inc_sprite_ofs;

reg [15:0] crtc[4];
reg  [3:0] gw_crtc_index;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        int_en <= 0;
        reset_z80_n <= 1;
        tms_int_n <= 1;
        tms_bio <= 1'b1;
        tms_din <= 16'd0;
        cpu_halt_by_dsp <= 1'b0;
        dsp_active <= 1'b0;
        dsp_host_seg <= 3'd0;
        dsp_execute <= 1'b0;
        dsp_halt_released <= 1'b0;
        dsp_int_delay <= 3'd0;
        shared_dsp_ram_din <= 16'd0;
        shared_dsp_ram_addr <= 14'd0;
        shared_dsp_ram_w <= 1'b0;
        shared_dsp_sprite_w <= 1'b0;
        shared_dsp_palette_w <= 1'b0;
        inc_sprite_ofs <= 1'b0;
        gw_crtc_index <= 4'd0;
        crtc[0] <= 16'd0;
        crtc[1] <= 16'd0;
        crtc[2] <= 16'd0;
        crtc[3] <= 16'd0;
    end else begin
        // if the pcb uses the 68k reset pin to drive the reset line
        //reset_z80_n <= cpu_reset_n_o;

        if (clk_14M_N && (dsp_int_delay != 3'd0)) begin
            dsp_int_delay <= dsp_int_delay - 3'd1;
        end
        shared_dsp_ram_w <= 1'b0;
        shared_dsp_sprite_w <= 1'b0;
        shared_dsp_palette_w <= 1'b0;

        if (gw_tms_port_rd) begin
            case (tms_addr[2:0])
                3'h1: begin
                    tms_din <= gw_dsp_port1_din_mux;
                end
                default: tms_din <= 16'd0;
            endcase
        end

        if (gw_tms_port_wr) begin
            case (tms_addr[2:0])
                3'h0: begin
                    dsp_host_seg <= tms_dout[15:13];
                    shared_dsp_ram_addr <= {1'b0, tms_dout[12:0]};
                end

                3'h1: begin
                    shared_dsp_ram_din <= tms_dout;
                    dsp_execute <= gw_dsp_execute_set;
                    case (dsp_host_seg)
                        3'h3: begin
                            shared_dsp_ram_w <= 1'b1;
                        end
                        3'h4: shared_dsp_sprite_w <= 1'b1;
                        3'h5: shared_dsp_palette_w <= 1'b1;
                        default: begin
                        end
                    endcase
                end

                3'h3: begin
                    if (tms_dout[15]) begin
                        tms_bio <= 1'b1;
                    end else if (tms_dout == 16'd0) begin
                        tms_bio <= 1'b0;
                        if (dsp_execute) begin
                            cpu_halt_by_dsp <= 1'b0;
                            dsp_execute <= 1'b0;
                            dsp_halt_released <= 1'b1;
                        end
                    end
                end
            endcase
        end
        
        // Mirror the inherited DemonsWorld bus timing: the 68K write is
        // sampled on the local 10 MHz CPU enable.
        int_en <= gw_irq4_enable;
        tile_flip <= gw_flip_screen;
        // MAME flips only the tilemaps from the main latch. The game-side
        // object code handles sprite coordinates/attributes for flip screen.
        sprite_flip <= 1'b0;

        if ( gw_crtc_addr_eff_cs ) begin
            gw_crtc_index <= cpu_write_byte[3:0];
        end

        if ( gw_crtc_data_eff_cs ) begin
            if (!gw_crtc_index[3]) begin
                if (gw_crtc_index[0]) begin
                    crtc[gw_crtc_index[2:1]][15:8] <= cpu_write_byte;
                end else begin
                    crtc[gw_crtc_index[2:1]][7:0] <= cpu_write_byte;
                end
            end
        end

        // Match MAME's toaplan_dsp_device: DSP INT enable unhalts the DSP and
        // halts the 68K; disable halts the DSP but does not itself release the
        // 68K. The 68K is released by the port-3 zero/BIO handshake below.
        if (dsp_rom_loaded) begin
            if (gw_dsp_inhibit_cmd) begin
                tms_int_n <= 1'b1;
                dsp_active <= 1'b0;
                dsp_int_delay <= 3'd0;
            end else if (dsp_latch_start && !gw_dsp_release_now) begin
                dsp_active <= 1'b1;
                tms_int_n <= 1'b1;
                dsp_int_delay <= 3'd3;
                cpu_halt_by_dsp <= 1'b1;
                dsp_halt_released <= 1'b0;
            end else if (dsp_active) begin
                tms_int_n <= (dsp_int_delay != 3'd0);
            end else begin
                tms_int_n <= 1'b1;
                dsp_int_delay <= 3'd0;
            end
        end else begin
            tms_int_n <= 1'b1;
            dsp_active <= 1'b0;
            dsp_int_delay <= 3'd0;
            cpu_halt_by_dsp <= 1'b0;
            dsp_halt_released <= 1'b0;
        end

        if (gw_dsp_release_now || dsp_halt_released) begin
            cpu_halt_by_dsp <= 1'b0;
        end

        if ( cpu_write_strobe ) begin
            if ( tile_ofs_cs ) begin
                curr_tile_ofs <= cpu_dout;
            end
            
            if ( int_en_cs ) begin
                int_en <= gw_irq4_enable;
            end
            
            if ( bcu_flip_cs ) begin
                tile_flip <= gw_flip_screen;
            end
            
            if ( fcu_flip_cs ) begin
                sprite_flip <= 1'b0;
            end
            
            if ( sprite_ofs_cs ) begin
                // mask out valid range
                curr_sprite_ofs <= { 6'b0, cpu_dout[9:0] };
            end
            
            if ( scroll_ofs_x_cs ) begin
                scroll_ofs_x <= cpu_dout;
            end
            
            if ( scroll_ofs_y_cs ) begin
                scroll_ofs_y <= cpu_dout;
            end
            
            // x layer values are even addresses
            if ( scroll_cs ) begin
                if ( cpu_a[1] == 0 ) begin
                    scroll_x[ cpu_a[3:2] ] <= cpu_dout[15:7];
                end else begin
                    scroll_y[ cpu_a[3:2] ] <= cpu_dout[15:7];
                end
            end
            
            // SCU sprite RAM writes use the MAME 0x040000-0x040fff map.
            if ( sprite_cs ) begin
                inc_sprite_ofs <= 1;
            end
            
            if ( reset_z80_cs ) begin
                // The original core drives this as a latch. Keep the Z80 reset
                // line under 68K control so boot-time sound handshakes match.
                reset_z80_n <= cpu_dout[0];
            end
        end
        
        // write lasts multiple cpu clocks so limit to one increment per write signal
        if ( inc_sprite_ofs == 1 && cpu_rw == 1 ) begin
            curr_sprite_ofs <= curr_sprite_ofs + 1;
            inc_sprite_ofs <= 0;
        end
    end
end

reg [15:0] scroll_x_total [3:0];
reg [15:0] scroll_y_total [3:0];

wire [15:0] ram_dout;
wire [9:0]  tile_palette_addr;
wire [15:0] tile_palette_cpu_dout;
wire [15:0] tile_palette_dout;

wire [9:0]  sprite_palette_addr;
wire [15:0] sprite_palette_cpu_dout;
wire [15:0] sprite_palette_dout;

reg [15:0] curr_tile_ofs;
reg [15:0] curr_sprite_ofs;

reg [15:0] scroll_ofs_x;
reg [15:0] scroll_ofs_y;

wire [15:0] cpu_tile_dout_attr;
wire [15:0] cpu_tile_dout_num;
wire [15:0] gw_tile_cpu_dout;

assign cpu_tile_dout_attr = gw_tile_cpu_dout;
assign cpu_tile_dout_num  = 16'd0;

wire [15:0] sprite_0_dout;
wire [15:0] sprite_1_dout;
wire [15:0] sprite_2_dout;
wire [15:0] sprite_3_dout;

wire [15:0] sprite_attr_0_dout;
wire [15:0] sprite_attr_1_dout;
wire [15:0] sprite_attr_2_dout;
wire [15:0] sprite_attr_3_dout;

wire [15:0] sprite_attr_0_buf_dout;
wire [15:0] sprite_attr_1_buf_dout;
wire [15:0] sprite_attr_2_buf_dout;
wire [15:0] sprite_attr_3_buf_dout;
wire [15:0] sprite_rb_dout;

wire        sprite_direct_upper_only = gw_upper_sel && !gw_lower_sel;
wire        sprite_direct_lower_only = !gw_upper_sel && gw_lower_sel;
wire        shared_dsp_sprite_word0_w = shared_dsp_sprite_w && (shared_dsp_sprite_word == 2'd0);
wire        shared_dsp_sprite_word1_w = shared_dsp_sprite_w && (shared_dsp_sprite_word == 2'd1);
wire        shared_dsp_sprite_word2_w = shared_dsp_sprite_w && (shared_dsp_sprite_word == 2'd2);
wire        shared_dsp_sprite_word3_w = shared_dsp_sprite_w && (shared_dsp_sprite_word == 2'd3);
wire [15:0] sprite_direct_din =
    sprite_direct_upper_only ? { cpu_dout[15:8], sprite_rb_dout[7:0] } :
    sprite_direct_lower_only ? { sprite_rb_dout[15:8], cpu_dout[7:0] } :
                               cpu_dout;
wire [15:0] sprite_0_din =
    gw_sprite_direct_attr_w ? sprite_direct_din : cpu_dout;
wire [15:0] sprite_1_din =
    gw_sprite_direct_attr_w ? sprite_direct_din : cpu_dout;
wire [15:0] sprite_2_din =
    gw_sprite_direct_attr_w ? sprite_direct_din : cpu_dout;
wire [15:0] sprite_3_din =
    gw_sprite_direct_attr_w ? sprite_direct_din : cpu_dout;

reg [15:0] sprite_buf_din;

reg [14:0] tile;

reg [8:0] sprite_num;
reg [8:0] sprite_num_copy;

reg [3:0] tile_draw_state;

reg [2:0] layer;    // 4 layers + 1 for initial background

wire [14:0] tile_idx_raw     = tile_attr[14:0];
wire [14:0] tile_idx         = {1'b0, tile_idx_raw[13:0]};
wire  [3:0] tile_priority    = tile_attr[31:28];
wire  [5:0] tile_palette_idx = tile_attr[21:16];
wire        tile_text_layer = layer == 3'd0;
wire  [9:0] tile_palette_addr_4bpp = { tile_palette_idx, tile_pix };
wire  [9:0] tile_palette_addr_text = { 2'b10, tile_palette_idx[4:0], tile_pix[2:0] };
wire  [9:0] tile_palette_word_addr = tile_text_layer ? tile_palette_addr_text : tile_palette_addr_4bpp;
wire        tile_hidden      = tile_attr[15];
wire        tile_priority_active = tile_priority != 4'd0;
wire        tile_priority_wins = tile_priority_active && ((tile_priority & ~tile_priority_buf[x]) != 4'd0);
wire  [3:0] tile_priority_merged = tile_priority_buf[x] | tile_priority;
wire        tile_draw_normal =
    (tile_hidden == 1'b0) && (tile_pix > 4'd0) && tile_priority_wins;
wire        tile_draw_selected = tile_draw_normal;

reg  [15:0] fb_dout;
wire [15:0] tile_fb_out;
wire [15:0] sprite_fb_out;
reg  [15:0] fb_din;
reg  [15:0] sprite_fb_din;

reg tile_fb_w;
reg sprite_fb_w;
reg sprite_buf_w;

dual_port_ram #(.LEN(1024), .DATA_WIDTH(16)) tile_line_buffer (
    .clock_a ( clk_sys ),
    .address_a ( tile_fb_addr_w ),
    .wren_a ( tile_fb_w ),
    .data_a ( fb_din ),
    .q_a ( ),

    .clock_b ( clk_sys ),
    .address_b ( fb_addr_r ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( tile_fb_out )
    );
    
dual_port_ram #(.LEN(1024), .DATA_WIDTH(16)) sprite_line_buffer (
    .clock_a ( clk_sys ),
    .address_a ( sprite_fb_addr_w ),
    .wren_a ( sprite_fb_w ),
    .data_a ( sprite_fb_din ),
    .q_a ( ),

    .clock_b ( clk_sys ),
    .address_b ( fb_addr_r ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_fb_out )
    );

reg [9:0] x_ofs;
reg [9:0] x;

reg [9:0] y_ofs;

// y needs to be one line ahaed of the visible line
// render the first line at the end of the previous frame
// this depends on the timing that the sprite list is valid
// sprites values are copied at the start of vblank (line 240)

// MAME's tilemap core positions maps at dx-scroll/dy-scroll, so sampling
wire [9:0] x_ofs_dx         = 10'd55;
wire [9:0] y_ofs_dx         = 10'd30;
wire [9:0] x_ofs_dx_flipped = 10'd134;
wire [9:0] y_ofs_dx_flipped = 10'd243;

// calculate scrolling
wire [9:0] tile_x_unflipped = scroll_x_latch[layer[1:0]] + x_ofs_dx;
wire [9:0] tile_y_unflipped = scroll_y_latch[layer[1:0]] + y_ofs_dx + scroll_y_offset;
wire [9:0] tile_x_flipped   = 319 + scroll_x_latch[layer[1:0]] + x_ofs_dx_flipped; 
wire [9:0] tile_y_flipped   = 239 + scroll_y_latch[layer[1:0]] + y_ofs_dx_flipped + scroll_y_offset;

// reverse tiles when flipped
wire [9:0] curr_x = tile_flip ? tile_x_flipped - x :  tile_x_unflipped + x;
wire [9:0] curr_y = tile_flip ? tile_y_flipped - y :  tile_y_unflipped + y;

reg  [9:0] y;
wire [9:0] y_flipped = ( sprite_flip ? (240 - y ) + scroll_y_offset : y + scroll_y_offset);

reg [3:0] draw_state;
reg [3:0] sprite_state;
reg [3:0] sprite_copy_state;
reg       sprite_copy_vblank_last;

// pixel 4 bit colour
wire [3:0] tile_pix;
wire [2:0] tile_bit = curr_x[2:0];
wire [3:0] tile_pix_4bpp = {
    tile_data[31-tile_bit],
    tile_data[23-tile_bit],
    tile_data[15-tile_bit],
    tile_data[7-tile_bit]
};
wire [3:0] tile_pix_text_3bpp = {
    1'b0,
    tile_data[23-tile_bit],
    tile_data[15-tile_bit],
    tile_data[7-tile_bit]
};
assign tile_pix = (layer == 3'd0) ? tile_pix_text_3bpp : tile_pix_4bpp;

// MAME's Toaplan SCU consumes sprite RAM as native 16-bit words.
wire [15:0] sprite_scu_attr_0 = sprite_eval_attr_0;
wire [15:0] sprite_scu_attr_1 = sprite_eval_attr_1;
wire [15:0] sprite_scu_attr_2 = sprite_eval_attr_2;
wire [15:0] sprite_scu_attr_3 = sprite_eval_attr_3;

wire       sprite_attr_flipx = sprite_scu_attr_1[8];
wire       sprite_attr_flipy = sprite_scu_attr_1[9];
wire [3:0] sprite_x_rom = sprite_attr_flipx ? (4'd15 - sprite_x[3:0]) : sprite_x[3:0];
wire [3:0] sprite_y_rom = sprite_attr_flipy ? (4'd15 - sprite_y_rel[3:0]) : sprite_y_rel[3:0];
wire [2:0] sprite_bit = sprite_x_rom[2:0];
wire [3:0] sprite_pix;
assign sprite_pix = {
    sprite_data[31-sprite_bit],
    sprite_data[23-sprite_bit],
    sprite_data[15-sprite_bit],
    sprite_data[7-sprite_bit]
};

// two lines of buffer alternate
reg  [9:0] tile_fb_addr_w;
wire [9:0] fb_addr_r = {video_vc[0], 9'b0 } + video_hc;

reg [9:0] sprite_fb_addr_w;

reg [31:0] tile_attr;

wire [10:0] gw_tx_scan_addr = { curr_y[7:3], curr_x[8:3] };
wire [11:0] gw_fg_scan_addr = { curr_y[8:3], curr_x[8:3] };
wire [11:0] gw_bg_scan_addr = { curr_y[8:3], curr_x[8:3] };
wire [15:0] gw_tx_scan_data;
wire [15:0] gw_fg_scan_data;
wire [15:0] gw_bg_scan_data;
wire [15:0] gw_tx_scroll_x;
wire [15:0] gw_tx_scroll_y;
wire [15:0] gw_fg_scroll_x;
wire [15:0] gw_fg_scroll_y;
wire [15:0] gw_bg_scroll_x;
wire [15:0] gw_bg_scroll_y;

wire [15:0] gw_layer_tile_word =
    (layer == 3'd0) ? gw_tx_scan_data :
    (layer == 3'd1) ? gw_fg_scan_data :
                      gw_bg_scan_data;
wire [14:0] gw_tx_tile_index = { 4'd0, gw_layer_tile_word[10:0] };
wire [14:0] gw_fg_tile_index = 15'h0c00 + { 1'b0, gw_fg_rom_bank, gw_layer_tile_word[11:0] };
wire [14:0] gw_bg_tile_index = 15'h2c00 + { 3'd0, gw_layer_tile_word[11:0] };
wire [14:0] gw_layer_tile_index =
    (layer == 3'd0) ? gw_tx_tile_index :
    (layer == 3'd1) ? gw_fg_tile_index :
                      gw_bg_tile_index;
wire [5:0] gw_tx_tile_color = { 1'b0, gw_layer_tile_word[15:11] };
wire [5:0] gw_gfx_tile_color = { 2'b00, gw_layer_tile_word[15:12] };
wire [5:0] gw_layer_tile_color =
    (layer == 3'd0) ? gw_tx_tile_color : gw_gfx_tile_color;
wire [5:0] gw_layer_palette_idx =
    ((layer == 3'd0) ? 6'h20 :
     (layer == 3'd1) ? 6'h10 :
                       6'h00) + gw_layer_tile_color;
localparam [3:0] GW_PRIORITY_BG = 4'b0001;
localparam [3:0] GW_PRIORITY_FG = 4'b0010;
localparam [3:0] GW_PRIORITY_TX = 4'b0100;
wire [3:0] gw_layer_priority =
    (layer == 3'd0) ? GW_PRIORITY_TX :
    (layer == 3'd1) ? GW_PRIORITY_FG :
                      GW_PRIORITY_BG;
wire [31:0] gw_layer_tile_attr = {
    gw_layer_priority,
    6'd0,
    gw_layer_palette_idx,
    1'b0,
    gw_layer_tile_index
};

// two lines worth for 4 layers (~8k)
// [15:14] = layer.
// [13:10] = priority
// [9:0] = resolved palette word address. Text tiles are 3bpp, so their
// palette groups are 8 entries wide; BG/FG tiles and sprites are 4bpp.

reg [3:0] tile_priority_buf   [327:0];
reg [4:0] sprite_priority_buf [327:0];

reg  [9:0] sprite_x;         // offset from left side of sprite
reg  [9:0] sprite_y;

wire [10:0] sprite_rom_index = sprite_scu_attr_0[10:0];
wire  [8:0] sprite_pos_x_raw = sprite_scu_attr_2[15:7];
wire  [8:0] sprite_pos_y_raw = sprite_scu_attr_3[15:7];
wire        sprite_hidden   = (sprite_pos_y_raw == 9'h100);

wire [5:0] sprite_pal_addr  = sprite_scu_attr_1[5:0];
wire [3:0] sprite_priority_raw = { 2'b00, sprite_scu_attr_1[11:10] };

wire [9:0] sprite_pos_x  = sprite_adj_x + ({ 1'b0, sprite_pos_x_raw } - 10'd31 - (sprite_attr_flipx ? 10'd15 : 10'd0));
wire [9:0] sprite_pos_y  = sprite_adj_y + ({ 1'b0, sprite_pos_y_raw } - 10'd16);
wire signed [10:0] sprite_pos_x_s = { sprite_pos_x[9], sprite_pos_x };
wire signed [10:0] sprite_x_s = { 1'b0, sprite_x };
wire signed [10:0] sprite_buf_x_s =
    sprite_flip ? (11'sd320 - (sprite_x_s + sprite_pos_x_s)) :
                  (sprite_x_s + sprite_pos_x_s);
wire        sprite_buf_x_visible = (sprite_buf_x_s >= 11'sd0) && (sprite_buf_x_s < 11'sd320);
wire [8:0]  sprite_buf_x_addr = sprite_buf_x_s[8:0];
wire [9:0]  sprite_fb_line_addr = { y[0], 9'b0 } + { 1'b0, sprite_buf_x_addr };

wire [8:0] sprite_height = 9'd16;
wire [8:0] sprite_width  = 9'd16;
wire signed [10:0] sprite_y_scan_s  = { y_flipped[9], y_flipped };
wire signed [10:0] sprite_pos_y_s   = { sprite_pos_y[9], sprite_pos_y };
wire signed [10:0] sprite_height_s  = { 2'b00, sprite_height };
wire signed [10:0] sprite_width_s   = { 2'b00, sprite_width };
wire signed [10:0] sprite_pos_x_end_s = sprite_pos_x_s + sprite_width_s;
wire        sprite_visible_y_ge = sprite_y_scan_s >= sprite_pos_y_s;
wire        sprite_visible_y_lt = sprite_y_scan_s < (sprite_pos_y_s + sprite_height_s);
wire        sprite_visible_x_unflipped = (sprite_pos_x_end_s > 11'sd0) && (sprite_pos_x_s < 11'sd320);
wire        sprite_visible_x_flipped   = (sprite_pos_x_end_s > 11'sd1) && (sprite_pos_x_s < 11'sd321);
wire        sprite_visible_x = sprite_flip ? sprite_visible_x_flipped : sprite_visible_x_unflipped;
wire [9:0]  sprite_y_rel = y_flipped - sprite_pos_y;
wire [17:0] sprite_current_rom_addr = { 2'b00, sprite_rom_index, sprite_y_rom, sprite_x_rom[3] };
wire        sprite_overlap_wins = !sprite_priority_buf[sprite_buf_x_addr][4];
wire       sprite_visible_candidate =
    !sprite_hidden &&
    (sprite_priority_raw != 4'd0) &&
    (sprite_width > 9'd0) &&
    sprite_visible_x &&
    sprite_visible_y_ge &&
    sprite_visible_y_lt;

reg [8:0] sprite_buf_num;
wire [8:0] sprite_source_read_num = sprite_num_copy;
reg [15:0] sprite_eval_attr_0;
reg [15:0] sprite_eval_attr_1;
reg [15:0] sprite_eval_attr_2;
reg [15:0] sprite_eval_attr_3;
reg       sprite_candidate_pending;
reg [17:0] sprite_candidate_rom_addr;
reg  [9:0] sprite_candidate_y_rel;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        sprite_state <= 0;
        draw_state <= 0;
        sprite_rom_cs <= 0;
        tile_rom_cs <= 0;
        sprite_copy_state <= 0;
        sprite_copy_vblank_last <= 1'b0;
        sprite_eval_attr_0 <= 16'd0;
        sprite_eval_attr_1 <= 16'd0;
        sprite_eval_attr_2 <= 16'd0;
        sprite_eval_attr_3 <= 16'd0;
        sprite_candidate_pending <= 1'b0;
        sprite_candidate_rom_addr <= 18'd0;
        sprite_candidate_y_rel <= 10'd0;
        tile_draw_state <= 0;
        tile_fb_w <= 1'b0;
        sprite_fb_w <= 1'b0;
        sprite_buf_w <= 1'b0;
        tile_fb_addr_w <= 10'd0;
        sprite_fb_addr_w <= 10'd0;
        fb_din <= 16'd0;
        sprite_fb_din <= 16'd0;
        sprite_num <= 9'd0;
        sprite_num_copy <= 9'd0;
        sprite_buf_num <= 9'd0;
        sprite_x <= 10'd0;
        sprite_y <= 10'd0;
        x <= 10'd0;
        y <= 10'd0;
        layer <= 3'd0;
    end else begin
        sprite_copy_vblank_last <= cpu_vblank;

        // render sprites 
        // triggered when the tile rendering starts
        if ( sprite_state == 0 && draw_state > 0 ) begin
            sprite_num <= 9'h1ff;
            sprite_x <= 0;
            sprite_fb_w <= 1;
            sprite_state <= 1;
            sprite_fb_din <= 0;
            sprite_fb_addr_w <= { y[0], 9'b0 };
        end else if ( sprite_state == 1 ) begin
            // erase line buffer
            sprite_fb_addr_w <= { y[0], 9'b0 } + sprite_x;
            sprite_priority_buf[sprite_x] <= 0;
            if ( sprite_x < 320 ) begin
                sprite_x <= sprite_x + 1;
            end else begin
                sprite_x <= 0;
                sprite_fb_w <= 0;
                sprite_state <= 2;
            end
        end else if ( sprite_state == 2 ) begin
            // sprite num is valid now
            sprite_candidate_pending <= 1'b0;
            sprite_state <= 3;
        end else if ( sprite_state == 3 ) begin
            // The RAM address registered on the previous cycle; latch the
            // selected sprite attributes here so the scanner has more line
            // time for dense gameplay scenes.
            sprite_rom_cs <= 0;
            sprite_fb_w <= 0;
            sprite_eval_attr_0 <= sprite_attr_0_buf_dout;
            sprite_eval_attr_1 <= sprite_attr_1_buf_dout;
            sprite_eval_attr_2 <= sprite_attr_2_buf_dout;
            sprite_eval_attr_3 <= sprite_attr_3_buf_dout;
            sprite_state <= 5;
        end else if ( sprite_state == 5 ) begin
            sprite_rom_cs <= 0;
            sprite_fb_w <= 0;
            sprite_y <= sprite_y_rel;
            // is sprite visible and is current y in sprite y range
            // sprite pos can be negative?
            if ( sprite_visible_candidate ) begin
                sprite_candidate_pending <= 1'b1;
                sprite_candidate_rom_addr <= sprite_current_rom_addr;
                sprite_candidate_y_rel <= sprite_y_rel;
                sprite_rom_addr <= sprite_current_rom_addr;
                sprite_y <= sprite_y_rel;
                sprite_rom_cs <= 1;
                sprite_state <= 6;
            end else if ( sprite_num != 9'd0 ) begin
                sprite_num <= sprite_num - 9'd1;
                sprite_state <= 2;
            end else begin
                sprite_state <= 15;
            end
        end else if ( sprite_state == 6 ) begin
            // wait for sprite bitmap ready
            if ( sprite_rom_data_valid ) begin
                // latch data and deassert cs
                sprite_data <= sprite_rom_data;
                sprite_rom_cs <= 0;
                sprite_state <= 7;
            end
        end else if ( sprite_state == 7 ) begin
            sprite_fb_w <= 0;
            if ( sprite_pix != 0 && sprite_buf_x_visible && sprite_overlap_wins ) begin
                sprite_fb_din <= { 2'b11, sprite_priority_raw[3:0], sprite_pal_addr, sprite_pix };
                sprite_fb_addr_w <= sprite_fb_line_addr;
                sprite_priority_buf[sprite_buf_x_addr] <= { 1'b1, sprite_priority_raw };
                sprite_fb_w <= 1;
            end
            if ( sprite_x < ( sprite_width - 1 ) ) begin
                sprite_x <= sprite_x + 1;
                if ( sprite_x[2:0] == 7 ) begin
                    // do recalc bitmap address
                    sprite_state <= 5;
                end
            end else if ( sprite_num != 9'd0 ) begin
                sprite_num <= sprite_num - 9'd1;
                sprite_x <= 0;
                // need to load new attributes
                sprite_state <= 2;
            end else begin
                // tile state machine will reset sprite_state when line completes.
                sprite_state <= 15; // done
            end
        end else if ( sprite_state == 15 ) begin
            sprite_fb_w <= 0;
            sprite_rom_cs <= 0;
        end
        // copy sprite attributes to buffer
        if ( sprite_copy_state == 0 && cpu_vblank && !sprite_copy_vblank_last ) begin
            sprite_copy_state <= 1;
            sprite_buf_w <= 0;
            sprite_num_copy <= 9'd0;
        end else if ( sprite_copy_state == 1 ) begin
            sprite_num_copy <= sprite_num_copy + 1;
            sprite_buf_num <= sprite_num_copy;
            sprite_buf_w <= 1;
            // wait for read from source
            if ( sprite_num_copy == 9'h1ff ) begin
                sprite_copy_state <= 2;
            end
        end else if ( sprite_copy_state == 2 ) begin
            sprite_buf_w <= 0;
            sprite_copy_state <= 0;
        end
        // tile state machine
        if ( draw_state == 0 && video_vc == gw_top_prerender_v ) begin
            scroll_x_latch[0] <= gw_tx_scroll_x - scroll_ofs_x;
            scroll_x_latch[1] <= gw_fg_scroll_x - scroll_ofs_x;
            scroll_x_latch[2] <= gw_bg_scroll_x - scroll_ofs_x;
            scroll_x_latch[3] <= 16'd0;
            scroll_y_latch[0] <= gw_tx_scroll_y - scroll_ofs_y;
            scroll_y_latch[1] <= gw_fg_scroll_y - scroll_ofs_y;
            scroll_y_latch[2] <= gw_bg_scroll_y - scroll_ofs_y;
            scroll_y_latch[3] <= 16'd0;
            layer <= 3'd2;
            y <= 0;
            draw_state <= 2;
            sprite_state <= 0;
        end else if ( draw_state == 2 ) begin
            x <= 0;
            x_ofs <= scroll_x_latch[layer[1:0]];
            y_ofs <= scroll_y_latch[layer[1:0]];
            // latch offset info
            draw_state <= 3;
            tile_draw_state <= 0;
        end else if ( draw_state == 3 ) begin
            if ( tile_draw_state == 0 ) begin
                tile <=  { layer[1:0], curr_y[8:3], curr_x[8:3] };  // works
                tile_draw_state <= 4'h1;
            end else if ( tile_draw_state == 1 ) begin
                tile_draw_state <= 2;
            end else if ( tile_draw_state == 2 ) begin
                tile_attr <= gw_layer_tile_attr;
                tile_buf_dout <= gw_layer_tile_attr;
                tile_draw_state <= 3;
            end else if ( tile_draw_state == 3 ) begin
                // read bitmap info
                tile_rom_cs <= 1;
                tile_rom_addr <= { tile_idx, curr_y[2:0] };
                tile_draw_state <= 4;
            end else if ( tile_draw_state == 4 ) begin
                // wait for bitmap ram ready
                if ( tile_rom_data_valid ) begin
                    // latch data and deassert cs
                    tile_data <= tile_rom_data;
                    tile_draw_state <= 5;
                    tile_rom_cs <= 0;
                end
            end else if ( tile_draw_state == 5 ) begin
                tile_fb_w <= 0; 
                tile_fb_addr_w   <= { y[0], 9'b0 } + x;
                // Force-render the background layer first so the line buffer is
                // initialized before foreground/text transparency is applied.
                if ( layer == 3'd2 ) begin
                    tile_priority_buf[x] <= tile_priority;
                    fb_din <= { layer[1:0], tile_priority, tile_palette_word_addr };
                    tile_fb_w <= 1;
                //end else if (tile_hidden == 0 && tile_pix > 0 && tile_priority > 0 && tile_priority >= tile_priority_buf[x] ) begin
                end else if (tile_draw_selected) begin
                    tile_priority_buf[x] <= tile_priority_merged;
                    // if tile hidden then make the pallette index 0. ie transparent
                    fb_din <= { layer[1:0], tile_priority_merged, tile_palette_word_addr };
                    tile_fb_w <= 1;
                end
                if ( x < 320 ) begin
                    // do we need to read another tile?
                    // last pixel of this tile changes based on flip direction
                    if ( curr_x[2:0] == ( tile_flip ? 0 : 7)  ) begin
                        draw_state <= 3; 
                        tile_draw_state <= 0;
                    end 
                    x <= x + 1;
                end else if ( layer > 0 ) begin
                    layer <= layer - 1;
                    tile_fb_w <= 0;
                    draw_state <= 2;
                end else begin
                    // done
                    tile_draw_state <= 7;
                    tile_fb_w <= 0;
                end
            end else if ( tile_draw_state == 7 ) begin
                // wait for next line or quit
                if ( y == 239 ) begin
                    draw_state <= 0;
                end else if ( y == 0 && video_vc != 9'd0 ) begin
                    // Line 0 is pre-rendered from vblank start so it is ready
                    // before the visible frame starts. Hold it until scanline 0,
                    // then resume the usual one-line-ahead cadence.
                    draw_state <= 3;
                    tile_draw_state <= 7;
                end else if ( y == 0 ) begin
                    y <= 10'd1;
                    draw_state <= 2;
                    sprite_state <= 0;
                    layer <= 3'd2;
                end else if ( video_hc == gw_raster_h_last ) begin
                    y <= y + 1;
                    draw_state <= 2;
                    sprite_state <= 0;
                    layer <= 3'd2;
                end
            end
        end
    end
end

// render
reg draw_sprite;

// two lines worth for 4 layers (~8k)
// [15:14] = layer.
// [13:10] = priority
// [9:0] = resolved palette word address.

// there are 10 70MHz cycles per pixel. clk7_count from 0-9
// 

function automatic [7:0] pal5_to_8(input [4:0] v);
    pal5_to_8 = { v, v[4:2] };
endfunction

function automatic [3:0] scu_tile_mask(input [3:0] spr_prio);
    case (spr_prio[1:0])
        2'd0: scu_tile_mask = GW_PRIORITY_BG | GW_PRIORITY_FG | GW_PRIORITY_TX;
        2'd1: scu_tile_mask = GW_PRIORITY_FG | GW_PRIORITY_TX;
        2'd2: scu_tile_mask = GW_PRIORITY_TX;
        default: scu_tile_mask = 4'd0;
    endcase
endfunction

wire [3:0] sprite_priority_mame_mask = scu_tile_mask(sprite_fb_out[13:10]);
wire sprite_compositor_draw =
    (sprite_fb_out[3:0] > 4'd0) &&
    ((sprite_priority_mame_mask & tile_fb_out[13:10]) == 4'd0);

wire [23:0] tile_rgb_normal = {
    pal5_to_8(tile_palette_dout[4:0]),
    pal5_to_8(tile_palette_dout[9:5]),
    pal5_to_8(tile_palette_dout[14:10])
};
wire [23:0] sprite_rgb_normal = {
    pal5_to_8(sprite_palette_dout[4:0]),
    pal5_to_8(sprite_palette_dout[9:5]),
    pal5_to_8(sprite_palette_dout[14:10])
};

always @ (posedge clk_sys) begin
    if ( clk7_count == 4 ) begin
        tile_palette_addr  <= tile_fb_out[9:0];
        sprite_palette_addr <= sprite_fb_out[9:0];
    end else if ( clk7_count == 6 ) begin
        rgb <= tile_rgb_normal;
        if ( sprite_compositor_draw ) begin
            rgb <= sprite_rgb_normal;
        end
    end
end

reg         download_en;
reg [15:0]  download_index;
reg [11:0]  download_addr;
reg [7:0]   download_data;
reg         download_wr;

localparam [26:0] GULFWAR2_DSP_ROM_BASE = 27'h0048000;
localparam [26:0] GULFWAR2_DSP_ROM_END  = 27'h004a000;
localparam [26:0] DEMON_DSP_ROM_BASE    = 27'h0208000;
localparam [26:0] DEMON_DSP_ROM_END     = 27'h020a000;

wire gulfwar2_dsp_download_new =
    (ioctl_addr >= GULFWAR2_DSP_ROM_BASE) && (ioctl_addr < GULFWAR2_DSP_ROM_END);
wire gulfwar2_dsp_download_legacy =
    (ioctl_addr >= DEMON_DSP_ROM_BASE) && (ioctl_addr < DEMON_DSP_ROM_END);
wire gulfwar2_dsp_download_cs = gulfwar2_dsp_download_new | gulfwar2_dsp_download_legacy;
wire [26:0] gulfwar2_dsp_download_rel =
    gulfwar2_dsp_download_new ? (ioctl_addr - GULFWAR2_DSP_ROM_BASE) :
                            (ioctl_addr - DEMON_DSP_ROM_BASE);

// download tms32010 internal rom
always @ (posedge clk_sys) begin
    if (RESET) begin
        dsp_rom_loaded <= 1'b0;
    end else if (ioctl_wr && gulfwar2_dsp_download_cs) begin
        dsp_rom_loaded <= 1'b1;
    end

    tms_rom_w     <= 1'b0;
    download_en    <= ioctl_download & (download_index == 0) ; 
    download_index <= ioctl_index ;

    if ( gulfwar2_dsp_download_cs ) begin
        // dsp rom is 16 bits wide
        download_addr <= gulfwar2_dsp_download_rel[12:1] ;
        tms_rom_w     <= ioctl_wr & gulfwar2_dsp_download_rel[0];
        tms_rom_din[ { ~gulfwar2_dsp_download_rel[0], 3'b111 } -: 8 ] <= ioctl_dout ;
    end
end

reg         tms_rom_w;
wire [11:0] tms_rom_addr ;
reg  [15:0] tms_rom_din ;
wire [15:0] tms_rom_dout ;

dual_port_ram #(.LEN(4096), .DATA_WIDTH(16)) dsp_rom
(
    .clock_a( clk_sys ), // rom download. ioctl stuff. 
    .address_a( download_addr ),
    .wren_a( tms_rom_w ), // 
    .data_a( tms_rom_din ), // 16 bit wide
    .q_a( ),

    .clock_b( clk_sys ),
    .address_b( tms_rom_addr ),
    .data_b( 16'd0 ),
    .wren_b( 1'b0 ),
    .q_b( tms_rom_dout )
);

reg  [31:0] tile_buf_dout;
gulfwar2_tile_ram u_gulfwar2_tile_ram
(
    .clk(clk_sys),
    .reset(reset),

    .cpu_addr(gw_cpu_decode_addr),
    .cpu_read(gw_bus_read),
    .cpu_write(cpu_write_strobe),
    .upper_sel(gw_upper_sel),
    .lower_sel(gw_lower_sel),
    .cpu_dout(cpu_dout),
    .cpu_din(gw_tile_cpu_dout),

    .tx_scroll_cs(gw_tx_scroll_cs),
    .tx_offset_cs(gw_tx_offset_cs),
    .bg_scroll_cs(gw_bg_scroll_cs),
    .bg_offset_cs(gw_bg_offset_cs),
    .fg_scroll_cs(gw_fg_scroll_cs),
    .fg_offset_cs(gw_fg_offset_cs),
    .tx_vram_cs(gw_tx_vram_cs),
    .bg_vram_cs(gw_bg_vram_cs),
    .fg_vram_cs(gw_fg_vram_cs),
    .bg_ram_bank(gw_bg_ram_bank),

    .tx_scroll_x(gw_tx_scroll_x),
    .tx_scroll_y(gw_tx_scroll_y),
    .bg_scroll_x(gw_bg_scroll_x),
    .bg_scroll_y(gw_bg_scroll_y),
    .fg_scroll_x(gw_fg_scroll_x),
    .fg_scroll_y(gw_fg_scroll_y),

    .tx_scan_addr(gw_tx_scan_addr),
    .tx_scan_data(gw_tx_scan_data),
    .fg_scan_addr(gw_fg_scan_addr),
    .fg_scan_data(gw_fg_scan_data),
    .bg_scan_addr(gw_bg_scan_addr),
    .bg_scan_data(gw_bg_scan_data)
);

// sprite attribute ram.  each tile attribute is 4 16bit words
// indirect access through offset register
// split up so 64 bits can be read in a single clock
dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_0 (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_sprite_access ? shared_dsp_sprite_slot :
        gw_sprite_direct_attr_w ? gw_sprite_direct_slot : curr_sprite_ofs[10:2] ),
    .wren_a ( (cpu_write_strobe & sprite_0_cs) |
        (gw_sprite_direct_attr_w && (gw_sprite_direct_word == 2'd0)) |
        shared_dsp_sprite_word0_w ),
    .data_a ( shared_dsp_sprite_word0_w ? shared_dsp_ram_din : sprite_0_din ),
    .q_a ( sprite_0_dout ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_source_read_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_0_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_0_buf (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buf_num ),
    .wren_a ( sprite_buf_w ),
    .data_a ( sprite_attr_0_dout[15:0] ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_0_buf_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_1 (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_sprite_access ? shared_dsp_sprite_slot :
        gw_sprite_direct_attr_w ? gw_sprite_direct_slot : curr_sprite_ofs[10:2] ),
    .wren_a ( (cpu_write_strobe & sprite_1_cs) |
        (gw_sprite_direct_attr_w && (gw_sprite_direct_word == 2'd1)) |
        shared_dsp_sprite_word1_w ),
    .data_a ( shared_dsp_sprite_word1_w ? shared_dsp_ram_din : sprite_1_din ),
    .q_a ( sprite_1_dout ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_source_read_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_1_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_1_buf (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buf_num ),
    .wren_a ( sprite_buf_w ),
    .data_a ( sprite_attr_1_dout[15:0] ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_1_buf_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_2 (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_sprite_access ? shared_dsp_sprite_slot :
        gw_sprite_direct_attr_w ? gw_sprite_direct_slot : curr_sprite_ofs[10:2] ),
    .wren_a ( (cpu_write_strobe & sprite_2_cs) |
        (gw_sprite_direct_attr_w && (gw_sprite_direct_word == 2'd2)) |
        shared_dsp_sprite_word2_w ),
    .data_a ( shared_dsp_sprite_word2_w ? shared_dsp_ram_din : sprite_2_din ),
    .q_a ( sprite_2_dout ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_source_read_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_2_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_2_buf (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buf_num ),
    .wren_a ( sprite_buf_w ),
    .data_a ( sprite_attr_2_dout[15:0] ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_2_buf_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_3 (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_sprite_access ? shared_dsp_sprite_slot :
        gw_sprite_direct_attr_w ? gw_sprite_direct_slot : curr_sprite_ofs[10:2] ),
    .wren_a ( (cpu_write_strobe & sprite_3_cs) |
        (gw_sprite_direct_attr_w && (gw_sprite_direct_word == 2'd3)) |
        shared_dsp_sprite_word3_w ),
    .data_a ( shared_dsp_sprite_word3_w ? shared_dsp_ram_din : sprite_3_din ),
    .q_a ( sprite_3_dout ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_source_read_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_3_dout[15:0] )
    );

dual_port_ram #(.LEN(512), .DATA_WIDTH(16)) sprite_ram_3_buf (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buf_num ),
    .wren_a ( sprite_buf_w ),
    .data_a ( sprite_attr_3_dout[15:0] ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_num ),
    .data_b ( 16'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_attr_3_buf_dout[15:0] )
    );


// tiles  1024 15 bit values.  index is ( 6 bits from tile attribute, 4 bits from bitmap )
// background palette ram low
// does this need to be byte addressable?
dual_port_ram #(.LEN(1024), .DATA_WIDTH(8)) tile_palram_l (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_palette_access ? shared_dsp_palette_addr : cpu_a[10:1] ),
    .wren_a ( (cpu_write_strobe & tile_palette_cs & !cpu_lds_n) |
        (shared_dsp_palette_w & shared_dsp_palette_tile) ),
    .data_a ( shared_dsp_palette_w ? shared_dsp_ram_din[7:0] : cpu_dout[7:0] ),
    .q_a ( tile_palette_cpu_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( tile_palette_addr ),
    .data_b ( 8'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( tile_palette_dout[7:0] )
    );

// background palette ram high
dual_port_ram #(.LEN(1024), .DATA_WIDTH(8)) tile_palram_h (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_palette_access ? shared_dsp_palette_addr : cpu_a[10:1] ),
    .wren_a ( (cpu_write_strobe & tile_palette_cs & !cpu_uds_n) |
        (shared_dsp_palette_w & shared_dsp_palette_tile) ),
    .data_a ( shared_dsp_palette_w ? shared_dsp_ram_din[15:8] : cpu_dout[15:8] ),
    .q_a ( tile_palette_cpu_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( tile_palette_addr ),
    .data_b ( 8'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( tile_palette_dout[15:8] )
    );

// sprite palette ram low
// does this need to be byte addressable?
dual_port_ram #(.LEN(1024), .DATA_WIDTH(8)) sprite_palram_l (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_palette_access ? shared_dsp_palette_addr : cpu_a[10:1] ),
    .wren_a ( (cpu_write_strobe & sprite_palette_cs & !cpu_lds_n) |
        (shared_dsp_palette_w & !shared_dsp_palette_tile) ),
    .data_a ( shared_dsp_palette_w ? shared_dsp_ram_din[7:0] : cpu_dout[7:0] ),
    .q_a ( sprite_palette_cpu_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_palette_addr ),
    .data_b ( 8'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_palette_dout[7:0] )
    );

// background palette ram high
dual_port_ram #(.LEN(1024), .DATA_WIDTH(8)) sprite_palram_h (
    .clock_a ( clk_sys ),
    .address_a ( dsp_host_palette_access ? shared_dsp_palette_addr : cpu_a[10:1] ),
    .wren_a ( (cpu_write_strobe & sprite_palette_cs & !cpu_uds_n) |
        (shared_dsp_palette_w & !shared_dsp_palette_tile) ),
    .data_a ( shared_dsp_palette_w ? shared_dsp_ram_din[15:8] : cpu_dout[15:8] ),
    .q_a ( sprite_palette_cpu_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_palette_addr ),
    .data_b ( 8'd0 ),
    .wren_b ( 1'b0 ),
    .q_b ( sprite_palette_dout[15:8] )
    );

// main 68k ram high
dual_port_ram #(.LEN(16384), .DATA_WIDTH(8)) ram16kx8_H 
(
    .clock_a ( clk_sys ),
    .address_a ( cpu_a[14:1] ),
    .wren_a ( cpu_write_strobe & ram_cs & !cpu_uds_n ),
    .data_a ( cpu_dout[15:8]  ),
    .q_a (  ram_dout[15:8] ),
    
    .clock_b( clk_sys ),
    .address_b( shared_dsp_ram_addr ),
    .wren_b( shared_dsp_ram_w ),
    .data_b( shared_dsp_ram_din[15:8] ),
    .q_b( shared_dsp_ram_dout[15:8] )
);

// main 68k ram low
dual_port_ram #(.LEN(16384), .DATA_WIDTH(8)) ram16kx8_L
(
    .clock_a( clk_sys ),
    .address_a( cpu_a[14:1] ),
    .wren_a( cpu_write_strobe & ram_cs & !cpu_lds_n ),
    .data_a( cpu_dout[7:0]  ),
    .q_a(  ram_dout[7:0] ),
    
    .clock_b( clk_sys ),
    .address_b( shared_dsp_ram_addr ),
    .wren_b( shared_dsp_ram_w ),
    .data_b( shared_dsp_ram_din[7:0] ),
    .q_b( shared_dsp_ram_dout[7:0] )
);



//wire [15:0] z80_shared_addr = z80_addr - 16'h8000;
//wire [23:0] m68k_shard_addr = cpu_a    - 24'h040000;

// z80 and 68k shared ram
// 4k
dual_port_ram #(.LEN(4096), .DATA_WIDTH(8))  shared_ram 
(
    .clock_a( clk_sys ),
    .address_a( cpu_a[12:1] ),
    .wren_a( cpu_write_strobe & shared_ram_cs & !cpu_lds_n),
    .data_a( cpu_dout[7:0]  ),
    .q_a( cpu_shared_dout[7:0] ),

    .clock_b( clk_sys ),
    .address_b( z80_addr[11:0] ),
    .data_b( z80_dout ),
    .wren_b( clk_3_5M & sound_ram_1_cs & ~z80_wr_n ),
    .q_b( z80_shared_dout )
    );

wire [11:0] sprite_rb_addr = 12'd0;
wire [11:0] sprite_rb_addr_a =
    shared_dsp_sprite_w ? { 1'b0, shared_dsp_sprite_slot, shared_dsp_sprite_word } :
                          cpu_a[12:1];
wire        sprite_rb_l_w =
    shared_dsp_sprite_w | (cpu_write_strobe & sprite_ram_cs & !cpu_lds_n);
wire        sprite_rb_h_w =
    shared_dsp_sprite_w | (cpu_write_strobe & sprite_ram_cs & !cpu_uds_n);
wire [7:0]  sprite_rb_l_din =
    shared_dsp_sprite_w ? shared_dsp_ram_din[7:0] : cpu_dout[7:0];
wire [7:0]  sprite_rb_h_din =
    shared_dsp_sprite_w ? shared_dsp_ram_din[15:8] : cpu_dout[15:8];

dual_port_ram #(.LEN(4096), .DATA_WIDTH(8)) sprite_ram_rb_l
(
    .clock_a( clk_sys ),
    .address_a( sprite_rb_addr_a ),
    .wren_a( sprite_rb_l_w ),
    .data_a( sprite_rb_l_din ),
    .q_a( sprite_rb_dout[7:0] ),

    .clock_b( clk_sys ),
    .address_b( sprite_rb_addr ),
    .data_b( 8'd0 ),
    .wren_b( 1'b0 ),
    .q_b( )
    );

dual_port_ram #(.LEN(4096), .DATA_WIDTH(8)) sprite_ram_rb_h
(
    .clock_a( clk_sys ),
    .address_a( sprite_rb_addr_a ),
    .wren_a( sprite_rb_h_w ),
    .data_a( sprite_rb_h_din ),
    .q_a( sprite_rb_dout[15:8] ),

    .clock_b( clk_sys ),
    .address_b( sprite_rb_addr ),
    .data_b( 8'd0 ),
    .wren_b( 1'b0 ),
    .q_b( )
    );

reg  [22:0] sdram_addr;
reg  [31:0] sdram_data;
reg         sdram_we;
reg         sdram_req;

wire        sdram_ack;
wire        sdram_valid;
wire [31:0] sdram_q;

sdram #(.CLK_FREQ(70.0)) sdram
(
  .reset(~pll_locked),
  .clk(clk_sys),

  // controller interface
  .addr(sdram_addr),
  .data(sdram_data),
  .we(sdram_we),
  .req(sdram_req),
  
  .ack(sdram_ack),
  .valid(sdram_valid),
  .q(sdram_q),

  // SDRAM interface
  .sdram_a(SDRAM_A),
  .sdram_ba(SDRAM_BA),
  .sdram_dq(SDRAM_DQ),
  .sdram_cke(SDRAM_CKE),
  .sdram_cs_n(SDRAM_nCS),
  .sdram_ras_n(SDRAM_nRAS),
  .sdram_cas_n(SDRAM_nCAS),
  .sdram_we_n(SDRAM_nWE),
  .sdram_dqml(SDRAM_DQML),
  .sdram_dqmh(SDRAM_DQMH)
);

wire        prog_cache_rom_cs;
wire [22:0] prog_cache_addr;
wire [15:0] prog_cache_data;
wire        prog_cache_valid;

wire [15:0] prog_rom_data_raw;
wire [15:0] prog_rom_data;
wire        prog_rom_data_valid;

reg         tile_rom_cs;
reg  [17:0] tile_rom_addr;
wire [31:0] tile_rom_data;
wire        tile_rom_data_valid;

wire        tile_cache_cs;
wire [17:0] tile_cache_addr;
wire [31:0] tile_cache_data;
wire        tile_cache_valid;

reg  [31:0] tile_data;

wire        sprite_rom_cs;
wire [17:0] sprite_rom_addr;
wire [31:0] sprite_rom_data;
wire        sprite_rom_data_valid;
wire        sprite_download_seen;
wire        sprite_download_nonzero;

reg  [31:0] sprite_data;

wire [15:0] sound_rom_1_addr;
wire  [7:0] sound_rom_1_data;
wire        sound_rom_1_data_valid;

// sdram priority based rom controller
// is a oe needed?
rom_controller rom_controller
(
    .reset(reset),

    // clock
    .clk(clk_sys),

    // program ROM interface
    .prog_rom_cs(prog_cache_rom_cs),
    .prog_rom_oe(1'b1),
    .prog_rom_addr(prog_cache_addr),
    .prog_rom_data(prog_cache_data),
    .prog_rom_data_valid(prog_cache_valid),

    // character ROM interface
    .tile_rom_cs(tile_cache_cs),
    .tile_rom_oe(1'b1),
    .tile_rom_addr(tile_cache_addr),
    .tile_rom_data(tile_cache_data),
    .tile_rom_data_valid(tile_cache_valid),


    // sprite ROM interface
    .sprite_rom_cs(sprite_rom_cs),
    .sprite_rom_oe(1'b1),
    .sprite_rom_addr(sprite_rom_addr),
    .sprite_rom_base_sel(2'd0),
    .sprite_rom_data(sprite_rom_data),
    .sprite_rom_data_valid(sprite_rom_data_valid),
    .sprite_download_seen(sprite_download_seen),
    .sprite_download_nonzero(sprite_download_nonzero),

    // sound ROM #1 interface
    .sound_rom_1_cs(sound_rom_1_cs),
    .sound_rom_1_oe(1'b1),
    .sound_rom_1_addr(z80_addr),
    .sound_rom_1_data(sound_rom_1_data),
    .sound_rom_1_data_valid(sound_rom_1_data_valid),

    // IOCTL interface
    .ioctl_addr(ioctl_addr),
    .ioctl_data(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_download(ioctl_download),
    .download_wait(rom_download_wait),

    // SDRAM interface
    .sdram_addr(sdram_addr),
    .sdram_data(sdram_data),
    .sdram_we(sdram_we),
    .sdram_req(sdram_req),
    .sdram_ack(sdram_ack),
    .sdram_valid(sdram_valid),
    .sdram_q(sdram_q)
  );


cache prog_cache
(
    .reset(reset),
    .clk(clk_sys),

    // client
    .cache_req(prog_rom_cs),
    .cache_addr(cpu_a[23:1]),
    .cache_valid(prog_rom_data_valid),
    .cache_data(prog_rom_data_raw),

    // to rom controller
    .rom_req(prog_cache_rom_cs),
    .rom_addr(prog_cache_addr),
    .rom_valid(prog_cache_valid),
    .rom_data(prog_cache_data)

); 

assign prog_rom_data = prog_rom_data_raw;

tile_cache tile_cache
(
    .reset(reset),
    .clk(clk_sys),

    // client
    .cache_req(tile_rom_cs),
    .cache_addr(tile_rom_addr),
    .cache_data(tile_rom_data),
    .cache_valid(tile_rom_data_valid),

    // to rom controller
    .rom_req(tile_cache_cs),
    .rom_addr(tile_cache_addr),
    .rom_data(tile_cache_data),
    .rom_valid(tile_cache_valid)

);

endmodule


module cc_shifter
(
    input clk_out,
    input i,
    output o
);

// We use a two-stages shift-register to synchronize SignalIn_clkA to the clkB clock domain
reg [1:0] r;

assign o = r[1];    // new signal synchronized to (=ready to be used in) clkB domain

always @(posedge clk_out) begin
    r[0] <= i;
    r[1] <= r[0];    // notice that we use clkB
end

endmodule
