module lcd_display(
    input             lcd_clk,                  //lcd驱动时钟
    input             sys_rst_n,                //复位信号
    input		B0,B1,B2,B3,B4,
    input             A0,                       // 按键A0：原图显示
    input             A1,                       // 按键A1：二值化显示
    input             A2,                       // 按键A2：边缘检测显示
    input      [10:0] pixel_xpos,               //像素点横坐标
    input      [10:0] pixel_ypos,               //像素点纵坐标    
    output     [23:0] pixel_data                //像素点数据
    );    
    
parameter H_DISP = 11'd800;//分辨率一行
parameter V_DISP = 11'd480;//分辨率一列

// 图像参数 - 160*160
localparam WIDTH  = 10'd160;
localparam HEIGHT = 10'd160;
localparam TOTAL  = 15'd25600; // 160*160
localparam YELLOW = 24'b11111111_11111111_00000000; // 黄色
localparam RED    = 24'b11111111_00000000_00000000; // 红色
localparam WHITE  = 24'b11111111_11111111_11111111; // 白色

// 基础位置（要求1指定）
localparam POS_X_BASE = 10'd230;
localparam POS_Y_BASE = 10'd150;

// === 运动控制相关 ===
// 假设 lcd_clk = 33.3MHz，则每秒 33,300,000 像素时钟
// 要求速度：60 px/s → 每次移动间隔 = 33.3e6 / 60 ≈ 555,000 个时钟周期
localparam MOVE_CNT_MAX = 20'd555_000; // 约555k

reg [19:0] move_cnt;        // 计数器，用于生成60px/s节拍
reg        move_en;         // 每555k周期产生1个脉冲（即每帧移动1像素）

always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        move_cnt <= 20'd0;
        move_en  <= 1'b0;
    end else begin
        if (move_cnt == MOVE_CNT_MAX - 1) begin
            move_cnt <= 20'd0;
            move_en  <= 1'b1;
        end else begin
            move_cnt <= move_cnt + 1'b1;
            move_en  <= 1'b0;
        end
    end
end

// 动态图像位置寄存器
reg [10:0] img_x, img_y;
reg        x_dir, y_dir; // 方向寄存器：0表示正向/右/下，1表示负向/左/上

