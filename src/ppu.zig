const std = @import("std");
const rl = @import("raylib");
const Bus = @import("bus.zig");
const PPUBus = @import("ppu_bus.zig");

const PPU = @This();

bus: *Bus,
ppu_bus: *PPUBus,

// PPU registers
control: packed struct {
    n_nametable_address: u2,
    i_vram_addr_increment: u1,
    s_sprite_pattern_table: u1,
    b_background_pattern_table: u1,
    h_sprite_size: u1,
    p_master_slave_select: u1,
    v_generate_nmi: u1,
},
mask: packed struct {
    G_grayscale: u1,
    m_show_background_left: u1,
    M_show_sprites_left: u1,
    b_show_background: u1,
    s_show_sprites: u1,
    R_emphasize_red: u1,
    G_emphasize_green: u1,
    B_emphasize_blue: u1,
},
status: packed struct {
    _unused: u5,
    o_sprite_overflow: u1,
    s_sprite_zero_hit: u1,
    v_vblank: u1,
},

ppu_data_buffer: u8,

oam_addr: u8,
oam_data: [256]u8,

// Internal PPU registers
v: u15, // Current VRAM address (15 bits) Note that while the v register has 15 bits, the PPU memory space is only 14 bits wide. The highest bit is unused for access through $2007. 
t: u15, // Temporary VRAM address (15 bits)
x: u3,  // Fine X scroll (3 bits)
w: u1,  // First or second write toggle (1 bit)

frame_buffer: [256 * 240]rl.Color,

scanline: u16,
cycle: u16,

frame_finished: bool,
frame: u32,

pub fn init(bus: *Bus, ppu_bus: *PPUBus) PPU {
    return .{
        .bus = bus,
        .ppu_bus = ppu_bus,
        .control = .{
            .n_nametable_address = 0,
            .i_vram_addr_increment = 0,
            .s_sprite_pattern_table = 0,
            .b_background_pattern_table = 0,
            .h_sprite_size = 0,
            .p_master_slave_select = 0,
            .v_generate_nmi = 0,
        },
        .mask = .{
            .G_grayscale = 0,
            .m_show_background_left = 0,
            .M_show_sprites_left = 0,
            .b_show_background = 0,
            .s_show_sprites = 0,
            .R_emphasize_red = 0,
            .G_emphasize_green = 0,
            .B_emphasize_blue = 0,
        },
        .status = .{
            ._unused = 0,
            .o_sprite_overflow = 0,
            .s_sprite_zero_hit = 0,
            .v_vblank = 0,
        },
        .ppu_data_buffer = 0,
        .oam_addr = 0,
        .oam_data = std.mem.zeroes([256]u8),
        .v = 0,
        .t = 0,
        .x = 0,
        .w = 0,
        .frame_buffer = std.mem.zeroes([256*240]rl.Color),
        .scanline = 261, // pre-render scanline
        .cycle = 0,
        .frame_finished = false,
        .frame = 0,
    };
}

pub fn readRegister(self: *PPU, addr: u3) u8 {
    switch (addr) {
        0x0002 => { // PPUSTATUS
            const result = @as(u8, @bitCast(self.status));
            self.status.v_vblank = 0;
            self.w = 0;
            return result;
        },
        0x0004 => { // OAMDATA
            return self.oam_data[self.oam_addr];
        },
        0x0007 => { // PPUDATA
            var result = self.ppu_data_buffer;
            self.ppu_data_buffer = self.ppu_bus.ppuReadByte(@truncate(self.v));

            if (self.v >= 0x3F00) {
                result = self.ppu_data_buffer;
                self.ppu_data_buffer = self.ppu_bus.ppuReadByte(@truncate(self.v - 0x1000));
            }

            self.v = (self.v +% if (self.control.i_vram_addr_increment == 0) @as(u15, 1) else @as(u15, 32)) & 0x3FFF;
            return result;
        },
        else => return 0,
    }
}

pub fn writeRegister(self: *PPU, addr: u3, value: u8) void {
    switch(addr) {
        0x0000 => {
            const old_v = self.control.v_generate_nmi;
            self.control = @bitCast(value);
            self.t = (self.t & 0x73FF) | (@as(u15, self.control.n_nametable_address) << 11); // TODO check if this is right
            if((self.control.v_generate_nmi == 1) and (old_v == 0) and (self.status.v_vblank == 1)) {
                // trigger cpu nmi
                self.bus.triggerNMI();
            }
        },
        0x0001 => { // set PPU mask
            self.mask = @bitCast(value);
        },
        0x0003 => { // set OAM address
            self.oam_addr = value;
        },
        0x0004 => {
            self.oam_data[self.oam_addr] = value;
            self.oam_addr +%= 1;
        },
        0x0005 => {
            if (self.w == 0) {
                // First write (X scroll)
                self.x = @truncate(value & 0x07);
                self.t = (self.t & 0x7FE0) | @as(u15, value >> 3);
            } else {
                // Second write (Y scroll)
                self.t = (self.t & 0x0FFF) | (@as(u15, value) & 0x07 << 12);
                self.t = (self.t & 0x7C1F) | (@as(u15, value) & 0x78 << 2);
            }
            self.w ^= 1;
        },
        0x0006 => { // loads high byte first, low byte after, so not little-endian
            if(self.w == 0) {
                self.t = (self.t & 0x00FF) | (@as(u15, value) << 8);
            } else {
                self.t = (self.t & 0x7F00) | @as(u15, value);
                self.v = self.t;
            }
            self.w +%= 1;
        },
        0x0007 => {
            self.ppu_bus.ppuWriteByte(@truncate(self.v), value);
            self.v +%= if(self.control.i_vram_addr_increment == 0) 1 else 32;
        },
        else => {
            return;
        },
    }
    return;
}

