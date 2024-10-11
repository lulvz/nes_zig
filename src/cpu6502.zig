const std = @import("std");
const Bus = @import("bus.zig");
const instructions = @import("instructions.zig");

const CPU6502 = @This();

pc: u16,
sp: u8,
acc: u8,
X: u8,
Y: u8,
// least to most significant bit
P: packed struct { // processor status (packed structs are cool)
    c_carry: u1,
    z_zero: u1,
    i_interrupt_disable: u1,
    d_decimal: u1, // not supported in the NES (thank god TT)
    b_break: u1,
    no_cpu_effect: u1,
    v_overflow: u1,
    n_negative: u1,
},

screen: [256*240]u8, // 56 colors per pixel (could be u6)

bus: *Bus,

pub fn init(bus: *Bus) CPU6502 {
    var cpu6592 = CPU6502{
        .pc = 0xfffc,
        .sp = 0xFF,
        .acc = 0x0,
        .X = 0x0,
        .Y = 0x0,
        .P = .{
            .c_carry = 0x0,
            .z_zero = 0x0,
            .i_interrupt_disable = 0x0,
            .d_decimal = 0x0, // not supported in the NES (thank god TT)
            .b_break = 0x0,
            .no_cpu_effect = 0x1,
            .v_overflow = 0x0,
            .n_negative = 0x0,
        },
        .screen = undefined,
        .bus = bus,
    };

    @memset(&cpu6592.screen, 0x0);

    return cpu6592;
}

// After we push, the stack pointer will point to the next free spot on the stack
fn pushToStack(self: *CPU6502, value: u8) void {
    self.bus.writeByte(@as(u16, 0x0100 +% @as(u16, self.sp)), value);
    self.sp -%= 1;
}

// When we pop, the stack pointer is pointing to a free spot on the stack, so we
// add one, to get the last value pushed, and return it, this value stays on the stack,
// but it doesn't count as being on the stack, since the stack pointer is now pointing to it,
// meaning it's a free spot
fn popFromStack(self: *CPU6502) u8 {
    self.sp +%= 1;
    return self.bus.readByte(0x0100 +% self.sp);
} 

