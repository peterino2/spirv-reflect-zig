// Copyright (c) peterino2@github.com

const std = @import("std");

pub const vec2 = extern struct {
    x: f32,
    y: f32,
};

pub const vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    pad: f32,
};

pub const vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const mat4 = [4][4]f32;

pub const float = f32;

pub fn CheckFieldDetails(
    comptime T: type,
    comptime fieldName: []const u8,
    expectedOffset: usize,
    expectedSize: usize,
) void {
    const offset = @offsetOf(T, fieldName);
    const size = @sizeOf(@TypeOf(@field(std.mem.zeroes(T), fieldName)));
    if (offset != expectedOffset) {
        var msg = std.fmt.comptimePrint(
            "Unexpected field offset, {s} was expected at offset {d} but found at offset {d}",
            .{ fieldName, expectedOffset, offset },
        );
        @compileError(msg);
    }

    if (size != expectedSize) {
        var msg = std.fmt.comptimePrint(
            "Unexpected field size, '{s}' was expected with size {d} but found at size {d}",
            .{ fieldName, expectedSize, size },
        );
        @compileError(msg);
    }
}

pub fn ValidateGeneratedStruct(comptime T: type) void {
    for (@field(T, "FieldDetails")) |detail| {
        CheckFieldDetails(T, detail.name, detail.offset, detail.size);
    }
}

pub const FieldDetail = struct {
    name: []const u8,
    size: usize,
    offset: usize,
};
