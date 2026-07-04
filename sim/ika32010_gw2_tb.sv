`timescale 1ns/1ps

module ika32010_gw2_tb;

localparam int MAX_EVENTS = 128;

reg         clk_sys = 1'b0;
reg         reset = 1'b1;
reg         dsp_rom_loaded = 1'b1;
reg         dsp_active = 1'b0;
reg         tms_reset = 1'b1;
reg  [7:0]  tms_reset_count = 8'd0;
reg         tms_int_n = 1'b1;
reg         tms_bio = 1'b1;
reg  [15:0] tms_din = 16'd0;

wire [11:0] tms_addr;
wire [15:0] tms_dout;
wire [11:0] tms_rom_addr;
wire [15:0] tms_rom_dout;
wire        tms_we_n;
wire        tms_den_n;
wire        tms_men_n;

reg [15:0] dsp_rom [0:4095];
assign tms_rom_dout = dsp_rom[tms_rom_addr];

reg  [2:0]  clk14_count = 3'd0;
reg         clk_14M = 1'b0;
reg         clk_14M_N = 1'b0;

reg  [2:0]  dsp_host_seg = 3'd0;
reg  [13:0] shared_dsp_ram_addr = 14'd0;
reg         dsp_execute = 1'b0;
reg         cpu_halt_by_dsp = 1'b0;
reg         release_seen = 1'b0;
reg  [2:0]  dsp_int_delay = 3'd0;
reg  [15:0] shared_mem [0:8191];

integer     event_count = 0;
integer     dp_set_count = 0;
integer     max_cycles = 200000;

wire        gw_tms_we_raw       = (tms_we_n == 1'b0);
wire        gw_tms_den_raw      = (tms_den_n == 1'b0);
wire [2:0]  gw_tms_port         = tms_addr[2:0];
wire        gw_tms_port_wr      = gw_tms_we_raw;
wire        gw_tms_port_rd      = gw_tms_den_raw;
wire        gw_tms_port0_wr     = gw_tms_port_wr && (gw_tms_port == 3'h0);
wire        gw_tms_port1_wr     = gw_tms_port_wr && (gw_tms_port == 3'h1);
wire        gw_tms_port1_rd     = gw_tms_port_rd && (gw_tms_port == 3'h1);
wire        gw_tms_port3_wr     = gw_tms_port_wr && (gw_tms_port == 3'h3);
wire        gw_dsp_execute_set  =
    gw_tms_port1_wr && (dsp_host_seg == 3'h3) &&
    (shared_dsp_ram_addr[12:0] <= 13'd1) && (tms_dout == 16'd0);
wire        gw_tms_bio_release  = gw_tms_port3_wr && (tms_dout == 16'd0);
wire        gw_dsp_release_now  = gw_tms_bio_release && dsp_execute;

wire [15:0] host_port1_din =
    (dsp_host_seg == 3'h3) ? shared_mem[shared_dsp_ram_addr[12:0]] :
    16'h0000;

`ifdef USE_LEGACY_TMS320C1X
`define DSP_PC dut.PC
`define DSP_OP dut.IC
`define DSP_DP dut.ST.DP
`define DSP_DP_SET 1'b0
`define DSP_WRBUS 16'h0000

TMS320C1X dut
(
    .CLK     (clk_sys),
    .RST_N   (~reset),
    .EN      (dsp_rom_loaded && dsp_active),
    .CE_F    (clk_14M),
    .CE_R    (clk_14M_N),
    .RS_N    (~tms_reset),
    .INT_N   (tms_int_n),
    .BIO_N   (tms_bio),
    .A       (tms_addr),
    .DI      (tms_din),
    .DO      (tms_dout),
    .PC      (tms_rom_addr),
    .ROM_Q   (tms_rom_dout),
    .WE_N    (tms_we_n),
    .DEN_N   (tms_den_n),
    .MEN_N   (tms_men_n)
);
`else
`define DSP_PC dut.u_ika32010.if_pc
`define DSP_OP dut.u_ika32010.if_opcodereg
`define DSP_DP dut.u_ika32010.reg_dp
`define DSP_DP_SET dut.u_ika32010.reg_dp_set
`define DSP_WRBUS dut.u_ika32010.reg_wrbus

gulfwar2_ika32010_dsp
#(
    .ROM_ADDR_SWAP_A0_A1(1'b0)
)
dut
(
    .CLK     (clk_sys),
    .RST_N   (~reset),
    .EN      (dsp_rom_loaded && dsp_active),
    .CE_F    (clk_14M),
    .CE_R    (clk_14M_N),
    .RS_N    (~tms_reset),
    .INT_N   (tms_int_n),
    .BIO_N   (tms_bio),
    .A       (tms_addr),
    .DI      (tms_din),
    .DO      (tms_dout),
    .PC      (tms_rom_addr),
    .ROM_Q   (tms_rom_dout),
    .WE_N    (tms_we_n),
    .DEN_N   (tms_den_n),
    .MEN_N   (tms_men_n)
);
`endif