// 初始化及运动控制
always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        img_x <= POS_X_BASE;
        img_y <= POS_Y_BASE;
        x_dir <= 1'b0; // 初始向右
        y_dir <= 1'b0; // 初始向下
    end else if (B0) begin
        // B0=1：重置为初始坐标
        img_x <= POS_X_BASE;
        img_y <= POS_Y_BASE;
        x_dir <= 1'b0;
        y_dir <= 1'b0;
    end else if (move_en) begin
        // B1 控制水平左右移动，遇边界反弹（B3=1 时禁用水平移动）
        if (B1 && ~B3) begin
            if(x_dir == 1'b0) begin // 当前向右
                if(img_x >= (H_DISP - WIDTH)) begin // 到右边界，反弹向左
                    x_dir <= 1'b1;
                    img_x <= img_x - 1;
                end else begin
                    img_x <= img_x + 1;
                end
            end else begin // 当前向左
                if(img_x == 0) begin // 到左边界，反弹向右
                    x_dir <= 1'b0;
                    img_x <= img_x + 1;
                end else begin
                    img_x <= img_x - 1;
                end
            end
        end
        // B1=0 或 B3=1：X坐标保持不动

        // B2 控制垂直上下移动，遇边界反弹（B4=1 时禁用垂直移动）
        if (B2 && ~B4) begin
            if(y_dir == 1'b0) begin // 当前向下
                if(img_y >= (V_DISP - HEIGHT)) begin // 到下边界，反弹向上
                    y_dir <= 1'b1;
                    img_y <= img_y - 1;
                end else begin
                    img_y <= img_y + 1;
                end
            end else begin // 当前向上
                if(img_y == 0) begin // 到上边界，反弹向下
                    y_dir <= 1'b0;
                    img_y <= img_y + 1;
                end else begin
                    img_y <= img_y - 1;
                end
            end
        end
        // B2=0 或 B4=1：Y坐标保持不动
    end
    // move_en=0：所有坐标保持不变
end

// === 显示模式选择 (A0/A1/A2按键切换) ===
// A0=1 → 原图  |  A1=1 → 二值化  |  A2=1 → 边缘检测  |  默认→原图
reg [1:0] display_mode;  // 00=原图, 01=二值化, 10=边缘检测

// 按键边沿检测
reg A0_dly, A1_dly, A2_dly;
wire A0_pos, A1_pos, A2_pos;

always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        A0_dly <= 1'b0;
        A1_dly <= 1'b0;
        A2_dly <= 1'b0;
    end else begin
        A0_dly <= A0;
        A1_dly <= A1;
        A2_dly <= A2;
    end
end

assign A0_pos = A0 & ~A0_dly;  // A0 上升沿
assign A1_pos = A1 & ~A1_dly;  // A1 上升沿
assign A2_pos = A2 & ~A2_dly;  // A2 上升沿

// 模式切换：按 A0 原图，按 A1 二值化，按 A2 边缘检测
always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        display_mode <= 2'b00;  // 默认原图
    else if (A2_pos)
        display_mode <= 2'b10;  // 边缘检测模式
    else if (A1_pos)
        display_mode <= 2'b01;  // 二值化模式
    else if (A0_pos)
        display_mode <= 2'b00;  // 原图模式
end

// 运动模式编码：{B2, B1}
// 00=静止, 01=左右移动, 10=上下移动, 11=对角移动
wire [1:0] motion_mode;
assign motion_mode = {B2, B1};

// 拉伸模式：00=无, 01=左右拉伸(B3), 10=上下拉伸(B4)
wire [1:0] stretch_mode;
assign stretch_mode = {B4, B3};

wire rom_rd_en;//读ROM使能信号
reg [14:0] rom_addr;//读ROM地址
reg rom_valid;//读ROM数据有效信号

wire [23:0] rom_data;        //ROM输出数据
wire [23:0] sobel_data;      //Sobel边缘检测输出
wire [23:0] binary_data;     //二值化输出
wire [23:0] display_pixel;   //当前有效显示像素
wire [23:0] pixel_data_mux;  //Sobel/二值化/原图 多路选择输出

// ROM输出（原始图像数据）或白色背景
assign display_pixel = rom_valid ? rom_data : WHITE;

// 根据显示模式选择输出：A2边缘检测 / A1二值化 / A0原图
assign pixel_data_mux = (display_mode == 2'b10) ? sobel_data :
                        (display_mode == 2'b01) ? binary_data :
                        display_pixel;

//当前像素点坐标位于图案显示区域内，ROM使能信号拉高
// 拉伸模式下区域扩展到全屏
wire in_image_area = (B3 ? (pixel_xpos < H_DISP) : ((pixel_xpos >= img_x) && (pixel_xpos < img_x + WIDTH)))
                   && (B4 ? (pixel_ypos < V_DISP) : ((pixel_ypos >= img_y) && (pixel_ypos < img_y + HEIGHT)));

// 存储上一行的图像位置，用于检测图像位置是否发生变化
reg [10:0] prev_img_x, prev_img_y;
reg image_pos_changed;

always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        prev_img_x <= POS_X_BASE;
        prev_img_y <= POS_Y_BASE;
        image_pos_changed <= 1'b0;
    end else begin
        prev_img_x <= img_x;
        prev_img_y <= img_y;
        // 检测图像位置是否发生变化
        image_pos_changed <= (img_x != prev_img_x) || (img_y != prev_img_y);
    end
end

//控制读地址 - 关键修改：当图像位置改变时重置地址
always @(posedge lcd_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        rom_addr <= 15'd0;
    end
    else if(image_pos_changed) begin
        // 当图像位置发生变化时，重置地址为0
        rom_addr <= 15'd0;
    end
    else if(in_image_area) begin
        // 在图像区域内时，计算相对于图像左上角的地址
        // 地址 = (当前y - 图像y) * WIDTH + (当前x - 图像x)
        reg [14:0] current_addr;
        reg [14:0] rom_x, rom_y;
        
        // 拉伸模式下对坐标进行缩放映射
        // B3=1(左右拉伸): X = pixel_xpos * WIDTH / H_DISP = pixel_xpos / 5
        // B4=1(上下拉伸): Y = pixel_ypos * HEIGHT / V_DISP = pixel_ypos / 3
        if (B3)
            rom_x = pixel_xpos / 5;  // 160/800 = 1/5
        else
            rom_x = pixel_xpos - img_x;
            
        if (B4)
            rom_y = pixel_ypos / 3;  // 160/480 = 1/3
        else
            rom_y = pixel_ypos - img_y;
            
        current_addr = rom_y * WIDTH + rom_x;
        
        // 如果当前地址与rom_addr不一致（比如刚进入图像区域），则更新
        if(rom_addr != current_addr) begin
            rom_addr <= current_addr;
        end
        // 否则保持当前地址（等待下一个像素）
    end
    else begin
        rom_addr <= 15'd0; // 不在图像区域内时重置地址
    end
end
   
//从发出读使能信号到ROM输出有效数据存在一个时钟周期的延时
always @(posedge lcd_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        rom_valid <= 1'b0;
    else
        rom_valid <= in_image_area;
end

// ROM使能信号
assign rom_rd_en = in_image_area;
    
//通过调用IP核来例化ROM
pic_rom pic_rom_inst(
    .clock (lcd_clk),
    .address (rom_addr),
    .rden (rom_rd_en),
    .q (rom_data)

);

// ============================================================================
// Sobel 边缘检测模块例化
// ============================================================================
lcd_sobel u_lcd_sobel(
    .lcd_clk        (lcd_clk),
    .sys_rst_n      (sys_rst_n),
    .pixel_xpos     (pixel_xpos),
    .pixel_ypos     (pixel_ypos),
    .pixel_data_in  (display_pixel),
    .pixel_data_out (sobel_data)
);

// ============================================================================
// 二值化模块例化
// ============================================================================
lcd_binary u_lcd_binary(
    .lcd_clk        (lcd_clk),
    .sys_rst_n      (sys_rst_n),
    .pixel_data_in  (display_pixel),
    .pixel_data_out (binary_data)
);

// ============================================================================
// 文字叠加模块例化
// 在屏幕右上角显示当前模式文字
// ============================================================================
lcd_text_overlay u_lcd_text_overlay(
    .lcd_clk        (lcd_clk),
    .sys_rst_n      (sys_rst_n),
    .motion_mode    (motion_mode),
    .stretch_mode   (stretch_mode),
    .display_mode   (display_mode),
    .pixel_xpos     (pixel_xpos),
    .pixel_ypos     (pixel_ypos),
    .pixel_data_in  (pixel_data_mux),
    .pixel_data_out (pixel_data)
);

endmodule