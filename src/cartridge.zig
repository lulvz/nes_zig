const Cartridge = @This();

pub fn init() Cartridge {
    return .{

    };
}

pub fn readByte(_: *Cartridge, _: u16) u8 {
    return 0x00;
}

pub fn writeByte(_: *Cartridge, _: u16, _: u8) void {
    return;
}
