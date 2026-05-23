// ============================================================================
// lcd_binary.v — 图像二值化模块
//
// 功能：对输入的 RGB888 像素进行二值化处理
//       灰度值 > TH → 黑色(0x000000)
//       灰度值 ≤ TH → 白色(0xFFFFFF)
//
// 参考算法：main.cpp 中的二值化部分
//   if (gray > TH) pixel = 0; else pixel = 255;
// ============================================================================

module lcd_binary(
    input               lcd_clk,
    input               sys_rst_n,
    input      [23:0]   pixel_data_in,
    output reg [23:0]   pixel_data_out
);

// 二值化阈值 (降低至128使输出更均衡)
localparam TH = 8'd150;

// 灰度转换: gray = (R + G + B) / 4
wire [9:0] sum_rgb;
wire [7:0] gray;

assign sum_rgb = pixel_data_in[23:16] + pixel_data_in[15:8] + pixel_data_in[7:0];
assign gray   = sum_rgb[9:2];

// 二值化输出 (1周期流水线)
always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pixel_data_out <= 24'd0;
    else if (gray > TH)
        pixel_data_out <= 24'h00_00_00;  // 黑色
    else
        pixel_data_out <= 24'hFF_FF_FF;  // 白色
end

endmodule
