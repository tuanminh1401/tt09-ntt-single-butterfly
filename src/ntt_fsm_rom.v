// KHỐI FSM ĐIỀU KHIỂN VÀ GIẢI MÃ ĐỊA CHỈ HỆ SỐ XOAY (NTT / INTT)
//
// Quản lý 7 tầng biến đổi, mỗi tầng 128 butterfly (7 * 128 = 896 chu kỳ) cộng thêm
// DRAIN_CYCLES chu kỳ xả pipeline trước khi báo done (tổng 899 chu kỳ từ lúc start).
//
// Chế độ (mode chốt tại thời điểm start):
//   mode = 0 (NTT,  FIPS 203 Alg. 9 ): tầng 1..7 ứng với len = 128 ... 2
//        địa chỉ ROM = 2^(stage-1) + (step_cnt >> (8 - stage))      (k = 1 ... 127)
//   mode = 1 (INTT, FIPS 203 Alg. 10): tầng 1..7 ứng với len = 2 ... 128
//        địa chỉ ROM = 2^(8-stage) - 1 - (step_cnt >> stage)        (k = 127 ... 1)
//   ROM NTT chứa zeta*R, ROM INTT chứa (zeta/2)*R (xem twiddle_rom.v / gen_twiddle_rom.py).
//
// step_cnt cũng là chỉ số butterfly trong tầng, dùng để sinh địa chỉ hệ số (ntt_addr_gen).
// Độ trễ từ lúc phát địa chỉ đọc đến lúc ghi xong kết quả = 1 (đọc đồng bộ) + 2 (butterfly)
// = 3 chu kỳ, nên DRAIN_CYCLES mặc định = 3.

module ntt_fsm_rom #(
    parameter [6:0] DRAIN_CYCLES = 7'd3
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,          // xung bắt đầu NTT/INTT (chỉ nhận khi đang rảnh)
    input  wire        mode,           // 0: NTT, 1: INTT (chốt lúc start)
    output reg  [2:0]  current_stage,  // tầng hiện tại (1 -> 7)
    output reg  [6:0]  step_cnt,       // chỉ số butterfly trong tầng (0 -> 127)
    output wire        mode_out,       // mode đã chốt, ổn định suốt quá trình chạy
    output wire        step_valid,     // 1 khi step_cnt/current_stage là một butterfly thật
    output wire [6:0]  twiddle_addr,   // địa chỉ ROM (0 khi không chạy)
    output wire [11:0] twiddle_data,   // hệ số xoay từ ROM (tổ hợp, cùng chu kỳ với step_cnt)
    output wire        busy,           // 1 từ lúc nhận start đến hết giai đoạn xả
    output reg         done            // xung 1 chu kỳ khi hoàn tất, dữ liệu đã nằm trong bộ nhớ
);
    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_RUN   = 2'd1;
    localparam [1:0] S_DRAIN = 2'd2;

    reg [1:0] state;
    reg       mode_r;     // mode đã chốt lúc start

    assign busy       = (state != S_IDLE);
    assign step_valid = (state == S_RUN);
    assign mode_out   = mode_r;

    // ------------------------------------------------------------
    // Giải mã địa chỉ ROM
    // ------------------------------------------------------------
    reg [6:0] addr_fwd, addr_inv;

    always @(*) begin
        case (current_stage)
            3'd1: begin addr_fwd = 7'd1;                          addr_inv = 7'd127 - {1'b0, step_cnt[6:1]}; end
            3'd2: begin addr_fwd = 7'd2  + {6'b0, step_cnt[6]};   addr_inv = 7'd63  - {2'b0, step_cnt[6:2]}; end
            3'd3: begin addr_fwd = 7'd4  + {5'b0, step_cnt[6:5]}; addr_inv = 7'd31  - {3'b0, step_cnt[6:3]}; end
            3'd4: begin addr_fwd = 7'd8  + {4'b0, step_cnt[6:4]}; addr_inv = 7'd15  - {4'b0, step_cnt[6:4]}; end
            3'd5: begin addr_fwd = 7'd16 + {3'b0, step_cnt[6:3]}; addr_inv = 7'd7   - {5'b0, step_cnt[6:5]}; end
            3'd6: begin addr_fwd = 7'd32 + {2'b0, step_cnt[6:2]}; addr_inv = 7'd3   - {6'b0, step_cnt[6]};   end
            3'd7: begin addr_fwd = 7'd64 + {1'b0, step_cnt[6:1]}; addr_inv = 7'd1;                          end
            default: begin addr_fwd = 7'd0; addr_inv = 7'd0; end
        endcase
    end

    assign twiddle_addr = (state == S_RUN) ? (mode_r ? addr_inv : addr_fwd) : 7'd0;

    // ROM sinh bằng script (twiddle_rom.v), không dùng $readmemh để tổng hợp được trên ASIC
    twiddle_rom u_rom (
        .mode(mode_r),
        .addr(twiddle_addr),
        .data(twiddle_data)
    );

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            step_cnt      <= 7'd0;
            current_stage <= 3'd1;
            mode_r        <= 1'b0;
            done          <= 1'b0;
        end else begin
            done <= 1'b0;  // mặc định; chỉ lên 1 đúng 1 chu kỳ ở cuối S_DRAIN
            case (state)
                S_IDLE: begin
                    step_cnt      <= 7'd0;
                    current_stage <= 3'd1;
                    if (start) begin
                        mode_r <= mode;
                        state  <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (step_cnt == 7'd127) begin
                        step_cnt <= 7'd0;
                        if (current_stage == 3'd7) begin
                            state <= S_DRAIN;
                        end else begin
                            current_stage <= current_stage + 3'd1;
                        end
                    end else begin
                        step_cnt <= step_cnt + 7'd1;
                    end
                end

                S_DRAIN: begin
                    if (step_cnt == DRAIN_CYCLES - 7'd1) begin
                        step_cnt <= 7'd0;
                        state    <= S_IDLE;
                        done     <= 1'b1;
                    end else begin
                        step_cnt <= step_cnt + 7'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule