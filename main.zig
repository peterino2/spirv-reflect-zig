const std = @import("std");
const ReflectedJsonInfo = @import("ReflectedJsonInfo.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reflectedInfo = try ReflectedJsonInfo.reflect(allocator, "zig-out/test_vk.vert.json", "test_vk");
    reflectedInfo.deinit();

    std.debug.print("{d}\n", .{420});
}
