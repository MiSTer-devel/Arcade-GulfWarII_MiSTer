`default_nettype none

module gulfwar2_sound_decode
(
    input  wire [15:0] addr,
    input  wire        mreq_n,
    input  wire        iorq_n,
    input  wire        rd_n,
    input  wire        wr_n,

    output wire        mem_read,
    output wire        mem_write,
    output wire        io_read,
    output wire        io_write,

    output wire        rom_cs,
    output wire        shared_ram_cs,
    output wire        ym3812_cs,
    output wire        ym3812_addr,
    output wire        system_cs,
    output wire        coinlatch_cs,
    output wire        dswa_cs,
    output wire        dswb_cs
);

assign mem_read  = !mreq_n && !rd_n;
assign mem_write = !mreq_n && !wr_n;
assign io_read   = !iorq_n && !rd_n;
assign io_write  = !iorq_n && !wr_n;

wire mem_cycle = !mreq_n;
wire io_cycle  = !iorq_n;
wire [7:0] port = addr[7:0];

assign rom_cs        = mem_cycle && (addr <= 16'h7fff);
assign shared_ram_cs = mem_cycle && (addr >= 16'h8000) && (addr <= 16'h87ff);

assign ym3812_cs   = io_cycle && (port[7:1] == 7'h00);
assign ym3812_addr = port[0];
assign system_cs   = io_read  && (port == 8'h10);
assign coinlatch_cs = io_write && (port == 8'h20);
assign dswa_cs     = io_read  && (port == 8'h40);
assign dswb_cs     = io_read  && (port == 8'h50);

endmodule

`default_nettype wire
