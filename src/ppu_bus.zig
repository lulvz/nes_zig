const std = @import("std");
const Cartridge = @import("cartridge.zig");
const PPU = @import("ppu.zig");

const PPUBus = @This();

cartridge: *Cartridge,

vram: [1024*2]u8,

// ppu frame palette is 8 groups of colors, 4 colors each, so 32 slots need to exist in the frame palette
palettes: [32]u8,
// ppu system palette holds 64 different colors, that are referenced by the ppu frame palette
system_palette: [64]u32,

pub fn init(cartridge: *Cartridge) !PPUBus {
    var ppubus = PPUBus {
        .cartridge = cartridge,
        .vram = std.mem.zeroes([1024*2]u8),
        .palettes = std.mem.zeroes([32]u8),
        .system_palette = std.mem.zeroes([64]u32),
    };
    try ppubus.loadPaletteFile("palettes/NES_classig_fbx.pal");
    return ppubus;
}

fn calculateMirroredAddress(self: *PPUBus, addr: u14) u14 {
    const vram_addr = addr & 0x0FFF;
    const nametable_index = vram_addr / 0x400;
    const mirroring_type = self.cartridge.header.flags6.nametable_arrangement;

    var calculated_address: u14 = 0;
    switch(mirroring_type) {
        0 => { // Horizontal
            calculated_address = switch(nametable_index) {
                0 => vram_addr, // (A)
                1 => vram_addr-0x400, // (a) we subtract to simulate a mirror of A
                2 => vram_addr-0x400, // (B) we subtract only 0x400 because index 2 will be B
                3 => vram_addr-0x800, // (b) we subtract 0x800 to simulate the mirror of B
                else => vram_addr,
            };
        },
        1 => { // Vertical
            calculated_address = switch(nametable_index) {
                0 => vram_addr, // (A)
                1 => vram_addr, // (B)
                2 => vram_addr - 0x800, // (a)
                3 => vram_addr - 0x800, // (b)
                else => vram_addr,
            };
        },
    }

    return calculated_address;
}

// by receiving a u14, we emulate the mirroring that happens from 0x3fff to 0xffff
pub fn ppuReadByte(self: *PPUBus, addr: u14) u8 {
    switch (addr) {
        0x0000...0x1FFF => return self.cartridge.ppuReadByte(addr),
        0x2000...0x2FFF => return self.vram[self.calculateMirroredAddress(addr)],
        0x3000...0x3EFF => return 0x00, // unused
        0x3F00...0x3FFF => {
            const wrapped_address = addr & 0x001F; // address mirroring
            return switch (wrapped_address) { // these addresses are mirrors of the background palette indexes
                0x0010, 0x0014, 0x0018, 0x001C => self.palettes[wrapped_address - 0x0010],
                else => self.palettes[wrapped_address],
            };
        },
    }
}

pub fn ppuWriteByte(self: *PPUBus, addr: u14, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.cartridge.ppuWriteByte(addr, value),
        0x2000...0x2FFF => self.vram[self.calculateMirroredAddress(addr)] = value,
        0x3000...0x3EFF => return, // unused
        0x3F00...0x3FFF => {
            const wrapped_address = addr & 0x001F; // address mirroring
            return switch (wrapped_address) { // these addresses are mirrors of the background palette indexes
                0x0010, 0x0014, 0x0018, 0x001C => self.palettes[wrapped_address - 0x0010] = value,
                else => self.palettes[wrapped_address] = value,
            };
        },
    }
}

// TODO make this function better and make a palette struct
// this loads the system palette, which has 64 colors, the frame palette, that is stored
// in the ppu (in this case in the ppu_bus) will then refernece the colors loaded
// from the pal file, using their index
// this function assumes the palette has 64 colors
pub fn loadPaletteFile(self: *PPUBus, filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size % 3 != 0) { // 64 colors, 3 bytes each for RGB
        return error.InvalidPaletteFile; // TODO make this check if the palette file is 192 bytes instead maybe
    }

    const num_colors = @divExact(file_size, 3);
    std.debug.print("num_colors: {d}\n", .{num_colors});
    // var system_palette: [64]u32 = std.mem.zeroes([64]u32);

    var buffer: [3]u8 = undefined;
    var i: usize = 0;
    while (i < num_colors) : (i += 1) {
        _ = try file.read(&buffer);
        self.system_palette[i] = 0x000000FF | (@as(u32, buffer[0]) << 24) | (@as(u32, buffer[1]) << 16) | (@as(u32, buffer[2]) << 8);
    }
}
