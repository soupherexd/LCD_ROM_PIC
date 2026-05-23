// ============================================================================
// lcd_text_overlay.v — LCD 屏幕文字叠加显示模块
//
// 功能：在屏幕右上角叠加显示当前模式和功能文字
//       使用 48x48 点阵汉字字模（微软雅黑）
//
// 文字布局：
//   第1行 (y=8..55):  运动/拉伸模式 → 静态显示 / 左右移动 / 上下移动 / 对角移动
//                                       左右拉伸 / 上下拉伸
//   第2行 (y=62..109): 显示模式 → 原图 / 二值化 / 边缘检测
//   文字颜色：原图模式=黑色, 二值化/边缘检测模式=白色
// ============================================================================

module lcd_text_overlay(
    input               lcd_clk,
    input               sys_rst_n,
    input      [1:0]    motion_mode,    // 00=静止, 01=左右移动, 10=上下移动, 11=对角移动
    input      [1:0]    stretch_mode,   // 00=无, 01=左右拉伸(B3), 10=上下拉伸(B4)
    input      [1:0]    display_mode,   // 00=原图, 01=二值化, 10=边缘检测
    input      [10:0]   pixel_xpos,
    input      [10:0]   pixel_ypos,
    input      [23:0]   pixel_data_in,
    output reg [23:0]   pixel_data_out
);

// ============================================================================
// 参数
// ============================================================================
localparam TEXT_X     = 11'd600;   // 文字起始X (800-200=600, 4字*50px=200)
localparam TEXT_Y_L1  = 11'd8;     // 第1行起始Y
localparam TEXT_Y_L2  = 11'd62;    // 第2行起始Y (8+48+6)
localparam CHAR_SIZE  = 6'd48;     // 字符大小 48x48
localparam CHAR_STEP  = 6'd50;     // 字符步进（含2px间距）

// ============================================================================
// 字符索引表（与 font_rom.v 一致）
// ============================================================================
//  0:上  1:下  2:二  3:伸  4:值  5:动
//  6:化  7:原  8:右  9:图 10:对 11:左
// 12:态 13:拉 14:显 15:检 16:测 17:示
// 18:移 19:缘 20:角 21:边 22:静

// 字符串 → 字符索引数组
// "静态显示" → [22, 12, 14, 17]  (静,态,显,示)
// "左右移动" → [11, 8, 18, 5]   (左,右,移,动)
// "上下移动" → [0, 1, 18, 5]    (上,下,移,动)
// "对角移动" → [10, 20, 18, 5]  (对,角,移,动)
// "左右拉伸" → [11, 8, 13, 3]   (左,右,拉,伸)
// "上下拉伸" → [0, 1, 13, 3]    (上,下,拉,伸)
// "原图"     → [7, 9]           (原,图)
// "二值化"   → [2, 4, 6]        (二,值,化)
// "边缘检测" → [21, 19, 15, 16] (边,缘,检,测)

// ============================================================================
// 当前像素是否在文字区域内
// ============================================================================
wire in_text_area_l1, in_text_area_l2;
wire [10:0] local_x;        // 相对于文字区域起点的X偏移
wire [10:0] local_y_l1;     // 相对于第1行的Y偏移
wire [10:0] local_y_l2;     // 相对于第2行的Y偏移
wire [5:0]  char_col;       // 字符内的列 (0~47)
wire [5:0]  char_row;       // 字符内的行 (0~47)
wire [4:0]  char_idx;       // 字符在当前字符串中的位置

assign local_x    = pixel_xpos - TEXT_X;
assign local_y_l1 = pixel_ypos - TEXT_Y_L1;
assign local_y_l2 = pixel_ypos - TEXT_Y_L2;

assign in_text_area_l1 = (pixel_xpos >= TEXT_X) && (pixel_xpos < TEXT_X + 6 * CHAR_STEP)
                       && (pixel_ypos >= TEXT_Y_L1) && (pixel_ypos < TEXT_Y_L1 + CHAR_SIZE);
assign in_text_area_l2 = (pixel_xpos >= TEXT_X) && (pixel_xpos < TEXT_X + 6 * CHAR_STEP)
                       && (pixel_ypos >= TEXT_Y_L2) && (pixel_ypos < TEXT_Y_L2 + CHAR_SIZE);
assign in_text_area = in_text_area_l1 || in_text_area_l2;

assign char_idx  = local_x / CHAR_STEP;
assign char_col  = local_x % CHAR_STEP;
assign char_row  = in_text_area_l1 ? local_y_l1[5:0] : local_y_l2[5:0];

