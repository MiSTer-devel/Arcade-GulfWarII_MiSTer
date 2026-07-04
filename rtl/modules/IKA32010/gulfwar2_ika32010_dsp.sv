module gulfwar2_ika32010_dsp
#(
    parameter bit ROM_ADDR_SWAP_A0_A1 = 1'b0
)
(
    input  wire        CLK,
    input  wire        RST_N,
    input  wire        EN,

    input  wire        CE_F,
    input  wire        CE_R,

    input  wire        RS_N,
    input  wire        INT_N,
    input  wire        BIO_N,

    output wire [11:0] A,
    input  wire [15:0] DI,
    output wire [15:0] DO,

    output wire [11:0] PC,
    input  wire [15:0] ROM_Q,

    output wire        WE_N,
    output wire        DEN_N,
    output wire        MEN_N
);

wire        ika_rs_n = RST_N & RS_N;
wire        ika_men_n;
wire        ika_den_n;
wire        ika_we_n;
wire [11:0] ika_addr;
wire [15:0] ika_din;
wire [15:0] ika_dout;
wire        ika_dout_oe;
wire        ika_clkout;
wire        ika_clkout_pcen;
wire        ika_clkout_ncen;

// CE_R is part of the old local DSP contract. IKA32010 derives its own
// CLKOUT phases from CLKIN, so feed four CLKIN enables per 14 MHz slot.
// That keeps IKA's divided CLKOUT cadence aligned with the legacy CE_F
// host sampling without running the core at one quarter speed.
wire        old_ce_r_unused = CE_R;
reg  [2:0]  ika_clkin_phase;

always @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
        ika_clkin_phase <= 3'd0;
    end else if (!ika_rs_n || !EN) begin
        ika_clkin_phase <= 3'd0;
    end else if (CE_F) begin
        ika_clkin_phase <= 3'd0;
    end else if (ika_clkin_phase != 3'd4) begin
        ika_clkin_phase <= ika_clkin_phase + 3'd1;
    end
end

wire        ika_clkin_pcen = (EN | ~ika_rs_n) && (ika_clkin_phase != 3'd4);

assign A  = ika_addr;
assign PC = ROM_ADDR_SWAP_A0_A1 ? {ika_addr[11:2], ika_addr[0], ika_addr[1]} :
                                  ika_addr;
assign DO = ika_dout;

assign MEN_N = ~EN | ika_men_n;
assign DEN_N = ~EN | ika_den_n;
assign WE_N  = ~EN | ika_we_n | ~ika_dout_oe;

assign ika_din = !ika_men_n ? ROM_Q :
                 !ika_den_n ? DI :
                              ROM_Q;

IKA32010 u_ika32010
(
    .i_EMUCLK      (CLK),
    .i_CLKIN_PCEN  (ika_clkin_pcen),

    .o_CLKOUT      (ika_clkout),
    .o_CLKOUT_PCEN (ika_clkout_pcen),
    .o_CLKOUT_NCEN (ika_clkout_ncen),

    .i_RS_n        (ika_rs_n),

    .o_MEN_n       (ika_men_n),
    .o_DEN_n       (ika_den_n),
    .o_WE_n        (ika_we_n),
    .o_AOUT        (ika_addr),
    .i_DIN         (ika_din),
    .o_DOUT        (ika_dout),
    .o_DOUT_OE     (ika_dout_oe),

    .i_BIO_n       (BIO_N),
    .i_INT_n       (INT_N)
);

endmodule