// TODO NUMBER OF CYCLES, BASED ON P AND T (https://www.pagetable.com/c64ref/6502/?tab=2#)
pub fn step(self: *CPU6502) void {
    const opcode = self.bus.readByte(self.pc);
    self.pc+%=1;

    const i: instructions.Instruction = instructions.instruction_set[opcode];
    var address: u16 = 0;
    // if page is crossed, there are three addressing modes that add a cycle
    var page_crossed = false;

    // Decode addressing mode TODO CHECK IF THIS IS CORRECT
    switch (i.addressing_mode) {
        // Non-Indexed, Non-Memory
        .ACCUMULATOR => {
        },
        .IMMEDIATE => {
            address = self.pc;
            self.pc +%= 1;
        },
        .IMPLIED => {},

        // Non-Indexed Memory Ops
        .RELATIVE => {
            const offset: i8 = @bitCast(self.bus.readByte(self.pc));
            address = @bitCast(@as(i16, @bitCast(self.pc)) +% @as(i16, offset) +% 1); // todo check if this is correct
            self.pc +%= 1;
        },
        .ABSOLUTE => {
            address = self.bus.readWord(self.pc);
            self.pc +%= 2;
        },
        .ZEROPAGE => {
            address = @as(u16, self.bus.readByte(self.pc));
            self.pc +%= 1;
        },
        .INDIRECT => {
            const pointer = self.bus.readWord(self.pc);
            address = self.bus.readWord(pointer);
            self.pc +%= 2;
        },

        // Indexed Memory Ops
        // X and Y are interpreted as unsigned values from 0 to 255
        .ABSOLUTE_X => {
            const base = self.bus.readWord(self.pc);
            address = base +% self.X;
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc +%= 2;
        },
        .ABSOLUTE_Y => {
            const base = self.bus.readWord(self.pc);
            address = base +% @as(u16, self.Y);
            // if we overflow the last 256bytes then we crossed a page
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc +%= 2;
        },
        .ZEROPAGE_X => {
            address = @as(u16, self.bus.readByte(self.pc) +% self.X) & 0x00FF;
            self.pc +%= 1;
        },
        .ZEROPAGE_Y => {
            address = @as(u16, self.bus.readByte(self.pc) +% self.Y) & 0x00FF;
            self.pc +%= 1;
        },
        .INDEXED_INDIRECT => {
            const pointer = @as(u16, self.bus.readByte(self.pc) +% self.X) & 0x00FF;
            address = self.bus.readWord(pointer);
            self.pc +%= 1;
        },
        .INDIRECT_INDEXED => {
            const pointer = self.bus.readByte(self.pc);
            const base = self.bus.readWord(pointer);
            address = base +% @as(u16, self.Y);
            page_crossed = (address & 0xFF00) != (base & 0xFF00);
            self.pc +%= 1;
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
            self.updateNZFlags(self.acc);

            // Update carry flag
            self.P.c_carry = if (result > 0xFF) 1 else 0; // Set carry flag if overflow occurs 
            // Update overflow flag (when result sign is different but addends have same sign)
            self.P.v_overflow = @as(u1, @truncate(((self.acc ^ old_acc) & (self.acc ^ operand)) >> 7));
        },
        .AND => { // Operation: A ∧ M → A
            const operand: u8 = self.bus.readByte(address);
            self.acc = self.acc & operand;
            self.updateNZFlags(self.acc);
        },
        .ASL => { // Operation: C ← /M7...M0/ ← 0
            const operand = self.bus.readByte(address);
            self.P.c_carry = @as(u1, @truncate((operand & 0x80) >> 7));
            const shifted_value = operand << 1;
            self.bus.writeByte(address, shifted_value);
            self.updateNZFlags(shifted_value);
        },
        .ASLA => {
            self.P.c_carry = @as(u1, @truncate((self.acc & 0x80) >> 7));
            self.acc <<= 1;
            self.updateNZFlags(self.acc);
        },
        .BCC => {
            if(self.P.c_carry == 0) {
                self.pc = address;
            }
        },
        .BCS => {
            if(self.P.c_carry == 1) {
                self.pc = address;
            }
        },
        .BEQ => {
            if(self.P.z_zero == 1) {
                self.pc = address;
            }
        },
        .BIT => { // Operation: A ∧ M, M7 → N, M6 → V
            const operand: u8 = self.bus.readByte(address);
            const result: u8 = self.acc & operand;
            // N and V flags are set based on the memory
            self.P.n_negative = @as(u1, @truncate((operand & 0x80) >> 7));
            self.P.v_overflow = @as(u1, @truncate((operand & 0x40) >> 6));
            // Z flag is set based on the result
            self.P.z_zero = if(result == 0) 1 else 0;
        },
        .BMI => {
            if(self.P.n_negative == 1){
                self.pc = address;
            }
        },
        .BNE => {
            if(self.P.z_zero == 0) {
                self.pc = address;
            }
        },
        .BPL => {
            if(self.P.n_negative == 0) {
                self.pc = address;
            }
        },
        .BRK => {
            const return_address: u16 = self.pc +% 1;

            // Push the high byte of the PC to the stack
            self.pushToStack(@truncate(return_address >> 8));

            // Push the low byte of the PC to the stack
            self.pushToStack(@truncate(return_address & 0xFF));

            // Set the break flag in the status register
            self.P.b_break = 1;

            // Push the status register to the stack
            const status_register: u8 = @bitCast(self.P);
            
            self.pushToStack(status_register);

            // Set the interrupt disable flag to prevent further interrupts
            self.P.i_interrupt_disable = 1;

            // Fetch the new PC from the interrupt vector (0xFFFE and 0xFFFF)
            const low_byte = self.bus.readByte(0xFFFE);
            const high_byte = self.bus.readByte(0xFFFF);
            self.pc = @as(u16, (@as(u16, high_byte) << 8) | low_byte);
            // TODO CHECK IF THIS ISRIGHT
        },
        .BVC => {
            if(self.P.v_overflow == 0) {
                self.pc = address;
            }
        },
        .BVS => {
            if(self.P.v_overflow == 1) {
                self.pc = address;
            }
        },
        .CLC => {
            self.P.c_carry = 0;
        },
        .CLD => {
            self.P.d_decimal = 0;
        },
        .CLI => {
            self.P.i_interrupt_disable = 0;
        },
        .CLV => {
            self.P.v_overflow = 0;
        },
        .CMP => {
            const operand: u8 = self.bus.readByte(address);
            self.updateNZFlags(self.acc -% operand);
            if(self.acc >= operand) {
                self.P.c_carry = 1;
            } else {
                self.P.c_carry = 0;
            }
        },
        .CPX => {
            const operand: u8 = self.bus.readByte(address);
            self.updateNZFlags(self.X -% operand);
            if(self.X >= operand) {
                self.P.c_carry = 1;
            } else {
                self.P.c_carry = 0;
            }
        },
        .CPY => {
            const operand: u8 = self.bus.readByte(address);
            self.updateNZFlags(self.Y -% operand);
            if(self.Y >= operand) {
                self.P.c_carry = 1;
            } else {
                self.P.c_carry = 0;
            }
        },
        .DEC => {
            const operand: u8 = self.bus.readByte(address);
            const result: u8 = operand -% 1;
            self.bus.writeByte(address, result); 
            self.updateNZFlags(result);
        },
        .DEX => {
            self.X -%= 1;
            self.updateNZFlags(self.X); 
        },
        .DEY => {
            self.Y -%=1;
            self.updateNZFlags(self.Y);
        },
        .EOR => {
            const operand = self.bus.readByte(address);   
            self.acc = self.acc ^ operand;
            self.updateNZFlags(self.acc);
        },
        .INC => {
            const operand: u8 = self.bus.readByte(address);
            const result: u8 = operand +% 1;
            self.bus.writeByte(address, result); 
            self.updateNZFlags(result); 
        },
        .INX => {
            self.X +%= 1;
            self.updateNZFlags(self.X); 
        },
        .INY => {
            self.Y +%= 1;
            self.updateNZFlags(self.Y);
        },
        .JMP => {
            self.pc = address;
        },
        .JSR => { // this instruction doesn't push the address of the next instruction to the stack, it pushes the address of the last byte of the instruction itself (it's a 3 byte instruction) and expects the RTS instruction to add 1 to that address when popping it's value from the stack to resume execution
            const return_address = self.pc -% 1; // Subtract 1 from PC

            // Push the high byte of the return address to the stack
            self.pushToStack(@truncate(return_address >> 8));

            // Push the low byte of the return address to the stack
            self.pushToStack(@truncate(return_address & 0xFF));

            // Jump to the subroutine address
            self.pc = address;
        },
        .LDA => {
            self.acc = self.bus.readByte(address);    
            self.updateNZFlags(self.acc);
        },
        .LDX => {
            self.X = self.bus.readByte(address);
            self.updateNZFlags(self.X);
        },
        .LDY => {
            self.Y = self.bus.readByte(address);
            self.updateNZFlags(self.Y);
        },
        .LSR => {
            const operand = self.bus.readByte(address);
            self.P.c_carry = @truncate(operand & 0x01);
            const shifted_value = operand >> 1;
            self.bus.writeByte(address, shifted_value);
            self.updateNZFlags(shifted_value); // N is 0, Z is updated based on the result
        },
        .LSRA => {
            self.P.c_carry = @truncate(self.acc & 0x01);
            self.acc >>= 1;
            self.updateNZFlags(self.acc); // N is 0, Z is updated based on the accumulator
        },
        .NOP => {},
        .ORA => {
            const operand = self.bus.readByte(address);
            self.acc = self.acc | operand;
            self.updateNZFlags(self.acc);
        },
        .PHA => {
            self.pushToStack(self.acc);
        },
        .PHP => {
            self.pushToStack(@bitCast(self.P));
        },
        .PLA => { 
            self.acc = self.popFromStack();
            self.updateNZFlags(self.acc);
        },
        .PLP => {
            self.P = self.popFromStack();
        },
        .ROL => {
            const operand = self.bus.readByte(address);
            self.P.c_carry = @as(u1, @truncate((operand & 0x80) >> 7));
            const shifted_value = (operand << 1) | @as(u8, self.P.c_carry);
            self.bus.writeByte(address, shifted_value);
            self.updateNZFlags(shifted_value);
        },
        .ROLA => {
            self.P.c_carry = @as(u1, @truncate((self.acc & 0x80) >> 7));
            self.acc = (self.acc << 1) | @as(u8, self.P.c_carry);
            self.updateNZFlags(self.acc);
        },
        .ROR => {
            const operand = self.bus.readByte(address);
            self.P.c_carry = @truncate(operand & 0x01);
            const shifted_value = operand >> 1 | (@as(u8, self.P.c_carry) << 7);
            self.bus.writeByte(address, shifted_value);
            self.updateNZFlags(shifted_value); // N is 0, Z is updated based on the result
        },
        .RORA => {
            self.P.c_carry = @truncate(self.acc & 0x01);
            self.acc = (self.acc >> 1) | (@as(u8, self.P.c_carry) << 7);
            self.updateNZFlags(self.acc); // N is 0, Z is updated based on the accumulator
        },
        .RTI => {
            self.P = @bitCast(self.popFromStack());
            const low_byte = self.popFromStack();
            const high_byte = self.popFromStack();
            self.pc = @as(u16, (@as(u16, high_byte) << 8) | low_byte);
        },
        .RTS => {
            const low_byte = self.popFromStack();
            const high_byte = self.popFromStack();
            self.pc = @as(u16, ((@as(u16, high_byte) << 8) | low_byte) +% 1);
        },
        .SBC => {
            const operand: u8 = self.bus.readByte(address);
            const carry: u8 = @as(u8, 1 - self.P.c_carry); // 1 if C == 0, 0 if C == 1 (inverted carry)
            const old_acc = self.acc;
            
            const result: u16 = @as(u16, old_acc) -% @as(u16, operand) -% @as(u16, carry);
            
            // Update the accumulator
            self.acc = @as(u8, @truncate(result));

            // Update status flags
            self.updateNZFlags(self.acc);

            // Update carry flag (borrow flag)
            self.P.c_carry = if (result <= 0xFF) 1 else 0; // Clear if borrow occurs

            // Update overflow flag: if the sign of the result is different from the sign of both the accumulator and the operand
            self.P.v_overflow = @as(u1, @truncate(((old_acc ^ self.acc) & (old_acc ^ operand)) >> 7));
        },
        .SEC => {
            self.P.c_carry = 1;
        },
        .SED => {
            self.P.d_decimal = 1; // nes has no decimal mode
        },
        .SEI => {
            self.P.i_interrupt_disable = 1;
        },
        .STA => {
            self.bus.writeByte(address, self.acc);
        },
        .STX => {
            self.bus.writeByte(address, self.X);
        },
        .STY => {
            self.bus.writebyte(address, self.Y);
        },
        .TAX => {
            self.X = self.acc;
            self.updateNZFlags(self.X);
        },
        .TAY => {
            self.Y = self.acc;
            self.updateNZFlags(self.Y);
        },
        .TSX => {
            self.X = self.sp;
            self.updateNZFlags(self.X);
        },
        .TXA => {
            self.acc = self.X;
            self.updateNZFlags(self.acc);
        },
        .TXS => {
            self.sp = self.X;
        },
        .TYA => {
            self.acc = self.Y;
            self.updateNZFlags(self.acc);
        },
        else => {
            std.debug.print("Unimplemented opcode: {}\n", .{i.opcode});
        },
    }
}

fn updateNZFlags(self: *CPU6502, value: u8) void {
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
