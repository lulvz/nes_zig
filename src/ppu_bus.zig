const Cartridge = @import("cartridge.zig");

const PPUBus = @This();

cartridge: *Cartridge,

pub fn init(cartridge: *Cartridge) PPUBus {
    return .{
        .cartridge = cartridge,
    };
}

pub fn readByte(self: *PPUBus, addr: u16) u8 {
    _ = self;
    const valid_addr  = addr & 0x3FFF;
    _ = valid_addr;
    return 0x0;
}

pub fn writeByte(self: *PPUBus, addr: u16, value: u8) void {
    _ = self;
    _ = value;
    const valid_addr  = addr & 0x3FFF;
    _ = valid_addr;
    return;
}