// 字符位置有效性：只在字符串实际长度范围内显示
wire char_valid;
assign char_valid = in_text_area_l1 ? (char_idx < 5'd4) :
                    (in_text_area_l2 && (display_mode == 2'b00)) ? (char_idx < 5'd2) :   // "原图" 2字
                    (in_text_area_l2 && (display_mode == 2'b01)) ? (char_idx < 5'd3) :   // "二值化" 3字
                    (in_text_area_l2 && (display_mode == 2'b10)) ? (char_idx < 5'd4) :   // "边缘检测" 4字
                    1'b0;

// ============================================================================
// 根据模式生成字符地址
// ============================================================================
reg [4:0] char_addr;

always @(*) begin
    if (in_text_area_l1) begin
        // 第1行：先判断拉伸模式，再判断运动模式
        if (stretch_mode == 2'b01) begin  // 左右拉伸
            case (char_idx)
                5'd0: char_addr = 5'd11;  // 左
                5'd1: char_addr = 5'd8;   // 右
                5'd2: char_addr = 5'd13;  // 拉
                5'd3: char_addr = 5'd3;   // 伸
                default: char_addr = 5'd0;
            endcase
        end else if (stretch_mode == 2'b10) begin  // 上下拉伸
            case (char_idx)
                5'd0: char_addr = 5'd0;   // 上
                5'd1: char_addr = 5'd1;   // 下
                5'd2: char_addr = 5'd13;  // 拉
                5'd3: char_addr = 5'd3;   // 伸
                default: char_addr = 5'd0;
            endcase
        end else begin  // 无拉伸，显示运动模式
            case (motion_mode)
                2'b00: begin  // 静止 → 静态显示
                    case (char_idx)
                        5'd0: char_addr = 5'd22;  // 静
                        5'd1: char_addr = 5'd12;  // 态
                        5'd2: char_addr = 5'd14;  // 显
                        5'd3: char_addr = 5'd17;  // 示
                        default: char_addr = 5'd0;
                    endcase
                end
                2'b01: begin  // 左右移动
                    case (char_idx)
                        5'd0: char_addr = 5'd11;  // 左
                        5'd1: char_addr = 5'd8;   // 右
                        5'd2: char_addr = 5'd18;  // 移
                        5'd3: char_addr = 5'd5;   // 动
                        default: char_addr = 5'd0;
                    endcase
                end
                2'b10: begin  // 上下移动
                    case (char_idx)
                        5'd0: char_addr = 5'd0;   // 上
                        5'd1: char_addr = 5'd1;   // 下
                        5'd2: char_addr = 5'd18;  // 移
                        5'd3: char_addr = 5'd5;   // 动
                        default: char_addr = 5'd0;
                    endcase
                end
                2'b11: begin  // 对角移动
                    case (char_idx)
                        5'd0: char_addr = 5'd10;  // 对
                        5'd1: char_addr = 5'd20;  // 角
                        5'd2: char_addr = 5'd18;  // 移
                        5'd3: char_addr = 5'd5;   // 动
                        default: char_addr = 5'd0;
                    endcase
                end
                default: char_addr = 5'd0;
            endcase
        end
    end else if (in_text_area_l2) begin
        // 第2行：显示模式 00=原图, 01=二值化, 10=边缘检测
        case (display_mode)
            2'b00: begin  // 原图
                case (char_idx)
                    5'd0: char_addr = 5'd7;   // 原
                    5'd1: char_addr = 5'd9;   // 图
                    default: char_addr = 5'd0;
                endcase
            end
            2'b01: begin  // 二值化
                case (char_idx)
                    5'd0: char_addr = 5'd2;   // 二
                    5'd1: char_addr = 5'd4;   // 值
                    5'd2: char_addr = 5'd6;   // 化
                    default: char_addr = 5'd0;
                endcase
            end
            2'b10: begin  // 边缘检测
                case (char_idx)
                    5'd0: char_addr = 5'd21;  // 边
                    5'd1: char_addr = 5'd19;  // 缘
                    5'd2: char_addr = 5'd15;  // 检
                    5'd3: char_addr = 5'd16;  // 测
                    default: char_addr = 5'd0;
                endcase
            end
            default: char_addr = 5'd0;
        endcase
    end else begin
        char_addr = 5'd0;
    end
end

// ============================================================================
// 1-cycle pipeline: 查字体ROM并延迟原始像素
// ============================================================================
reg  in_text_area_r;
reg  char_valid_r;
reg  [5:0] char_col_r;
reg  [23:0] pixel_data_r;

wire [47:0] font_pixels;

font_rom u_font_rom(
    .clk        (lcd_clk),
    .char_addr  (char_addr),
    .row_addr   (char_row),
    .pixel_data (font_pixels)
);

always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        in_text_area_r <= 1'b0;
        char_valid_r   <= 1'b0;
        char_col_r     <= 6'd0;
        pixel_data_r   <= 24'd0;
    end else begin
        in_text_area_r <= in_text_area;
        char_valid_r   <= char_valid;
        char_col_r     <= char_col;
        pixel_data_r   <= pixel_data_in;
    end
end

// ============================================================================
// 输出：文字区域内且该像素为前景色时显示文字，否则透传
// ============================================================================
wire pixel_on;

// 动态文字颜色：原图=黑色, 二值化/边缘检测=白色
wire [23:0] text_color;
assign text_color = (display_mode == 2'b00) ? 24'h00_00_00 : 24'hFF_FF_FF;

// 判断当前像素在字符中的位置是否为前景 (font_pixels 为48bit, 每bit一列)
// font_pixels[47] = 最左列, font_pixels[0] = 最右列
// char_col=0 → font_pixels[47], char_col=1 → font_pixels[46], ...
assign pixel_on = in_text_area_r && char_valid_r && (char_col_r < 6'd48) && font_pixels[47 - char_col_r];

always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pixel_data_out <= 24'd0;
    else if (pixel_on)
        pixel_data_out <= text_color;
    else
        pixel_data_out <= pixel_data_r;
end

endmodule
