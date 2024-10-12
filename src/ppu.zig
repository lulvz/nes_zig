const Bus = @import("bus.zig");
const PPUBus = @import("ppu_bus.zig");

const PPU = @This();

bus: *Bus,
ppu_bus: *PPUBus,

pub fn init(bus: *Bus, ppu_bus: *PPUBus) PPU {
    return .{
        .bus = bus,
        .ppu_bus = ppu_bus,
    };
}

pub fn readRegister(self: *PPU, addr: u16) u8 {
    _ = self;
    switch(addr) {
        0x0000 => {

        },
        0x0001 => {

        },
        0x0002 => {

        },
        0x0003 => {

        },
        0x0004 => {

        },
        0x0005 => {

        },
        0x0006 => {

        },
        0x0007 => {

        },
    }
    return 0x00;
}

pub fn writeRegister(self: *PPU, addr: u16, value: u8) void {
    _ = self;
    _ = value;
    switch(addr) {
        0x0000 => {

        },
        0x0001 => {

        },
        0x0002 => {

        },
        0x0003 => {

        },
        0x0004 => {

        },
        0x0005 => {

        },
        0x0006 => {

        },
        0x0007 => {

        },
    }
    return;
}