always #5 clk_sys = ~clk_sys;

always @(posedge clk_sys) begin
    if (reset) begin
        clk14_count <= 3'd0;
        clk_14M <= 1'b0;
        clk_14M_N <= 1'b0;
    end else begin
        if (clk14_count == 3'd4) begin
            clk14_count <= 3'd0;
        end else begin
            clk14_count <= clk14_count + 3'd1;
        end
        clk_14M <= (clk14_count == 3'd0);
        clk_14M_N <= (clk14_count == 3'd2);
    end
end

always @(posedge clk_sys) begin
    if (reset) begin
        tms_reset_count <= 8'd0;
        tms_reset <= 1'b1;
    end else if (tms_reset_count < 8'd50) begin
        tms_reset_count <= tms_reset_count + 8'd1;
    end else begin
        tms_reset <= 1'b0;
    end
end

always @(posedge clk_sys) begin
    if (reset) begin
        tms_int_n <= 1'b1;
        tms_bio <= 1'b1;
        tms_din <= 16'd0;
        dsp_active <= 1'b0;
        dsp_host_seg <= 3'd0;
        shared_dsp_ram_addr <= 14'd0;
        dsp_execute <= 1'b0;
        cpu_halt_by_dsp <= 1'b0;
        release_seen <= 1'b0;
        dsp_int_delay <= 3'd0;
    end else begin
        if (clk_14M_N && (dsp_int_delay != 3'd0)) begin
            dsp_int_delay <= dsp_int_delay - 3'd1;
        end

        if (gw_tms_port_rd) begin
            case (tms_addr[2:0])
                3'h1: tms_din <= host_port1_din;
                default: tms_din <= 16'd0;
            endcase
        end

        if (gw_tms_port_wr) begin
                event_count <= event_count + 1;
                $display("%0t WR p%0d dout=%04x pc=%03x a=%03x op=%04x dp=%0d seg=%0d addr=%04x exec=%0d bio=%0d",
                    $time, tms_addr[2:0], tms_dout, `DSP_PC,
                    tms_addr, `DSP_OP, `DSP_DP,
                    dsp_host_seg, shared_dsp_ram_addr, dsp_execute, tms_bio);
                case (tms_addr[2:0])
                    3'h0: begin
                        dsp_host_seg <= tms_dout[15:13];
                        shared_dsp_ram_addr <= {1'b0, tms_dout[12:0]};
                    end

                    3'h1: begin
                        dsp_execute <= gw_dsp_execute_set;
                        if (dsp_host_seg == 3'h3) begin
                            shared_mem[shared_dsp_ram_addr[12:0]] <= tms_dout;
                        end
                    end

                    3'h3: begin
                        if (tms_dout[15]) begin
                            tms_bio <= 1'b1;
                        end else if (tms_dout == 16'd0) begin
                            tms_bio <= 1'b0;
                            if (dsp_execute) begin
                                cpu_halt_by_dsp <= 1'b0;
                                dsp_execute <= 1'b0;
                                release_seen <= 1'b1;
                                $display("%0t RELEASE pc=%03x events=%0d dp_set_count=%0d",
                                    $time, `DSP_PC, event_count, dp_set_count);
                            end
                        end
                    end
                    default: begin
                    end
                endcase
        end

        if (gw_tms_port1_rd) begin
            $display("%0t RD  p1 din=%04x pc=%03x a=%03x op=%04x dp=%0d seg=%0d addr=%04x",
                $time, host_port1_din, `DSP_PC, tms_addr,
                `DSP_OP, `DSP_DP,
                dsp_host_seg, shared_dsp_ram_addr);
        end

        if (`DSP_DP_SET) begin
            dp_set_count <= dp_set_count + 1;
            $display("%0t DP_SET pc=%03x op=%04x dp_before=%0d wrbus=%04x",
                $time, `DSP_PC, `DSP_OP,
                `DSP_DP, `DSP_WRBUS);
        end

`ifdef TRACE_IKA_LOOP
        if (dut.u_ika32010.cyc_ncen &&
            (dut.u_ika32010.if_pc >= 12'h3f0) &&
            (dut.u_ika32010.if_pc <= 12'h410)) begin
            $display("%0t LOOP pc=%03x op=%04x cyc=%0d pcsel=%0d acc=%08x z=%0d n=%0d ar0=%04x ar1=%04x arp=%0d ram_a=%02x ram_q=%04x wr=%0d wrbus=%04x inlat=%04x",
                $time,
                dut.u_ika32010.if_pc,
                dut.u_ika32010.if_opcodereg,
                dut.u_ika32010.ex_inst_cycle,
                dut.u_ika32010.if_pc_modesel,
                dut.u_ika32010.alu_acc_output,
                dut.u_ika32010.alu_flag_zero,
                dut.u_ika32010.alu_flag_neg,
                dut.u_ika32010.reg_ar[0],
                dut.u_ika32010.reg_ar[1],
                dut.u_ika32010.reg_arp,
                dut.u_ika32010.ram_addr,
                dut.u_ika32010.ram_output,
                dut.u_ika32010.ram_wr,
                dut.u_ika32010.reg_wrbus,
                dut.u_ika32010.busctrl_inlatch);
        end
`endif

`ifdef TRACE_IKA_INT
        if (dut.u_ika32010.cyc_ncen || clk_14M || clk_14M_N) begin
            $display("%0t INT pc=%03x op=%04x cyc=%0d ncen=%0d pcen=%0d int_n=%0d z=%0d zz=%0d zzz=%0d lat=%0d intm=%0d rq=%0d ack=%0d delay=%0d active=%0d",
                $time,
                dut.u_ika32010.if_pc,
                dut.u_ika32010.if_opcodereg,
                dut.u_ika32010.ex_inst_cycle,
                dut.u_ika32010.cyc_ncen,
                dut.u_ika32010.cyc_pcen,
                tms_int_n,
                dut.u_ika32010.int_n_z,
                dut.u_ika32010.int_n_zz,
                dut.u_ika32010.int_n_zzz,
                dut.u_ika32010.int_latched,
                dut.u_ika32010.reg_intm,
                dut.u_ika32010.int_rq,
                dut.u_ika32010.int_ack,
                dsp_int_delay,
                dsp_active);
        end
`endif

        if (!dsp_active && !tms_reset) begin
            dsp_active <= 1'b1;
            tms_int_n <= 1'b1;
            dsp_int_delay <= 3'd3;
            cpu_halt_by_dsp <= 1'b1;
            $display("%0t START", $time);
        end else if (dsp_active) begin
            tms_int_n <= (dsp_int_delay != 3'd0);
        end

        if (event_count > MAX_EVENTS) begin
            $display("%0t FAIL too many DSP port events without stop", $time);
            $finish;
        end

        if (release_seen) begin
            repeat (20) @(posedge clk_sys);
            $finish;
        end
    end
end

initial begin
    integer idx;
    reg [15:0] arg_value;
    for (idx = 0; idx < 8192; idx = idx + 1) begin
        shared_mem[idx] = 16'h0000;
    end
    if ($value$plusargs("mem0=%h", arg_value)) shared_mem[13'h0000] = arg_value;
    if ($value$plusargs("mem1=%h", arg_value)) shared_mem[13'h0001] = arg_value;
    if ($value$plusargs("mem2=%h", arg_value)) shared_mem[13'h0002] = arg_value;
    if ($value$plusargs("mem3=%h", arg_value)) shared_mem[13'h0003] = arg_value;
    if ($value$plusargs("mem4=%h", arg_value)) shared_mem[13'h0004] = arg_value;
    if ($value$plusargs("mem100=%h", arg_value)) shared_mem[13'h0100] = arg_value;
    if ($value$plusargs("mem101=%h", arg_value)) shared_mem[13'h0101] = arg_value;
    if ($value$plusargs("mem102=%h", arg_value)) shared_mem[13'h0102] = arg_value;
    if ($value$plusargs("mem103=%h", arg_value)) shared_mem[13'h0103] = arg_value;
    void'($value$plusargs("max_cycles=%d", max_cycles));

    $readmemh("sim/gulfwar2_dsp_lohi.hex", dsp_rom);
    repeat (10) @(posedge clk_sys);
    reset = 1'b0;
    repeat (max_cycles) @(posedge clk_sys);
    $display("%0t TIMEOUT release_seen=%0d events=%0d dp_set_count=%0d pc=%03x op=%04x dp=%0d",
        $time, release_seen, event_count, dp_set_count, `DSP_PC,
        `DSP_OP, `DSP_DP);
    $finish;
end

endmodule
