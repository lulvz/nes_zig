const NROM  = @import("NROM.zig");

pub const Mapper= union(enum) {
    NROM: NROM,

    pub fn readByte(self: *Mapper, addr: u16) u8 {
        return switch (self.*) {
            .NROM => |*nrom| nrom.*.readByte(addr),
        };
    }

    pub fn writeByte(self: *Mapper, addr: u16, value: u8) void {
        switch (self.*) {
            .NROM => |*nrom| nrom.*.writeByte(addr, value),
        }
    }

    pub fn ppuReadByte(self: *Mapper, addr: u14) u8 {
        return switch (self.*) {
            .NROM => |*nrom| nrom.*.ppuReadByte(addr),
        };
    }

    pub fn ppuWriteByte(self: *Mapper, addr: u14, value: u8) void {
        switch (self.*) {
            .NROM => |*nrom| nrom.*.ppuWriteByte(addr, value),
        }
    }
};
