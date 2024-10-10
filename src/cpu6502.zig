const std = @import("std");
const Bus = @import("bus.zig");
const instructions = @import("instructions.zig");

const CPU6502 = @This();

pc: u16,
sp: u8,
acc: u8,
X: u8,
Y: u8,
P: packed struct { // processor status (packed structs are cool)
    n_negative: u1,
    v_overflow: u1,
    b_break: u1,
    d_decimal: u1, // not supported in the NES (thank god TT)
    i_interrupt_disable: u1,
    z_zero: u1,
    c_carry: u1,
},

screen: [256*240]u8, // 56 colors per pixel (could be u6)

bus: *Bus,

pub fn init(bus: *Bus) CPU6502 {
    var cpu6592 = CPU6502{
        .pc = 0xfffc,
        .sp = 0x0,
        .acc = 0x0,
        .X = 0x0,
        .Y = 0x0,
        .P = .{
            .n_negative = 0x0,
            .v_overflow = 0x0,
            .b_break = 0x0,
            .d_decimal = 0x0, // not supported in the NES (thank god TT)
            .i_interrupt_disable = 0x0,
            .z_zero = 0x0,
            .c_carry = 0x0,
        },
        .screen = undefined,
        .bus = bus,
    };

    @memset(&cpu6592.screen, 0x0);

    return cpu6592;
}

pub fn step(self: *CPU6502) void {
    const opcode = self.bus.readByte(self.pc);
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
            const offset: i8 = @bitCast(self.bus.readByte(self.pc));
            self.pc += 1;
            address = @intCast(@as(i32, self.pc) + @as(i32, offset) + 1);
        },
        .ABSOLUTE => {
            address = self.bus.readWord(self.pc);
            self.pc += 2;
        },
        .ZEROPAGE => {
            address = @as(u16, self.bus.readByte(self.pc));
            self.pc += 1;
        },
        .INDIRECT => {
            const pointer = self.bus.readWord(self.pc);
            address = self.bus.readWord(pointer);
            self.pc += 2;
        },

        // Indexed Memory Ops
        // X and Y are interpreted as unsigned values from 0 to 255
        .ABSOLUTE_X => {
            const base = self.bus.readWord(self.pc);
            address = base +% self.X;
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 2;
        },
        .ABSOLUTE_Y => {
            const base = self.bus.readWord(self.pc);
            address = base +% @as(u16, self.Y);
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 2;
        },
        .ZEROPAGE_X => {
            address = @as(u16, self.bus.readByte(self.pc) +% self.X) & 0x00FF;
            self.pc += 1;
        },
        .ZEROPAGE_Y => {
            address = @as(u16, self.bus.readByte(self.pc) +% self.Y) & 0x00FF;
            self.pc += 1;
        },
        .INDEXED_INDIRECT => {
            const pointer = @as(u16, self.bus.readByte(self.pc) +% self.X) & 0x00FF;
            address = self.bus.readWord(pointer);
            self.pc += 1;
        },
        .INDIRECT_INDEXED => {
            const pointer = self.bus.readByte(self.pc);
            const base = self.bus.readWord(pointer);
            address = base +% @as(u16, self.Y);
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc += 1;
        },
    }

    switch (i.opcode) {
        .ADC => {
            const operand: u8 = self.bus.readByte(address);
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
