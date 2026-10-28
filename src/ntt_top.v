// KHỐI TOP-LEVEL NTT/INTT: 1 butterfly + FSM + ROM + sinh địa chỉ, bộ nhớ hệ số nằm ngoài core
//
// Luồng chạy (mỗi chu kỳ 1 butterfly, tổng 7 * 128 = 896 chu kỳ + 3 chu kỳ xả):
//   chu kỳ t   : FSM cho step/stage -> ntt_addr_gen phát mem_rd_idx_a/b, ROM tra twiddle
//   chu kỳ t+1 : bộ nhớ trả mem_rd_data_a/b (đọc đồng bộ), tw_q = twiddle đã đăng ký
//   chu kỳ t+3 : butterfly trả y0/y1 -> ghi vào mem_wr_idx_a/b (chỉ số = chỉ số lúc đọc, tính lại
//                từ step/stage đã trễ 3 chu kỳ)
// Ghi tại chỗ (in-place): y0 -> idx_a, y1 -> idx_b. Giữa hai tầng không cần chèn bubble nếu
// độ trễ đọc-ghi <= 64 chu kỳ (đã kiểm tra bằng ntt_schedule_model.py; ở đây chỉ là 4).
//
// Dùng với ntt_mem.v (hoặc macro SRAM có cùng cổng). Nạp đa thức vào bộ nhớ trước khi start,
// đọc kết quả sau khi done lên.

module ntt_top #(
    parameter [6:0] DRAIN_CYCLES = 7'd3   // = 1 (đọc đồng bộ) + 2 (butterfly)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        mode,              // 0: NTT, 1: INTT (chốt lúc start)
    output wire        busy,
    output wire        done,

    // giao diện bộ nhớ hệ số
    output wire [7:0]  mem_rd_idx_a,
    output wire [7:0]  mem_rd_idx_b,
    input  wire [11:0] mem_rd_data_a,     // trễ 1 chu kỳ sau mem_rd_idx_*
    input  wire [11:0] mem_rd_data_b,
    output wire        mem_wr_en,
    output wire [7:0]  mem_wr_idx_a,
    output wire [7:0]  mem_wr_idx_b,
    output wire [11:0] mem_wr_data_a,
    output wire [11:0] mem_wr_data_b
);
    wire [2:0]  stage;
    wire [6:0]  step;
    wire        run_mode, step_valid;
    wire [6:0]  twiddle_addr;
    wire [11:0] twiddle_data;

    ntt_fsm_rom #(.DRAIN_CYCLES(DRAIN_CYCLES)) u_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .mode         (mode),
        .current_stage(stage),
        .step_cnt     (step),
        .mode_out     (run_mode),
        .step_valid   (step_valid),
        .twiddle_addr (twiddle_addr),
        .twiddle_data (twiddle_data),
        .busy         (busy),
        .done         (done)
    );

    // ---------------- phía đọc ----------------
    ntt_addr_gen u_rd_addr (
        .mode (run_mode),
        .stage(stage),
        .step (step),
        .idx_a(mem_rd_idx_a),
        .idx_b(mem_rd_idx_b)
    );

    // twiddle trễ 1 chu kỳ để khớp độ trễ đọc đồng bộ của bộ nhớ
    // (đồng thời cắt đường ROM -> bộ nhân khỏi đường tới hạn)
    reg [11:0] tw_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tw_q <= 12'd0;
        else        tw_q <= twiddle_data;
    end

    single_butterfly u_butterfly (
        .clk       (clk),
        .rst_n     (rst_n),
        .mode      (run_mode),
        .in_a      (mem_rd_data_a),
        .in_b      (mem_rd_data_b),
        .in_twiddle(tw_q),
        .out_y0    (mem_wr_data_a),
        .out_y1    (mem_wr_data_b)
    );

    // ---------------- phía ghi: trễ (valid, stage, step) 3 chu kỳ ----------------
    reg        v1, v2, v3;
    reg [2:0]  stg_d1, stg_d2, stg_d3;
    reg [6:0]  stp_d1, stp_d2, stp_d3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1 <= 1'b0;     v2 <= 1'b0;     v3 <= 1'b0;
            stg_d1 <= 3'd1; stg_d2 <= 3'd1; stg_d3 <= 3'd1;
            stp_d1 <= 7'd0; stp_d2 <= 7'd0; stp_d3 <= 7'd0;
        end else begin
            v1 <= step_valid; v2 <= v1;     v3 <= v2;
            stg_d1 <= stage;  stg_d2 <= stg_d1; stg_d3 <= stg_d2;
            stp_d1 <= step;   stp_d2 <= stp_d1; stp_d3 <= stp_d2;
        end
    end

    ntt_addr_gen u_wr_addr (
        .mode (run_mode),
        .stage(stg_d3),
        .step (stp_d3),
        .idx_a(mem_wr_idx_a),
        .idx_b(mem_wr_idx_b)
    );

    assign mem_wr_en = v3;
endmodule