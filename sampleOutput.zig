// sample struct:
const gl = @import("glslTypes.zig");

const SampleTest = extern struct {
    imagePosition: gl.vec2,
    imageSize: gl.vec2,
    anchorPoint: gl.vec2,
    scale: gl.vec2,
    alpha: gl.float,
    pad0: [12]u8,
    baseColor: gl.vec4,
    zLevel: gl.float,

    pub const FieldDetails: []const gl.FieldDetail = &.{
        .{ .name = "imagePosition", .offset = 0, .size = 8 },
        .{ .name = "imageSize", .offset = 8, .size = 8 },
        .{ .name = "anchorPoint", .offset = 16, .size = 8 },
        .{ .name = "scale", .offset = 24, .size = 8 },
        .{ .name = "alpha", .offset = 32, .size = 4 },
        .{ .name = "baseColor", .offset = 48, .size = 16 },
        .{ .name = "zLevel", .offset = 64, .size = 4 },
    };
};

comptime {
    gl.ValidateGeneratedStruct(SampleTest);
}
