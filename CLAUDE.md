# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Intel/Altera Quartus FPGA project (Cyclone IV E — EP4CE40U19A7) that drives an 800×480 RGB LCD panel, displaying a 140×170 image from on-chip ROM with hardware-switch-controlled motion modes. Written in Verilog, originally created in Quartus II 13.1, later opened in Quartus Prime 18.1 Lite.

## Build / Tool Commands

- **Open project**: `quartus lcd_rom_pic.qpf` (or `quartus_map lcd_rom_pic` for command-line flow)
- **Full compilation**: `quartus_sh --flow compile lcd_rom_pic`
- **Synthesis only**: `quartus_map lcd_rom_pic`
- **Place & route**: `quartus_fit lcd_rom_pic`
- **Generate programming file**: `quartus_asm lcd_rom_pic`
- **Simulation (ModelSim-Altera)**: The project is configured for ModelSim-Altera (Verilog). Netlist output is in `simulation/modelsim/`. Use the `.vo` (gate-level) files and `.sdo` (SDF timing) files there.

## Architecture

### Module Hierarchy (top-down)

```
lcd_rom_pic (top)
├── lcd_pll          — ALTPLL IP: sys_clk → lcd_clk (~33.3 MHz). Holds reset until `locked` asserts.
├── lcd_driver       — Generates LCD timing: H/V sync, DE, and streaming pixel (x,y) coordinates.
└── lcd_display      — Image display logic: reads ROM, maps pixels, handles motion control.
    └── pic_rom      — altsyncram ROM IP (1-port, 32768×24-bit), initialized from CrazyBird.mif.
```

### Signal Flow

1. `sys_clk` (external) → PLL → `lcd_clk_w` (drives everything downstream)
2. `sys_rst_n` AND `locked` → `rst_n_w` (global reset, released only after PLL locks)
3. `lcd_driver` generates pixel coordinates `(pixel_xpos, pixel_ypos)` streaming across the 800×480 frame
4. `lcd_display` determines if each coordinate falls inside the movable image region, computes the ROM address, and returns `pixel_data` (RGB888) or white background
5. `lcd_driver` gates `pixel_data` onto `lcd_rgb` only when `lcd_de` is asserted

### Motion Control (lcd_display.v)

Four switch inputs select the mode (priority: B3 > B2 > B1 > B0, one-hot expected):

| Switch | Mode |
|--------|------|
| B0 (0001) | Static display at base position (230, 150) |
| B1 (0010) | Vertical oscillation over 130px range |
| B2 (0100) | Horizontal movement with boundary bounce |
| B3 (1000) | Diagonal 45° upper-left movement, wraps around screen edges |
| default | Static |

Movement speed is timer-driven: a counter divides the 33.3 MHz pixel clock down to 60 Hz (555,000 cycles per step).

### Key Parameters

- **Display**: 800×480, timing params in `lcd_driver.v` (H: 46/0/800/210/1056, V: 23/0/480/22/525)
- **Image**: 140×170, stored as RGB888 (24-bit) in ROM at 32768 addresses (15-bit address bus)
- **Default position**: (230, 150)
- **ROM init file**: `CrazyBird.mif` — the active image. Alternatives: `miqi.mif`, `miqi1.mif`, `picture1.mif`

### IP Cores

- **lcd_pll** (ALTPLL): Wizard-generated, instantiated by `lcd_pll.v`. Configured via `lcd_pll.qip` and `lcd_pll.ppf`. Has a corresponding black-box stub `lcd_pll_bb.v`.
- **pic_rom** (ROM: 1-PORT): Wizard-generated, instantiated by `pic_rom.v`. References `CrazyBird.mif` as init file. Black-box stub at `pic_rom_bb.v`.

Both IP cores are wizard-generated — do not hand-edit the `.v` or `_bb.v` files. To change ROM content, swap the `.mif` filename in the ROM IP parameters (via the MegaWizard or by editing `pic_rom.v`'s `init_file` defparam and the `.qip`). To change the PLL output frequency, use the ALTPLL MegaWizard.

### Pin Assignments

All pin locations are in `lcd_rom_pic.qsf`. The 24-bit LCD RGB bus is split across two banks (16-bit + 8-bit), switches B0–B3 on pins A16, B16, A15, B15.

### Revisions

The project has two revisions: `lcd_rom_pic` (current, RGB888 24-bit) and `vga_rom_pic` (historical, RGB565 16-bit). The `.txt` files (`lcd_rom_pic.txt`, `lcd_driver.txt`, `lcd_display.txt`) are earlier design snapshots — the active sources are the `.v` files.
