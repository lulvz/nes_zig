const std = @import("std");
const CPU6502 = @import("cpu6502.zig");
const Bus = @import("bus.zig");

test "ADC Immediate Mode" {
    var bus = Bus.init();
    var cpu = CPU6502.init(&bus);
    
    // Set up the CPU state
    cpu.acc = 0x50;
    cpu.P.c_carry = 0;
    
    // Write the instruction and operand to memory
    bus.writeByte(0x0000, 0x69); // ADC Immediate opcode
    bus.writeByte(0x0001, 0x10); // Operand
    
    // Execute one instruction
    cpu.pc = 0x0000;
    cpu.step();
    
    // Check the results
    try std.testing.expectEqual(@as(u8, 0x60), cpu.acc);
    try std.testing.expectEqual(@as(u1, 0), cpu.P.c_carry);
    try std.testing.expectEqual(@as(u1, 0), cpu.P.z_zero);
    try std.testing.expectEqual(@as(u1, 0), cpu.P.n_negative);
}