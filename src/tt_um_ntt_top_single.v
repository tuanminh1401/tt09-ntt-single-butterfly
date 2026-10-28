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

    // Vô hiệu hóa các chân IO hai chiều không dùng tới
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Tín hiệu điều khiển
    wire start = ui_in[0];
    wire mode  = ui_in[1];

    // Tín hiệu trạng thái
    wire busy;
    wire done;

    // Tín hiệu giao diện bộ nhớ nối giữa ntt_top và ntt_mem
    wire [7:0]  mem_rd_idx_a;
    wire [7:0]  mem_rd_idx_b;
    wire [11:0] mem_rd_data_a;
    wire [11:0] mem_rd_data_b;
    wire        mem_wr_en;
    wire [7:0]  mem_wr_idx_a;
    wire [7:0]  mem_wr_idx_b;
    wire [11:0] mem_wr_data_a;
    wire [11:0] mem_wr_data_b;

    // Khởi tạo Lõi tính toán NTT Single Butterfly
    ntt_top u_ntt_top (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .mode          (mode),
        .busy          (busy),
        .done          (done),
        .mem_rd_idx_a  (mem_rd_idx_a),
        .mem_rd_idx_b  (mem_rd_idx_b),
        .mem_rd_data_a (mem_rd_data_a),
        .mem_rd_data_b (mem_rd_data_b),
        .mem_wr_en     (mem_wr_en),
        .mem_wr_idx_a  (mem_wr_idx_a),
        .mem_wr_idx_b  (mem_wr_idx_b),
        .mem_wr_data_a (mem_wr_data_a),
        .mem_wr_data_b (mem_wr_data_b)
    );

    // Khởi tạo Bộ nhớ hệ số (DFF / Standard Cell)
    ntt_mem u_ntt_mem (
        .clk           (clk),
        .rd_idx_a      (mem_rd_idx_a),
        .rd_idx_b      (mem_rd_idx_b),
        .rd_data_a     (mem_rd_data_a),
        .rd_data_b     (mem_rd_data_b),
        .wr_en         (mem_wr_en),
        .wr_idx_a      (mem_wr_idx_a),
        .wr_idx_b      (mem_wr_idx_b),
        .wr_data_a     (mem_wr_data_a),
        .wr_data_b     (mem_wr_data_b)
    );

    // Mapping chân ra cho chip Tiny Tapeout
    // uo_out[0]: done, uo_out[1]: busy, uo_out[7:2]: 6-bit của dữ liệu đọc
    assign uo_out = {mem_rd_data_a[5:0], busy, done};

endmodule
