// KHỐI TÍNH TOÁN NTT VÀ INTT (SINGLE BUTTERFLY)
//
// Công thức NTT (mode = 0), ngõ vào a, b, hệ số xoay zeta (dạng Montgomery):
//   y0 = a + b*zeta (mod q)
//   y1 = a - b*zeta (mod q)
//   -> nhân trước, cộng/trừ sau (u_post)
//
// Công thức INTT (mode = 1), theo FIPS 203 (Alg. 10) có chia 2 ở mỗi tầng:
//   y0 = (a + b) / 2            (mod q)
//   y1 = (b - a) * (zeta / 2)   (mod q)
//   -> cộng/trừ trước (u_pre), nhân sau.
//   Hệ số chia 2 của nhánh y1 được gộp vào ROM: ROM INTT phải chứa
//   (zeta * 2^-1 * 2^16) mod q (dạng Montgomery). Sau 7 tầng tổng hệ số là 1/128.
//
// Độ trễ: 2 chu kỳ clock (khớp với mod_multiplier có 2 tầng thanh ghi).
// Mọi tín hiệu (in_a, in_b, in_twiddle, mode) phải được cấp đồng thời tại chu kỳ t;
// kết quả out_y0/out_y1 hợp lệ tại chu kỳ t+2.

module single_butterfly (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mode,        // 0: NTT (Cooley-Tukey), 1: INTT (Gentleman-Sande)
    input  wire [11:0] in_a,
    input  wire [11:0] in_b,
    input  wire [11:0] in_twiddle,  // hệ số xoay dạng Montgomery (ROM NTT hoặc ROM INTT)
    output wire [11:0] out_y0,
    output wire [11:0] out_y1
);
    // ------------------------------------------------------------
    // Khối xử lý trước: lấy (b - a) và (a + b)/2 cho INTT
    // Đổi chỗ in_a/in_b để out_sub = b - a (đúng dấu theo FIPS 203)
    // ------------------------------------------------------------
    wire [11:0] pre_sub_res;   // b - a mod q
    wire [11:0] pre_div2_res;  // (a + b)/2 mod q
    mod_add_sub_div2 u_pre (
        .in_a    (in_b),
        .in_b    (in_a),
        .out_add (),
        .out_sub (pre_sub_res),
        .out_div2(pre_div2_res)
    );

    // NTT: nhân b*zeta | INTT: nhân (b - a)*(zeta/2)
    wire [11:0] mul_op_b = mode ? pre_sub_res : in_b;
    wire [11:0] mul_out;
    mod_multiplier u_mul (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_a   (in_twiddle),
        .in_b   (mul_op_b),
        .out_res(mul_out)      // trễ 2 chu kỳ
    );

    // ------------------------------------------------------------
    // 2 tầng flip-flop để đồng bộ với độ trễ của mod_multiplier
    // (gồm cả tín hiệu mode, để mux ngõ ra dùng đúng mode của phép toán đang ra)
    // ------------------------------------------------------------
    reg [11:0] in_a_ff1, in_a_ff2;
    reg [11:0] div2_ff1, div2_ff2;
    reg        mode_ff1, mode_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_a_ff1 <= 12'd0;
            in_a_ff2 <= 12'd0;
            div2_ff1 <= 12'd0;
            div2_ff2 <= 12'd0;
            mode_ff1 <= 1'b0;
            mode_ff2 <= 1'b0;
        end else begin
            in_a_ff1 <= in_a;
            in_a_ff2 <= in_a_ff1;
            div2_ff1 <= pre_div2_res;
            div2_ff2 <= div2_ff1;
            mode_ff1 <= mode;
            mode_ff2 <= mode_ff1;
        end
    end

    // ------------------------------------------------------------
    // Khối xử lý sau (chỉ dùng cho NTT): a +/- b*zeta
    // ------------------------------------------------------------
    wire [11:0] post_add_res, post_sub_res;
    mod_add_sub_div2 u_post (
        .in_a    (in_a_ff2),
        .in_b    (mul_out),
        .out_add (post_add_res),
        .out_sub (post_sub_res),
        .out_div2()
    );

    // INTT: y0 lấy thẳng (a+b)/2 đã trễ 2 nhịp, y1 là kết quả của bộ nhân
    assign out_y0 = mode_ff2 ? div2_ff2 : post_add_res;
    assign out_y1 = mode_ff2 ? mul_out  : post_sub_res;
endmodule