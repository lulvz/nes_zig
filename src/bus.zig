const std = @import("std");

const APU = @import("apu.zig");
const PPU = @import("ppu.zig");
const Cartridge = @import("cartridge.zig");

const Bus = @This();

// ram Memory is 2KB for the NES ($0000–$07FF) Stack is at ($0100-$01FF)
ram: [1024*2]u8,
PPU: *PPU,
APU: *APU,
cartridge: *Cartridge,

// PPU Registers are 8 bytes ($2000–$2007)
// PPU_reg: [8]u8,
// APU and I/O registers and APU and I/O functionality that is normally disabled
// ($4000-$401F)
// APU_reg: [32]u8,
// Unmapped, reserved for cartridge ($4020-$FFFF)
// CART: [49_120]u8,

pub fn init() Bus {
    const bus: Bus = .{
        .ram = std.mem.zeroes([1024*2]u8),
        .PPU = undefined,
        .APU = undefined,
        .cartridge = undefined,
    };

    return bus;
}

pub fn readByte(self: *Bus, addr: u16) u8 {
    return switch (addr) {
        0x0000...0x1FFF => self.ram[addr & 0x07FF],
        0x2000...0x3FFF => self.PPU.readRegister(addr & 0x0007),
        0x4000...0x401F => self.APU.readRegister(addr - 0x4000),// TODO FIX THESE VALUES
        0x4020...0xFFFF => self.cartridge.readByte(addr),
    };
}

pub fn writeByte(self: *Bus, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
        0x2000...0x3FFF => self.PPU.writeRegister(addr & 0x0007, value),
        0x4000...0x401F => self.APU.writeRegister(addr - 0x4000, value),// TODO FIX THESE VALUES TOO
        0x4020...0xFFFF => self.cartridge.writeByte(addr, value),
    }
}

pub fn readWord(self: *Bus, addr: u16) u16 {
    const lo = self.readByte(addr);
    const hi = self.readByte(addr +% 1);
    return @as(u16, hi) << 8 | lo;
}

pub fn writeWord(self: *Bus, addr: u16, value: u16) void {
    self.writeByte(addr, @as(u8, @truncate(value)));
    self.writeByte(addr +% 1, @as(u8, @truncate(value >> 8)));
}
