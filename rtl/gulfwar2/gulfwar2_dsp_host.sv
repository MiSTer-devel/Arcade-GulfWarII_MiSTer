`default_nettype none

module gulfwar2_dsp_host
(
    input  wire        clk,
    input  wire        reset,

    input  wire        dsp_int_enable,
    input  wire [2:0]  dsp_port,
    input  wire        dsp_port_rd,
    input  wire        dsp_port_wr,
    input  wire [15:0] dsp_dout,
    output reg  [15:0] dsp_din,

    output reg         dsp_int_n,
    output reg         dsp_bio_n,
    output reg         dsp_active,
    output reg         main_halt,

    output reg         host_rd,
    output reg         host_wr,
    output wire [23:1] host_addr,
    output reg  [15:0] host_dout,
    input  wire [15:0] host_din,
    output wire        host_addr_valid
);

reg [2:0]  host_seg;
reg [12:0] host_word_addr;
reg        execute_pending;

assign host_addr = {5'd0, host_seg, 2'd0, host_word_addr};
assign host_addr_valid = (host_seg == 3'h3) || (host_seg == 3'h4) || (host_seg == 3'h5);

always @(posedge clk) begin
    if (reset) begin
        host_seg <= 3'd0;
        host_word_addr <= 13'd0;
        execute_pending <= 1'b0;
        dsp_din <= 16'd0;
        dsp_int_n <= 1'b1;
        dsp_bio_n <= 1'b1;
        dsp_active <= 1'b0;
        main_halt <= 1'b0;
        host_rd <= 1'b0;
        host_wr <= 1'b0;
        host_dout <= 16'd0;
    end else begin
        host_rd <= 1'b0;
        host_wr <= 1'b0;

        dsp_active <= dsp_int_enable;
        dsp_int_n <= ~dsp_int_enable;
        if (dsp_int_enable) begin
            main_halt <= 1'b1;
        end

        if (dsp_port_wr) begin
            case (dsp_port)
                3'd0: begin
                    host_seg <= dsp_dout[15:13];
                    host_word_addr <= dsp_dout[12:0];
                end
                3'd1: begin
                    host_dout <= dsp_dout;
                    if (host_addr_valid) host_wr <= 1'b1;
                    if ((host_seg == 3'h3) && (host_word_addr <= 13'd1) && (dsp_dout == 16'd0)) begin
                        execute_pending <= 1'b1;
                    end
                end
                3'd3: begin
                    if (dsp_dout[15]) dsp_bio_n <= 1'b1;
                    if (dsp_dout == 16'd0) begin
                        dsp_bio_n <= 1'b0;
                        if (execute_pending) begin
                            main_halt <= 1'b0;
                            execute_pending <= 1'b0;
                        end
                    end
                end
                default: begin
                end
            endcase
        end

        if (dsp_port_rd) begin
            if (dsp_port == 3'd1) begin
                if (host_addr_valid) host_rd <= 1'b1;
                dsp_din <= host_addr_valid ? host_din : 16'd0;
            end else begin
                dsp_din <= 16'd0;
            end
        end
    end
end

endmodule

`default_nettype wire