// this receives 256 bytes from the cpu's ram into the object attribut memory of the ppu
pub fn dmaCopy(self: *PPU, page_number: u8) void {
    @memcpy(self.oam_data[0..], self.bus.readRamPage(page_number));
}

pub fn render(self: *PPU) void {
    switch(self.scanline) {
        0...239 => { // visible scanlines 
            if (self.cycle >= 1 and self.cycle <= 256) {
                const x: usize = @intCast(self.cycle - 1);
                const y: usize = @intCast(self.scanline);
                const index = y * 256 + x;

                // Calculate the effective X and Y coordinates, taking scrolling into account
                const fine_x = self.x;
                const coarse_x = (self.v & 0x1F);
                const fine_y = (self.v >> 12) & 0x7;
                const coarse_y = (self.v >> 5) & 0x1F;
                
                const effective_x = (x + fine_x + (coarse_x << 3)) & 0xFF;
                const effective_y = (y + fine_y + (coarse_y << 3)) & 0xFF;

                // Calculate nametable address
                const base_nametable = 0x2000 | (self.v & 0x0C00);
                const nametable_x = effective_x >> 3;
                const nametable_y = effective_y >> 3;
                const nametable_index = (nametable_y << 5) + nametable_x;
                const nametable_addr = base_nametable + nametable_index;
                // Read the tile index from nametable
                const tile_index = self.ppu_bus.ppuReadByte(@truncate(nametable_addr));

                // Read tile data from pattern table
                const pattern_table_addr = if (self.control.b_background_pattern_table == 0) @as(u16, 0x0000) else @as(u16, 0x1000);
                const tile_addr = pattern_table_addr + @as(u16, tile_index) * 16;
                const tile_y: u3 = @truncate(effective_y & 0x07);
                const low_byte = self.ppu_bus.ppuReadByte(@truncate(tile_addr + tile_y));
                const high_byte = self.ppu_bus.ppuReadByte(@truncate(tile_addr + tile_y + 8));

                // Get the correct bit for this pixel
                const tile_x: u3 = @truncate(effective_x & 0x07);
                const pixel = ((high_byte >> (7 - tile_x)) & 1) << 1 | ((low_byte >> (7 - tile_x)) & 1);

                // Get the attribute byte for this 32x32 pixel area
                const attr_addr = (base_nametable + 0x3C0) + ((nametable_y >> 2) << 3) + (nametable_x >> 2);
                const attr_byte = self.ppu_bus.ppuReadByte(@truncate(attr_addr));

                // Determine which quadrant of the 32x32 pixel area we're in
                const quadrant: u3 = @truncate(((nametable_y & 0x02) << 1) | (nametable_x & 0x02));
                const palette_index = (attr_byte >> quadrant) & 0x03;

                // Use the palette to get the color from the system palette
                const color_addr = 0x3F00 + (@as(u15, palette_index) << 2) + pixel;
                const color_index = self.ppu_bus.ppuReadByte(@truncate(color_addr));
                const color: rl.Color = self.ppu_bus.system_palette[color_index];

                self.frame_buffer[index] = color;
            }
        },
        240 => { // post render line
            // idle scanline
        },
        241 => {
            if(self.cycle == 1) {
                self.frame_finished = true;
                self.frame +%= 1;
                self.status.v_vblank = 1;
                if(self.control.v_generate_nmi == 1) {
                    self.bus.triggerNMI();
                }
            }
        },
        242...260 => { // vblank period
            // No rendering during vblank
        },
        261 => { // pre-render scanline
            if(self.cycle == 1) {
                self.status.o_sprite_overflow = 0;
                self.status.s_sprite_zero_hit = 0;
                self.status.v_vblank = 0;
            }
        },
        else => {
            std.debug.print("Invalid scanline: {d}\n", .{self.scanline}); 
        },
    }
    // cycle increment logic (cycles are between 0 and 340)
    self.cycle += 1;
    if(self.cycle >= 341) { // wrap around to 0
        self.cycle = 0;
        self.scanline += 1;
        if (self.scanline == 261) {
            // At the start of the pre-render scanline, copy vertical scroll bits from t to v
            self.v = (self.v & 0x041F) | (self.t & 0x7BE0);
        }
    }
    if(self.scanline >= 262) { // wrap scanline around if it goes over 261
        self.scanline = 0;
        // self.frame_finished = false;
        // At the start of the frame, copy horizontal scroll bits from t to v
        self.v = (self.v & 0x7BE0) | (self.t & 0x041F);
    }
}
