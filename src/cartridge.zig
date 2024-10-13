const std = @import("std");
const Mapper = @import("mappers/mapper.zig").Mapper;
const NROM = @import("mappers/NROM.zig");
const Cartridge = @This();

header: Header,
mapper_id: u8,

PrgROM: []u8,
ChrROM: []u8,
mapper: Mapper,

allocator: std.mem.Allocator,

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
    prg_rom_units: u8,             // PRG ROM size in 16KB units
    chr_rom_units: u8,             // CHR ROM size in 8KB units
    flags6: Flags6,               // Flags 6 (mirroring, mapper lower bits, etc.)
    flags7: Flags7,               // Flags 7 (mapper upper bits, console type, etc.)
    prg_ram_size: u8,               // Flags 8 (PRG RAM size)
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

    const header: Header = @bitCast(buffer[0..@sizeOf(Header)].*);
    const mapper_id: u8 = (@as(u8, header.flags7.upper_mapper_bits) << 4) | header.flags6.lower_mapper_bits;

    var prg_start: usize = @sizeOf(Header);
    if(header.flags6.trainer == 1) { // if trainer flag is set, add 512 bytes to the prg_start
        prg_start += 512;
    }
    const prg_rom_size = @as(usize, header.prg_rom_units) * (1024*16);
    const chr_rom_size =  @as(usize, header.chr_rom_units) * (1024*8);
    if (file_size < prg_start + prg_rom_size + chr_rom_size) {
        return error.InvalidROMSize;
    }

    const PrgROM = try allocator.alloc(u8, prg_rom_size);
    errdefer allocator.free(PrgROM);
    const ChrROM = try allocator.alloc(u8, chr_rom_size);
    errdefer allocator.free(ChrROM);

    @memcpy(PrgROM, buffer[prg_start..prg_start+prg_rom_size]);
    @memcpy(ChrROM, buffer[prg_start+prg_rom_size..prg_start+prg_rom_size+chr_rom_size]);

    const mapper = switch(mapper_id) {
        0 => Mapper{.NROM = NROM{.PrgROM = PrgROM, .ChrROM = ChrROM, .prg_rom_units = header.prg_rom_units, .chr_rom_units = header.chr_rom_units}},
        else => {std.debug.print("Mapper not implemented: {d}\n", .{mapper_id}); return error.UnsupportedMapper;},
    };

    return .{
        .header = header,
        .mapper_id = mapper_id,
        .PrgROM = PrgROM,
        .ChrROM = ChrROM,
        .mapper = mapper,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Cartridge) void {
    self.allocator.free(self.PrgROM);
    self.allocator.free(self.ChrROM);
}

pub fn readByte(self: *Cartridge, addr: u16) u8 {
    return self.mapper.readByte(addr);
}

pub fn writeByte(self: *Cartridge, addr: u16, value: u8) void {
    self.mapper.writeByte(addr, value);
}

pub fn ppuReadByte(self: *Cartridge, addr: u14) u8 {
    return self.mapper.ppuReadByte(addr);
}

pub fn ppuWriteByte(self: *Cartridge, addr: u14, value: u8) void {
    self.mapper.ppuWriteByte(addr, value);
}

pub fn printHeader(self: *Cartridge) void {
    const header = self.header;
    std.debug.print("Header:\n", .{});
    std.debug.print("Magic: {x},{x},{x},{x}\n", .{header.magic0, header.magic1, header.magic2, header.magic3});
    std.debug.print("PRG ROM Size: {d} KB\n", .{header.prg_rom_units * 16});
    std.debug.print("CHR ROM Size: {d} KB\n", .{header.chr_rom_units * 8});
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
    std.debug.print("PRG RAM Size: {d} KB\n", .{header.prg_ram_size});
    std.debug.print("Flags9 - TV System: {d}\n", .{header.flags9.tv_system});
    std.debug.print("Flags10:\n", .{});
    std.debug.print("  TV System: {d}\n", .{header.flags10.tv_system});
    std.debug.print("  PRG RAM Bus Conflict: {d}\n", .{header.flags10.prg_ram_bus_conflict});
    std.debug.print("Padding: {x},{x},{x},{x},{x}\n", .{header.padding11,header.padding12,header.padding13,header.padding14,header.padding15});
}
