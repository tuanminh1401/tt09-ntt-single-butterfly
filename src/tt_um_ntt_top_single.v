`default_nettype none

module tt_um_ntt_top_single (
    input  wire [7:0] ui_in,    // Inputs dedicated
    output wire [7:0] uo_out,   // Outputs dedicated
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output, 0=input)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire rst = ~rst_n;
    wire start = ui_in[0];
    wire done;
    wire [15:0] data_out;

    ntt_top single_butterfly_inst (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .done     (done),
        .data_out (data_out)
    );

    assign uo_out = (ui_in[1]) ? data_out[15:8] : {data_out[7:1], done};

endmodule
