const std = @import("std");
const rl = @import("raylib");

const instructions = @import("instructions.zig");

pub fn main() anyerror!void {
    std.debug.print("{d}\n", .{instructions.instruction_set.len});
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