const PPU = @This();

pub fn init() PPU {
    return .{

    };
}

pub fn readRegister(_: *PPU, _: u16) u8 {
    return 0x00;
}

pub fn writeRegister(_: *PPU, _: u16, _: u8) void {
    return;
}
