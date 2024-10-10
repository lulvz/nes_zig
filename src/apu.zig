const APU = @This();

pub fn init() APU {
    return .{

    };
}

pub fn readRegister(_: *APU, _: u16) u8 {
    return 0x00;
}

pub fn writeRegister(_: *APU, _: u16, _: u8) void {
    return;
}
