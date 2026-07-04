`default_nettype none

module gulfwar2_latches
(
    input  wire       clk,
    input  wire       reset,

    input  wire       main_wr,
    input  wire       coin_wr,
    input  wire [7:0] data,

    output reg        irq4_enable,
    output reg        flip_screen,
    output reg        bg_ram_bank,
    output reg        fg_rom_bank,
    output reg        dsp_int_gulfwar2,
    output reg        display_on,

    output reg        dsp_int_fshark,
    output reg        coin_counter_1,
    output reg        coin_counter_2,
    output reg        coin_lockout_1,
    output reg        coin_lockout_2,

    output reg  [7:0] main_q,
    output reg  [7:0] coin_q
);

wire [2:0] latch_sel = data[3:1];
wire       latch_d   = data[0];

always @(posedge clk) begin
    if (reset) begin
        main_q <= 8'd0;
        coin_q <= 8'd0;
    end else begin
        if (main_wr) main_q[latch_sel] <= latch_d;
        if (coin_wr) coin_q[latch_sel] <= latch_d;
    end
end

always @* begin
    irq4_enable     = main_q[2];
    flip_screen     = main_q[3];
    bg_ram_bank     = main_q[4];
    fg_rom_bank     = main_q[5];
    dsp_int_gulfwar2 = main_q[6];
    display_on      = main_q[7];

    dsp_int_fshark  = ~coin_q[0];
    coin_counter_1  = coin_q[4];
    coin_counter_2  = coin_q[5];
    coin_lockout_1  = coin_q[6];
    coin_lockout_2  = coin_q[7];
end

endmodule

`default_nettype wire
