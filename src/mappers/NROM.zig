const std = @import("std");

pub const NROM = @This(); 
PrgROM: []u8,
ChrROM: []u8,
prg_rom_units: u8, // 16KB units
chr_rom_units: u8, // 8KB units

pub fn readByte(self: *NROM, addr: u16) u8 {
    const reading = if(self.prg_rom_units > 1) addr & 0x7FFF else addr & 0x3FFF;
    return self.PrgROM[reading];// either 16KB or 32KB prg rom
}

pub fn writeByte(self: *NROM, addr: u16, value: u8) void {
    _ = self;
    _ = addr;
    _ = value;
}

pub fn ppuReadByte(self: *NROM, addr: u14) u8 {
    return self.ChrROM[addr&0x1FFF];
}

pub fn ppuWriteByte(self: *NROM, addr: u14, value: u8) void {
    _ = self;
    _ = addr;
    _ = value;
}
