const std = @import("std");

const CPU6502 = @import("cpu6502.zig");
const PPU = @import("ppu.zig");
const APU = @import("apu.zig");
const Controller = @import("controller.zig");
const Cartridge = @import("cartridge.zig");

const Bus = @This();

// ram Memory is 2KB for the NES ($0000–$07FF) Stack is at ($0100-$01FF)
ram: [1024*2]u8,
cpu: *CPU6502,
ppu: *PPU,
apu: *APU,
controller: *Controller,
cartridge: *Cartridge,

test_ram: [1024*64]u8,

read_fn: *const fn (self: *Bus, address: u16) u8,
write_fn: *const fn (self: *Bus, address: u16, value: u8) void,

clocks_ticked: u64,

// ------------------------ INIT FUNCTIONS ------------------------------
pub fn init(cpu: *CPU6502, ppu: *PPU, apu: *APU, controller: *Controller, cartridge: *Cartridge) Bus {
    const bus: Bus = .{
        .ram = std.mem.zeroes([1024*2]u8),
        .cpu = cpu,
        .ppu = ppu,
        .apu = apu,
        .controller = controller,
        .cartridge = cartridge,
        .test_ram = undefined,
        .read_fn = standardReadByte,
        .write_fn = standardWriteByte,
        .clocks_ticked = 0,
    };

    return bus;
}

pub fn initTesting(cpu: *CPU6502) Bus {
    const bus: Bus = .{
        .ram = undefined,
        .cpu = cpu,
        .ppu = undefined,
        .apu= undefined,
        .cartridge = undefined,
        .test_ram = std.mem.zeroes([1024*64]u8),
        .read_fn = testReadByte,
        .write_fn = testWriteByte,
        .clocks_ticked = 0,
    };

    return bus; 
}
// ------------------------ INIT FUNCTIONS ------------------------------

// ------------------------ MEMORY FUNCTIONS ------------------------------
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
        0x2000...0x3FFF => self.ppu.readRegister(@truncate(addr & 0x0007)), // ppu registers from $00 to $07
        0x4000...0x4015 => self.apu.readRegister(addr - 0x4000),// TODO FIX THESE VALUES
        0x4016 => self.controller.readFirstController(),
        0x4017 => self.controller.readSecondController(),
        0x4018...0x401F => self.apu.readRegister(addr - 0x4000),
        0x4020...0xFFFF => self.cartridge.readByte(addr),
    };
}

fn testReadByte(self: *Bus, addr: u16) u8 {
    return self.test_ram[addr];
}

fn standardWriteByte(self: *Bus, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
        0x2000...0x3FFF => self.ppu.writeRegister(@truncate(addr & 0x0007), value),
        0x4000...0x4013 => self.apu.writeRegister(addr - 0x4000, value),// TODO FIX THESE VALUES TOO
        0x4014 => self.ppu.dmaCopy(value),
        0x4015 => self.apu.writeRegister(addr - 0x4000, value),
        0x4016 => self.controller.writeByte(value),
        0x4017...0x401F => self.apu.writeRegister(addr - 0x4000, value),
        0x4020...0xFFFF => self.cartridge.writeByte(addr, value),
    }
}

fn testWriteByte(self: *Bus, addr: u16, value: u8) void {
    self.test_ram[addr] = value;
}

pub fn readByte(self: *Bus, addr: u16) u8 {
    return self.read_fn(self, addr);
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

// this function should only be used to do dma from ram to oam
pub fn readRamPage(self: *Bus, page_number: u8) []const u8 {
    const page_base_addr = @as(u16, page_number & 0x1F) << 8;
    return self.ram[page_base_addr..page_base_addr + 256];
}
// ------------------------ MEMORY FUNCTIONS ------------------------------

// ------------------------ SYSTEM INTERFACE FUNCTIONS ------------------------------

pub fn loadCartridge(self: *Bus, cartridge: *Cartridge) void {
    self.cartridge = cartridge;
}

pub fn triggerNMI(self: *Bus) void {
    self.cpu.triggerNMI();
}

pub fn reset(self: *Bus) void {
    self.clocks_ticked = 0;
    self.cpu.reset();
}

pub fn clock(self: *Bus) void {
    self.cpu.step();
    self.ppu.render();
    self.ppu.render();
    self.ppu.render();
}

// ------------------------ SYSTEM INTERFACE FUNCTIONS ------------------------------
