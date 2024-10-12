const std = @import("std");
const Cartridge = @This();

header: Header,
mapper_id: u8,

PrgROM: []u8,
ChrROM: []u8,

// Least to most significant bit
const Flags6 = packed struct {
    nametable_arrangement: u1,    // Bit 0: Mirroring (0: Horizontal, 1: Vertical)
    battery_backed_prg_ram: u1,   // Bit 1: Battery-backed PRG RAM
    trainer: u1,                  // Bit 2: 512-byte Trainer (0: No, 1: Yes)
    four_screen_mirroring: u1,    // Bit 3: Four-screen mirroring (0: No, 1: Yes)
    lower_mapper_bits: u4,
};
const Flags7 = packed struct {
    console_type: u2,             // Bits 0-1: Console type (0: NES, 1: Vs. System, 2: PlayChoice-10)
    ines2_format: u1,             // Bit 2: NES 2.0 format (0: iNES, 1: NES 2.0)
    upper_mapper_bits: u4,
    unused: u1,
};
const Flags8 = packed struct {
    prg_ram_size: u8,             // Byte 8: PRG RAM size in 8KB units (if 0, assume 8KB)
};
const Flags9 = packed struct {
    tv_system: u1,                // Bit 0: TV system (0: NTSC, 1: PAL)
    unused: u7,
};
const Flags10 = packed struct {
    tv_system: u2,                // Bits 0-1: TV system (0: NTSC, 2: PAL, 3: Dual Compatible)
    prg_ram_bus_conflict: u1,     // Bit 2: PRG RAM bus conflict (0: No, 1: Yes)
    unused: u5,
};
const Header = packed struct {
    magic0: u8,
    magic1: u8,
    magic2: u8,
    magic3: u8,
    prg_rom_size: u8,             // PRG ROM size in 16KB units
    chr_rom_size: u8,             // CHR ROM size in 8KB units
    flags6: Flags6,               // Flags 6 (mirroring, mapper lower bits, etc.)
    flags7: Flags7,               // Flags 7 (mapper upper bits, console type, etc.)
    flags8: Flags8,               // Flags 8 (PRG RAM size)
    flags9: Flags9,               // Flags 9 (TV system)
    flags10: Flags10,             // Flags 10 (TV system, PRG RAM bus conflict)
    padding11: u8,
    padding12: u8,
    padding13: u8,
    padding14: u8,
    padding15: u8,
};

pub fn init(rom_path: []const u8, allocator: std.mem.Allocator) !Cartridge {
    const file = try std.fs.cwd().openFile(rom_path, .{}); 
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    const header: Header = .{
        .magic0 = buffer[0],
        .magic1 = buffer[1],
        .magic2 = buffer[2],
        .magic3 = buffer[3],
        .prg_rom_size = buffer[4],
        .chr_rom_size = buffer[5],
        .flags6 = @bitCast(buffer[6]),
        .flags7 = @bitCast(buffer[7]),
        .flags8 = @bitCast(buffer[8]),
        .flags9 = @bitCast(buffer[9]),
        .flags10 = @bitCast(buffer[10]),
        .padding11 = buffer[11],
        .padding12 = buffer[12],
        .padding13 = buffer[13],
        .padding14 = buffer[14],
        .padding15 = buffer[15],
    };
    const mapper_id: u8 = (@as(u8, header.flags7.upper_mapper_bits) << 4) | header.flags6.lower_mapper_bits;
    const PrgROM = try allocator.alloc(u8, @as(usize, header.prg_rom_size) * (1024*16));
    const ChrROM = try allocator.alloc(u8, @as(usize, header.chr_rom_size) * (1024*8));

    return .{
        .header = header,
        .mapper_id = mapper_id,
        .PrgROM = PrgROM,
        .ChrROM = ChrROM,
    };
}

pub fn deinit(self: *Cartridge, allocator: std.mem.Allocator) void {
    allocator.free(self.PrgROM);
    allocator.free(self.ChrROM);
}

pub fn readByte(_: *Cartridge, _: u16) u8 {
    return 0x00;
}

pub fn writeByte(_: *Cartridge, _: u16, _: u8) void {
    return;
}




pub fn printHeader(self: *Cartridge) void {
    const header = self.header;
    std.debug.print("Header:\n", .{});
    std.debug.print("Magic: {x},{x},{x},{x}\n", .{header.magic0, header.magic1, header.magic2, header.magic3});
    std.debug.print("PRG ROM Size: {d} KB\n", .{header.prg_rom_size * 16});
    std.debug.print("CHR ROM Size: {d} KB\n", .{header.chr_rom_size * 8});
    std.debug.print("Flags6:\n", .{});
    std.debug.print("  Nametable Arrangement: {d}\n", .{header.flags6.nametable_arrangement});
    std.debug.print("  Battery-backed PRG RAM: {d}\n", .{header.flags6.battery_backed_prg_ram});
    std.debug.print("  Trainer: {d}\n", .{header.flags6.trainer});
    std.debug.print("  Four-screen Mirroring: {d}\n", .{header.flags6.four_screen_mirroring});
    std.debug.print("  Lower Mapper Bits: {d}\n", .{header.flags6.lower_mapper_bits});
    std.debug.print("Flags7:\n", .{});
    std.debug.print("  Console Type: {d}\n", .{header.flags7.console_type});
    std.debug.print("  NES 2.0 Format: {d}\n", .{header.flags7.ines2_format});
    std.debug.print("  Upper Mapper Bits: {d}\n", .{header.flags7.upper_mapper_bits});
    std.debug.print("Flags8 - PRG RAM Size: {d} KB\n", .{header.flags8.prg_ram_size});
    std.debug.print("Flags9 - TV System: {d}\n", .{header.flags9.tv_system});
    std.debug.print("Flags10:\n", .{});
    std.debug.print("  TV System: {d}\n", .{header.flags10.tv_system});
    std.debug.print("  PRG RAM Bus Conflict: {d}\n", .{header.flags10.prg_ram_bus_conflict});
    std.debug.print("Padding: {x},{x},{x},{x},{x}\n", .{header.padding11,header.padding12,header.padding13,header.padding14,header.padding15});
}
