pub const packages = struct {
    pub const @"122002d98ca255ec706ef8e5497b3723d6c6e163511761d116dac3aee87747d46cf1" = struct {
        pub const build_root = "/home/lulvz/.cache/zig/p/122002d98ca255ec706ef8e5497b3723d6c6e163511761d116dac3aee87747d46cf1";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"12206dbd1510ce7e5270c725f980ca3a5ff3db47adeeda8d51ebe8527d6b27dd60a8" = struct {
        pub const build_root = "/home/lulvz/.cache/zig/p/12206dbd1510ce7e5270c725f980ca3a5ff3db47adeeda8d51ebe8527d6b27dd60a8";
        pub const build_zig = @import("12206dbd1510ce7e5270c725f980ca3a5ff3db47adeeda8d51ebe8527d6b27dd60a8");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "raylib", "1220f655fd57d8e10b5dbe7d99c45a0b9836a13cea085d75cd4c15f6e603a1fcb058" },
            .{ "raygui", "122002d98ca255ec706ef8e5497b3723d6c6e163511761d116dac3aee87747d46cf1" },
        };
    };
    pub const @"1220f655fd57d8e10b5dbe7d99c45a0b9836a13cea085d75cd4c15f6e603a1fcb058" = struct {
        pub const build_root = "/home/lulvz/.cache/zig/p/1220f655fd57d8e10b5dbe7d99c45a0b9836a13cea085d75cd4c15f6e603a1fcb058";
        pub const build_zig = @import("1220f655fd57d8e10b5dbe7d99c45a0b9836a13cea085d75cd4c15f6e603a1fcb058");
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "raylib-zig", "12206dbd1510ce7e5270c725f980ca3a5ff3db47adeeda8d51ebe8527d6b27dd60a8" },
};
