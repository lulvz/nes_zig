const Cartridge = @import("cartridge.zig");

const PPUBus = @This();

cartridge: *Cartridge,

pub fn init(cartridge: *Cartridge) PPUBus {
    return .{
        .cartridge = cartridge,
    };
}

pub fn ppuReadByte(self: *PPUBus, addr: u14) u8 {
    switch (addr) {
        0x0000...0x1FFF => return self.mapper.readPPU(addr),
        0x2000...0x2FFF => return self.vram[addr & 0x0FFF],
        0x3000...0x3EFF => return 0x00, // unused
        0x3F00...0x3FFF => return self.palettes[addr & 0x001F],
    }
}

pub fn ppuWriteByte(self: *PPUBus, addr: u16, value: u8) void {
    _ = self;
    _ = value;
    const valid_addr  = addr & 0x3FFF;
    _ = valid_addr;
    return;
}
