const std = @import("std");
const instructions = @import("instructions.zig");

const CPU6502 = @This();

pc: u16,
sp: u8,
acc: u8,
X: u8,
Y: u8,

// processor status (packed structs are cool)
P: packed struct {
    n_negative: u1,
    v_overflow: u1,
    b_break: u1,
    d_decimal: u1, // not supported in the NES (thank god TT)
    i_interrupt_disable: u1,
    z_zero: u1,
    c_carry: u1,
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
        .X = 0x0,
        .Y = 0x0,
        .P = undefined,
        .memory = undefined,
        .screen = undefined,
    };

    @memset(&cpu6592.P, 0x0);
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

fn readWord(self: *CPU6502, addr: u16) u16 {
    return @as(u16, @as(u16, self.mem[addr+1] << 8) | @as(u16, self.mem[addr]));
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

    const i: instructions.Instruction = instructions.instruction_set[opcode];
    var address: u16 = 0;
    var page_crossed = false;

    // Decode addressing mode TODO CHECK IF THIS IS CORRECT
    switch (i.addressing_mode) {
        // Non-Indexed, Non-Memory
        .ACCUMULATOR => {},
        .IMMEDIATE => {
            address = self.pc;
            self.pc += 1;
        },
        .IMPLIED => {},

        // Non-Indexed Memory Ops
        .RELATIVE => {
            const offset: i8 = @bitCast(self.readByte(self.pc));
            self.pc += 1;
            address = @intCast(@as(i32, self.pc) + @as(i32, offset) + 1);
        },
        .ABSOLUTE => {
            address = self.readWord(self.pc);
            self.pc += 2;
        },
        .ZEROPAGE => {
            address = @as(u16, self.readByte(self.pc));
            self.pc += 1;
        },
        .INDIRECT => {
            const pointer = self.readWord(self.pc);
            address = self.readWord(pointer);
            self.pc += 2;
        },

        // Indexed Memory Ops
        // X and Y are interpreted as unsigned values from 0 to 255
        .ABSOLUTE_X => {
            const base = self.readWord(self.pc);
            address = base +% self.X;
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 2;
        },
        .ABSOLUTE_Y => {
            const base = self.readWord(self.pc);
            address = base +% @as(u16, self.Y);
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 2;
        },
        .ZEROPAGE_X => {
            address = @as(u16, self.readByte(self.pc) +% self.X) & 0x00FF;
            self.pc += 1;
        },
        .ZEROPAGE_Y => {
            address = @as(u16, self.readByte(self.pc) +% self.Y) & 0x00FF;
            self.pc += 1;
        },
        .INDEXED_INDIRECT => {
            const pointer = @as(u16, self.readByte(self.pc) +% self.X) & 0x00FF;
            address = self.readWord(pointer);
            self.pc += 1;
        },
        .INDIRECT_INDEXED => {
            const pointer = self.readByte(self.pc);
            const base = self.readWord(pointer);
            address = base +% @as(u16, self.Y);
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 1;
        },
    }

    switch (i.opcode) {
        .ADC => {
            const operand: u8 = self.readByte(address);
            const carry:u8 = @as(u8, self.P.c_carry);
            const old_acc = self.acc;
            const result: u16 = @as(u16, old_acc) +% @as(u16, operand) +% @as(u16, carry);
            
            // Update the accumulator
            self.acc = @as(u8, @truncate(result));

            // Update status flags
            self.updateFlags(self.acc);

            // Update carry flag
            self.P.c_carry = if (result > 0xFF) 1 else 0; // Set carry flag if overflow occurs 
            // Update overflow flag (when result sign is different but addends have same sign)
            self.P.v_overflow = @as(u1, @truncate(((self.acc ^ old_acc) & (self.acc ^ operand)) >> 7));
        },
        else => {
            std.debug.print("Unimplemented opcode: {}\n", .{i.opcode});
        },
    }
}

fn updateFlags(self: *CPU6502, value: u8) void {
    if (value == 0) {
        self.P.z_zero = 1; // Set zero flag
    } else {
        self.P.z_zero = 0; // Clear zero flag
    }
    if ((value & 0b10000000) != 0) {
        self.P.n_negative = 1; // Set negative flag
    } else {
        self.P.n_negative = 0; // Clear negative flag
    }
}