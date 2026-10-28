// BỘ NHỚ HỆ SỐ 256 x 12 bit, CHIA 2 BANK (mô hình tham chiếu cho mô phỏng/FPGA)
//
// - bank(idx) = XOR của 8 bit idx; hàng trong bank = idx[7:1]. Hai hệ số của một butterfly
//   chỉ khác nhau đúng 1 bit nên luôn nằm ở 2 bank khác nhau -> mỗi chu kỳ đọc 2 và ghi 2 hệ số.
// - Mỗi bank có 1 cổng đọc + 1 cổng ghi. Đọc đồng bộ, độ trễ 1 chu kỳ; đọc cùng chu kỳ ghi
//   trả dữ liệu cũ (read-first).
// - Khi busy = 1: cổng core hoạt động. Khi busy = 0: cổng host (nạp/đọc đa thức) hoạt động.
// - Khi làm ASIC, thay hai mảng bank0/bank1 bằng macro SRAM (loại 1 RW + 1 R) hoặc mảng latch,
//   giữ nguyên các cổng này. Diện tích ASIC của bộ tăng tốc chỉ tính ntt_top, không tính khối này.

module ntt_mem (
    input  wire        clk,
    input  wire        busy,          // từ ntt_top: 1 = core đang chiếm bộ nhớ

    // cổng phía core
    input  wire [7:0]  rd_idx_a,
    input  wire [7:0]  rd_idx_b,
    output wire [11:0] rd_data_a,     // hợp lệ sau 1 chu kỳ
    output wire [11:0] rd_data_b,
    input  wire        wr_en,
    input  wire [7:0]  wr_idx_a,
    input  wire [7:0]  wr_idx_b,
    input  wire [11:0] wr_data_a,
    input  wire [11:0] wr_data_b,

    // cổng phía host (chỉ dùng khi busy = 0)
    input  wire        host_we,
    input  wire [7:0]  host_idx,
    input  wire [11:0] host_wdata,
    output wire [11:0] host_rdata     // hợp lệ sau 1 chu kỳ
);
    reg [11:0] bank0 [0:127];
    reg [11:0] bank1 [0:127];
    reg [11:0] q0, q1;
    reg        sel_core_q, sel_host_q;

    // đọc
    wire       bank_ra = ^rd_idx_a;
    wire [6:0] row_ra  = rd_idx_a[7:1];
    wire [6:0] row_rb  = rd_idx_b[7:1];
    wire       bank_h  = ^host_idx;
    wire [6:0] row_h   = host_idx[7:1];

    wire [6:0] rd_addr0 = busy ? (bank_ra ? row_rb : row_ra) : row_h;
    wire [6:0] rd_addr1 = busy ? (bank_ra ? row_ra : row_rb) : row_h;

    assign rd_data_a  = sel_core_q ? q1 : q0;
    assign rd_data_b  = sel_core_q ? q0 : q1;
    assign host_rdata = sel_host_q ? q1 : q0;

    // ghi
    wire       bank_wa = ^wr_idx_a;
    wire [6:0] row_wa  = wr_idx_a[7:1];
    wire [6:0] row_wb  = wr_idx_b[7:1];

    wire        we0 = busy ? wr_en : (host_we & ~bank_h);
    wire        we1 = busy ? wr_en : (host_we &  bank_h);
    wire [6:0]  wa0 = busy ? (bank_wa ? row_wb : row_wa) : row_h;
    wire [6:0]  wa1 = busy ? (bank_wa ? row_wa : row_wb) : row_h;
    wire [11:0] wd0 = busy ? (bank_wa ? wr_data_b : wr_data_a) : host_wdata;
    wire [11:0] wd1 = busy ? (bank_wa ? wr_data_a : wr_data_b) : host_wdata;

    always @(posedge clk) begin
        if (we0) bank0[wa0] <= wd0;
        if (we1) bank1[wa1] <= wd1;
        q0         <= bank0[rd_addr0];
        q1         <= bank1[rd_addr1];
        sel_core_q <= bank_ra;
        sel_host_q <= bank_h;
    end
endmodule