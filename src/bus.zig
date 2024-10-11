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

test_ram: [1024*64]u8,

read_fn: *const fn (self: *Bus, address: u16) u8,
write_fn: *const fn (self: *Bus, address: u16, value: u8) void,

pub fn init() Bus {
    const bus: Bus = .{
        .ram = std.mem.zeroes([1024*2]u8),
        .PPU = undefined,
        .APU = undefined,
        .cartridge = undefined,
        .test_ram = undefined,
        .read_fn = standardReadByte,
        .write_fn = standardWriteByte,
    };

    return bus;
}

pub fn initTesting() Bus {
    const bus: Bus = .{
        .ram = undefined,
        .PPU = undefined,
        .APU = undefined,
        .cartridge = undefined,
        .test_ram = std.mem.zeroes([1024*64]u8),
        .read_fn = testReadByte,
        .write_fn = testWriteByte,
    };

    return bus; 
}

pub fn loadTestROM(self: *Bus, file_location: []const u8) !void {
    var file = try std.fs.cwd().openFile(file_location, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    // Create a dynamic buffer based on the file size
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    defer std.heap.page_allocator.free(buffer);

    // Read the file into the buffer
    _ = try file.readAll(buffer);

    // Copy the contents to the test RAM (ensure test_ram has enough space)
    @memcpy(&self.test_ram, buffer);
}

fn standardReadByte(self: *Bus, addr: u16) u8 {
    return switch (addr) {
        0x0000...0x1FFF => self.ram[addr & 0x07FF],
        0x2000...0x3FFF => self.PPU.readRegister(addr & 0x0007),
        0x4000...0x401F => self.APU.readRegister(addr - 0x4000),// TODO FIX THESE VALUES
        0x4020...0xFFFF => self.cartridge.readByte(addr),
    };
}

fn testReadByte(self: *Bus, addr: u16) u8 {
    return self.test_ram[addr];
}

pub fn readByte(self: *Bus, addr: u16) u8 {
    return self.read_fn(self, addr);
}

fn standardWriteByte(self: *Bus, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
        0x2000...0x3FFF => self.PPU.writeRegister(addr & 0x0007, value),
        0x4000...0x401F => self.APU.writeRegister(addr - 0x4000, value),// TODO FIX THESE VALUES TOO
        0x4020...0xFFFF => self.cartridge.writeByte(addr, value),
    }
}

fn testWriteByte(self: *Bus, addr: u16, value: u8) void {
    self.test_ram[addr] = value;
}

pub fn writeByte(self: *Bus, addr: u16, value: u8) void {
    self.write_fn(self, addr, value);
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
