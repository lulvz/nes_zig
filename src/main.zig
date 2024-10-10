const std = @import("std");
const rl = @import("raylib");

const Bus = @import("bus.zig");
const CPU6502 = @import("cpu6502.zig");

pub fn main() anyerror!void {
    var bus = Bus.init();
    var cpu = CPU6502.init(&bus);
    cpu.acc = 0x50;
    cpu.P.c_carry = 0;
    
    // Write the instruction and operand to memory
    bus.writeByte(0x0000, 0x69); // ADC Immediate opcode
    bus.writeByte(0x0001, 0x10); // Operand
    
    // Execute one instruction
    cpu.pc = 0x0000;

    cpu.step();
    std.debug.print("{x}\n", .{cpu.acc});

    // try runWindow();
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