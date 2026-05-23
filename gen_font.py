"""
生成汉字48x48点阵字模 Verilog 文件
字体: 微软雅黑, 字号 48
输出: font_rom.v — 包含所有需要汉字的点阵数据
"""
from PIL import ImageFont, ImageDraw, Image
import os

# 需要显示的汉字（去重）
chars = "静态显示左右移动上下对角原图边缘检测拉伸"
FONT_SIZE = 48
CHAR_W = FONT_SIZE
CHAR_H = FONT_SIZE

# 微软雅黑
font_path = "C:/Windows/Fonts/msyh.ttc"
if not os.path.exists(font_path):
    for fp in [
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/msyhbd.ttc",
    ]:
        if os.path.exists(fp):
            font_path = fp
            break

print(f"Using font: {font_path}")
print(f"Font size: {FONT_SIZE}")

# 加载字体
font = ImageFont.truetype(font_path, FONT_SIZE)

# 为每个字符生成点阵数据
char_data = {}

for ch in chars:
    margin = 4
    tmp_size = FONT_SIZE + margin * 2
    img = Image.new('1', (tmp_size, tmp_size), 0)  # 黑色背景
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), ch, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = margin + (FONT_SIZE - tw) // 2 - bbox[0]
    y = margin + (FONT_SIZE - th) // 2 - bbox[1]
    draw.text((x, y), ch, font=font, fill=1)  # 白色前景

    # 裁剪回标准大小
    img = img.crop((margin, margin, margin + FONT_SIZE, margin + FONT_SIZE))

    pixels = []
    for row in range(CHAR_H):
        val = 0
        for col in range(CHAR_W):
            if img.getpixel((col, row)):
                val |= (1 << (CHAR_W - 1 - col))
        pixels.append(val)
    char_data[ch] = pixels

# 生成 Verilog 文件
def gen_verilog():
    lines = []
    lines.append("// ============================================================")
    lines.append("// font_rom.v — 汉字48x48点阵字模自动生成")
    lines.append("// 生成自: gen_font.py")
    lines.append(f"// 字体: {os.path.basename(font_path)}, 字号: {FONT_SIZE}")
    lines.append(f"// 字符集: {chars}")
    lines.append("// ============================================================")
    lines.append("")
    lines.append("module font_rom (")
    lines.append("    input             clk,")
    lines.append("    input      [4:0]  char_addr,   // 字符索引 (0~16)")
    lines.append("    input      [5:0]  row_addr,    // 行地址 (0~47)")
    lines.append("    output reg [47:0] pixel_data   // 48bit 点阵数据")
    lines.append(");")
    lines.append("")
    lines.append("// 字符索引表")
    idx = 0
    for ch in sorted(set(chars)):
        lines.append(f"localparam CHAR_{ord(ch):04X} = 5'd{idx}; // '{ch}'")
        idx += 1
    lines.append("")

    lines.append("always @(posedge clk) begin")
    lines.append("    case ({char_addr, row_addr})")
    lines.append("        // {char_addr, row_addr} -> pixel_data")

    char_list = sorted(set(chars))
    for ch_idx, ch in enumerate(char_list):
        data = char_data[ch]
        for row in range(CHAR_H):
            addr = (ch_idx << 6) | row
            val = data[row]
            lines.append(f"        11'd{addr}: pixel_data <= 48'h{val:012X}; // '{ch}' row{row}")

    lines.append("        default: pixel_data <= 48'd0;")
    lines.append("    endcase")
    lines.append("end")
    lines.append("")
    lines.append("endmodule")

    return "\n".join(lines)

verilog_code = gen_verilog()

output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "font_rom.v")
with open(output_path, "w", encoding="utf-8") as f:
    f.write(verilog_code)

print(f"Generated: {output_path}")
print(f"Chars: {''.join(sorted(set(chars)))}")
# 打印缩略图预览
for ch in sorted(set(chars)):
    data = char_data[ch]
    print(f"\n  '{ch}' (48x48):")
    for row in range(0, CHAR_H, 3):
        line = ""
        for col in range(0, CHAR_W, 3):
            r = row + 1
            c = col + 1
            if r < CHAR_H and c < CHAR_W:
                line += "█" if (data[r] & (1 << (CHAR_W - 1 - c))) else " "
        print(f"    {line}")
    print(f"\n  '{ch}':")
    for row in range(16):
        line = ""
        for col in range(16):
            line += "█" if (data[row] & (1 << (15 - col))) else " "
        print(f"    {line}")
