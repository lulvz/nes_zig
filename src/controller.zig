const std = @import("std");
const Controller = @This();

// 0 - A
// 1 - B
// 2 - Select
// 3 - Start
// 4 - Up
// 5 - Down
// 6 - Left
// 7 - Right
data_line_first_controller: packed struct {
    a: u1,
    b: u1,
    select: u1,
    start: u1,
    up: u1,
    down: u1,
    left: u1,
    right: u1,
},
data_line_second_controller: packed struct {
    a: u1,
    b: u1,
    select: u1,
    start: u1,
    up: u1,
    down: u1,
    left: u1,
    right: u1,
},

strobe: bool,

shift_register_one: u8,
shift_register_two: u8,

pub fn init() Controller {
    return .{
        .data_line_first_controller = .{
            .a = 0,
            .b = 0,
            .select = 0,
            .start = 0,
            .up = 0,
            .down = 0,
            .left = 0,
            .right = 0, 
        },
        .data_line_second_controller = .{
            .a = 0,
            .b = 0,
            .select = 0,
            .start = 0,
            .up = 0,
            .down = 0,
            .left = 0,
            .right = 0, 
        },
        .strobe = false,
        .shift_register_one = 0,
        .shift_register_two = 0,
    };
}

pub fn writeByte(self: *Controller, value: u8) void {
    if((value & 0x1) == 0x1) {
        self.strobe = true;
        self.shift_register_one = @bitCast(self.data_line_first_controller);
        self.shift_register_two = @bitCast(self.data_line_second_controller);
    } else {
        self.strobe = false;
    }
}

pub fn readFirstController(self: *Controller) u8 {
    if(self.strobe) {
        return self.shift_register_one & 0x1;
    } else {
        const return_bit = self.shift_register_one & 0x1; 
        self.shift_register_one >>= 1;
        return return_bit;
    }
}

pub fn readSecondController(self: *Controller) u8 {
    if(self.strobe) {
        return self.shift_register_two & 0x1;
    } else {
        const return_bit = self.shift_register_two & 0x1; 
        self.shift_register_two >>= 1;
        return return_bit;
    }
}
