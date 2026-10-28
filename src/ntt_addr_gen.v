// KHỐI SINH ĐỊA CHỈ HỆ SỐ CHO BUTTERFLY (thay thế nmi_reorder)
//
// Với butterfly thứ n (0..127) của một tầng, sinh cặp chỉ số hệ số (idx_a, idx_b)
// cách nhau len = 2^m, trong đó idx_a có bit m bằng 0:
//   idx_a = chèn bit 0 vào vị trí m của n,   idx_b = idx_a | (1 << m)
//   NTT  (mode = 0): m = 8 - stage  (len = 128 ... 2)
//   INTT (mode = 1): m = stage      (len = 2 ... 128)
// Logic thuần tổ hợp, không có thanh ghi (0 DFF).

module ntt_addr_gen (
    input  wire       mode,
    input  wire [2:0] stage,   // 1 .. 7
    input  wire [6:0] step,    // chỉ số butterfly trong tầng, 0 .. 127
    output reg  [7:0] idx_a,
    output reg  [7:0] idx_b
);
    wire [2:0] m = mode ? stage : (3'd0 - stage);  // 8 - stage (mod 8) với stage = 1..7

    always @(*) begin
        case (m)
            3'd1: begin idx_a = {step[6:1], 1'b0, step[0]};   idx_b = {step[6:1], 1'b1, step[0]};   end
            3'd2: begin idx_a = {step[6:2], 1'b0, step[1:0]}; idx_b = {step[6:2], 1'b1, step[1:0]}; end
            3'd3: begin idx_a = {step[6:3], 1'b0, step[2:0]}; idx_b = {step[6:3], 1'b1, step[2:0]}; end
            3'd4: begin idx_a = {step[6:4], 1'b0, step[3:0]}; idx_b = {step[6:4], 1'b1, step[3:0]}; end
            3'd5: begin idx_a = {step[6:5], 1'b0, step[4:0]}; idx_b = {step[6:5], 1'b1, step[4:0]}; end
            3'd6: begin idx_a = {step[6],   1'b0, step[5:0]}; idx_b = {step[6],   1'b1, step[5:0]}; end
            3'd7: begin idx_a = {1'b0, step};                 idx_b = {1'b1, step};                 end
            default: begin idx_a = 8'd0; idx_b = 8'd0; end
        endcase
    end
endmodule