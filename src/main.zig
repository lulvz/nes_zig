const std = @import("std");
const rl = @import("raylib");

const Bus = @import("bus.zig");
const CPU6502 = @import("cpu6502.zig");

pub fn main() anyerror!void {
    try run6502Test();
}

pub fn run6502Test() anyerror!void {
    // Initialize an empty bus and CPU, set the CPU's program counter (PC) to 0x0200.
    var bus = Bus.initTesting();
    try bus.loadTestROM("test_bin/6502_functional_test.bin");
    var cpu = CPU6502.init(&bus);
    cpu.pc = 0x0208;

    const screenWidth = 800;
    const screenHeight = 450;

    // Initialize Raylib window.
    rl.initWindow(screenWidth, screenHeight, "6502 Test Environment");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var step: bool = false; // Flag to track if we should step the CPU.
    var memoryViewStart: u16 = 0x0000; // Start address for memory view

    while (!rl.windowShouldClose()) { 
        // Update
        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            // Step the CPU by executing the next instruction when space is pressed.
            cpu.step();
            step = true; // Set the flag indicating a step was performed.
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_up) and memoryViewStart >= 16) {
            memoryViewStart -= 16;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_down) and memoryViewStart <= 0xFFF0) {
            memoryViewStart += 16;
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        // Display CPU state for debugging.
        rl.drawText("6502 CPU Test", 10, 10, 20, rl.Color.dark_gray);
        rl.drawText("Press SPACE to step through the next instruction.", 10, 40, 20, rl.Color.gray);
        
        // Display program counter (PC) and other registers (e.g., A, X, Y, status flags).
        const textSize = 20;
        const spacing = 25;
        rl.drawText("CPU Registers:", 10, 80, textSize, rl.Color.black);
        rl.drawText("PC: ", 10, 80 + spacing * 1, textSize, rl.Color.black);
        rl.drawText(rl.textFormat("0x%04x", .{cpu.pc}), 100, 80 + spacing * 1, textSize, rl.Color.black);
        rl.drawText("acc: ", 10, 80 + spacing * 2, textSize, rl.Color.black);
        rl.drawText(rl.textFormat("0x%04x", .{cpu.acc}), 100, 80 + spacing * 2, textSize, rl.Color.black);
        rl.drawText("X: ", 10, 80 + spacing * 3, textSize, rl.Color.black);
        rl.drawText(rl.textFormat("0x%04x", .{cpu.X}), 100, 80 + spacing * 3, textSize, rl.Color.black);
        rl.drawText("Y: ", 10, 80 + spacing * 4, textSize, rl.Color.black);
        rl.drawText(rl.textFormat("0x%04x", .{cpu.Y}), 100, 80 + spacing * 4, textSize, rl.Color.black);
        // rl.drawText("Status: ", 10, 80 + spacing * 5, textSize, rl.Color.black);
        // rl.drawText(std.fmt.format("{b}", cpu.status), 100, 80 + spacing * 5, textSize, rl.Color.black);

        rl.drawText("Memory:", 10, 220, textSize, rl.Color.black);
        var y: i32 = 250;
        var addr: u16 = memoryViewStart;
        while (y < screenHeight - 30 and addr < 0x10000) : (y += spacing) {
            const addrText = rl.textFormat("0x%04X:", .{addr});
            rl.drawText(addrText, 10, y, textSize, rl.Color.black);

            var x: i32 = 100;
            for (0..8) |i| {
                if (addr + i < 0x10000) {
                    const byteText = rl.textFormat("%02X", .{bus.readByte(addr + @as(u16, @intCast(i)))});
                    rl.drawText(byteText, x, y, textSize, rl.Color.black);
                    x += 30;
                }
            }
            addr += 8;
        }

        if (step) {
            rl.drawText("Stepped!", screenWidth - 120, screenHeight - 40, textSize, rl.Color.green);
            step = false;
        }

        if (step) {
            rl.drawText("Stepped!", screenWidth - 120, screenHeight - 40, textSize, rl.Color.green);

            // update the value of the registers to display
            step = false; // Reset step flag after drawing.
        }
    }
}


pub fn runWindow() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    // load shader
    // const fragShader: rl.Shader = rl.loadShader(0, "../resources/shaders/display.frag");

    // Set the frag shader value for the texture
    // SetShaderValueTexture

    rl.setTargetFPS(60);

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------


        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);



        //----------------------------------------------------------------------------------
    }
}
