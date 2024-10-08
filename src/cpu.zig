const std = @import("std");

const ADDRESSING_MODE = enum {
    ACCUMULATOR,
    IMMEDIATE,
    IMPLIED,
    RELATIVE,
    ABSOLUTE,
    ABSOLUTE_X,
    ABSOLUTE_Y,

    ZEROPAGE,
    ZEROPAGE_X,
    ZEROPAGE_Y,

    INDIRECT,
    INDEXED_INDIRECT,
    INDIRECT_INDEXED,
};

const CPU6502 = @This();

pc: u16,
sp: u8,
acc: u8,
iX: u8,
iY: u8,

// processor status (packed structs are cool)
P: packed struct {
    n_negative: bool,
    v_overflow: bool,
    b_break: bool,
    d_decimal: bool,
    i_interrupt_disable: bool,
    z_zero: bool,
    c_carry: bool,
},

// Address range 	Size 	Device 
// $0000–$07FF 	    $0800 	2 KB internal RAM
// $0800–$0FFF 	    $0800 	Mirrors of $0000–$07FF
// $1000–$17FF 	    $0800
// $1800–$1FFF 	    $0800
// $2000–$2007 	    $0008 	CPU6502 PPU registers
// $2008–$3FFF 	    $1FF8 	Mirrors of $2000–$2007 (repeats every 8 bytes)
// $4000–$4017 	    $0018 	CPU6502 APU and I/O registers
// $4018–$401F 	    $0008 	APU and I/O functionality that is normally disabled. See CPU Test Mode.
// $4020–$FFFF      $BFE0   Unmapped. Available for cartridge use.
// • $6000–$7FFF    $2000   Usually cartridge RAM, when present.
// • $8000–$FFFF 	$8000   Usually cartridge ROM and mapper registers.
memory: u8[2^16],
screen: u8[256*240], // 56 colors per pixel (could be u6)

pub fn init() CPU6502 {
    var cpu6592 = CPU6502{
        .pc = 0xfffc,
        .sp = 0x0,
        .acc = 0x0,
        .iX = 0x0,
        .iY = 0x0,
        .P = 0x0,
        .memory = undefined,
        .screen = undefined,
    };

    @memset(&cpu6592.screen, 0x0);
    @memset(&cpu6592.memory, 0x0);

    return cpu6592;
}

// receives a slice of bytes and loads2
// pub fn loadROM(self: *CPU6502, ROMBytes: []const u8) !void {
//     // Check if the ROM has a valid CPU6502 header
//     if (ROMBytes.len < 16 or !std.mem.eql(u8, ROMBytes[0..4], "CPU6502\x1A")) {
//         return error.InvalidCPU6502Header;
//     }

//     const prgROMSize = 16384 * ROMBytes[4];
//     const chrROMSize = 8192 * ROMBytes[5];
//     const flags6 = ROMBytes[6];
//     // const flags7 = ROMBytes[7];

//     // Calculate offsets
//     const headerSize = 16;
//     const trainerSize = if (flags6 & 0x04 != 0) 512 else 0;
//     const prgROMStart = headerSize + trainerSize;
//     const chrROMStart = prgROMStart + prgROMSize;

// }

fn readByte(self: *CPU6502, addr: u16) u8 {
    return self.mem[addr];
}

fn readFirstArgument(self: *CPU6502) u8 {
    return self.mem[self.pc+1];
}

fn readSecondArgument(self: *CPU6502) u8 {
    return self.mem[self.pc+2];
}

fn readWord(self: *CPU6502, addr: u16) u16 {
    return @as(u16, @as(u16, self.mem[addr+1] << 8) | @as(u16, self.mem[addr]));
}

fn readWordArgument(self: *CPU6502) u16 {
    return @as(u16, @as(u16, self.mem[self.pc+2] << 8) | @as(u16, self.mem[self.pc+1]));
}

fn writeByte(self: *CPU6502, addr: u16, value: u8) void {
    self.mem[addr] = value;
}

fn fetchByteAtPC(self: *CPU6502) u8 {
    const byte = self.readByte(self.pc);
    return byte;
}

pub fn step(self: *CPU6502) void {
    const opcode = self.fetchByteAtPC();
    self.pc+=1;
    switch (opcode) {

    }
}

fn updateFlags(self: *CPU6502, value: u8) void {
    if (value == 0) {
        self.P |= 0b00000010; // Set zero flag
    } else {
        self.P &= ~0b00000010; // Clear zero flag
    }
    if ((value & 0b10000000) != 0) {
        self.P |= 0b10000000; // Set negative flag
    } else {
        self.P &= ~0b10000000; // Clear negative flag
    }
}
