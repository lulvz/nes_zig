const std = @import("std");
const rl = @import("raylib");

const Bus = @import("bus.zig");
const PPUBus = @import("ppu_bus.zig");
const CPU6502 = @import("cpu6502.zig");
const PPU = @import("ppu.zig");
const APU = @import("apu.zig");
const Cartridge = @import("cartridge.zig");

const WINDOW_WIDTH = 1200;
const WINDOW_HEIGHT = 900;
const NES_WIDTH = 256;
const NES_HEIGHT = 240;
const DEBUG_PANEL_WIDTH = 430;
const GAME_SCALE = 3;

const FG_COLOR = rl.Color.ray_white;
const FG_ACCENT_COLOR = rl.Color.beige;
const BG_COLOR = rl.Color.dark_gray;

pub fn main() anyerror!void {
    try run6502Test();
}

fn run6502Test() anyerror!void {
    var cpu: CPU6502 = undefined;
    var ppu: PPU = undefined;
    var apu: APU = undefined;
    var cartridge: Cartridge = undefined;
    var ppu_bus = try PPUBus.init(&cartridge);
    var bus = Bus.init(&cpu, &ppu, &apu, &cartridge);

    cpu = CPU6502.init(&bus);
    ppu = PPU.init(&bus, &ppu_bus); 

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator(); 
    cartridge = try Cartridge.init("test_bin/nestest.nes", allocator);
    defer cartridge.deinit();
    cartridge.printHeader();

    // cpu.customReset(0xC000);
    cpu.reset();
    try initAndRunWindow(&cpu, &bus, &ppu);
}

fn initAndRunWindow(cpu: *CPU6502, bus: *Bus, ppu: *PPU) !void {
    const log = try std.fs.cwd().createFile("execution_log.log", .{});
    const log_writer = log.writer();
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "NES Emulator");
    defer rl.closeWindow();
    
    rl.setTargetFPS(0);
    var memoryViewStart: u16 = 0x0000;
    const target = rl.loadRenderTexture(NES_WIDTH, NES_HEIGHT);
    defer rl.unloadRenderTexture(target);

    while (!rl.windowShouldClose()) { 
        try cpu.logCpuState(log_writer);
        while (!ppu.frame_finished) {
            bus.clock();
        }
        ppu.frame_finished = false;
        handleInput(&memoryViewStart);
        updateGameScreen(target, ppu);
        drawFrame(cpu, bus, memoryViewStart, target);
    }
}

fn handleInput(memoryViewStart: *u16) void {
    if (rl.isKeyDown(rl.KeyboardKey.key_up) and memoryViewStart.* >= 16) {
        memoryViewStart.* -= 16;
    }
    if (rl.isKeyDown(rl.KeyboardKey.key_down) and memoryViewStart.* <= 0xFFF0) {
        memoryViewStart.* += 16;
    }
}

fn updateGameScreen(target: rl.RenderTexture2D, ppu: *PPU) void {
    rl.beginTextureMode(target);
    defer rl.endTextureMode();

    for (0..NES_HEIGHT) |y| {
        for (0..NES_WIDTH) |x| {
            const color = ppu.frame_buffer[y * NES_WIDTH + x];
            rl.drawPixel(@intCast(x), @intCast(y), rl.Color{ .r = @truncate(color >> 24), .g = @truncate(color >> 16), .b = @truncate(color >> 8), .a = @truncate(color) });
        }
    }
}

fn drawFrame(cpu: *CPU6502, bus: *Bus, memoryViewStart: u16, target: rl.RenderTexture2D) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(BG_COLOR);
    const scaledWidth = NES_WIDTH * GAME_SCALE;
    const scaledHeight = NES_HEIGHT * GAME_SCALE;
    const sourceRec = rl.Rectangle{ .x = 0, .y = 0, .width = @as(f32, NES_WIDTH), .height = -@as(f32, NES_HEIGHT) };
    const destRec = rl.Rectangle{ .x = 0, .y = 0, .width = @as(f32, scaledWidth), .height = @as(f32, scaledHeight) };
    
    rl.drawTexturePro(target.texture, sourceRec, destRec, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
    rl.drawText("NES Screen", 10, NES_HEIGHT * GAME_SCALE + 10, 20, FG_ACCENT_COLOR);
    
    drawDebugPanel(cpu, bus, memoryViewStart);
}

fn drawDebugPanel(cpu: *CPU6502, bus: *Bus, memoryViewStart: u16) void {
    const debugPanelX = WINDOW_WIDTH - DEBUG_PANEL_WIDTH;
    rl.drawLine(debugPanelX, 0, debugPanelX, WINDOW_HEIGHT, FG_ACCENT_COLOR);
    
    drawInstructions(debugPanelX);
    drawCPUState(cpu, debugPanelX);
    drawMemoryView(bus, memoryViewStart, debugPanelX);
}

fn drawInstructions(baseX: i32) void {
    rl.drawText("NES Emulator Debug", baseX + 10, 10, 20, rl.Color.dark_gray);
    rl.drawText("SPACE: Step | UP/DOWN: Scroll Memory", baseX + 10, 40, 20, FG_ACCENT_COLOR);
}

fn drawCPUState(cpu: *CPU6502, baseX: i32) void {
    const textSize = 20;
    const spacing = 25;
    const x = baseX + 10;
    const baseY = 80;

    rl.drawText("CPU Registers:", x, baseY, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("PC: 0x%04x", .{cpu.pc}), x, baseY + spacing * 1, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("A:  0x%02x", .{cpu.acc}), x, baseY + spacing * 2, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("X:  0x%02x", .{cpu.X}), x, baseY + spacing * 3, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("Y:  0x%02x", .{cpu.Y}), x, baseY + spacing * 4, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("P: nvxbdizc", .{}), x, baseY + spacing * 5, textSize, FG_COLOR);
    rl.drawText(rl.textFormat("   %08b", .{@as(u8, @bitCast(cpu.P))}), x, baseY + spacing * 6, textSize, FG_COLOR);
}

fn drawMemoryView(bus: *Bus, memoryViewStart: u16, baseX: i32) void {
    const textSize = 20;
    const spacing = 25;
    const x = baseX + 10;
    const baseY = 250;

    rl.drawText("Memory:", x, baseY, textSize, FG_COLOR);
    var y: i32 = baseY + 30;
    var addr: u16 = memoryViewStart;

    while (y < WINDOW_HEIGHT - 30 and addr < 0x10000) : (y += spacing) {
        const addrText = rl.textFormat("0x%04X:", .{addr});
        rl.drawText(addrText, x, y, textSize, FG_COLOR);

        var byteX: i32 = x + 90;
        for (0..8) |i| {
            if (addr + i < 0x10000) {
                const byteText = rl.textFormat("%02X", .{bus.readByte(addr + @as(u16, @intCast(i)))});
                rl.drawText(byteText, byteX, y, textSize, FG_COLOR);
                byteX += 30;
            }
        }
        addr += 8;
    }
}
