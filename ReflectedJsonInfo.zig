const std = @import("std");

allocator: std.mem.Allocator,
fileName: []const u8,
name: []const u8,

typeIdNames: std.StringArrayHashMap([]const u8),
reflectedTypes: std.StringArrayHashMap(ReflectedTypeInfo),

pub const ReflectedField = struct {
    name: []const u8,
    typeName: []const u8,
    size: usize,
};

pub const ReflectedTypeInfo = struct {
    name: []const u8,
    field: std.ArrayList(ReflectedField),
};

pub fn reflect(allocator: std.mem.Allocator, fileName: []const u8, logicalName: []const u8) !@This() {
    var self = @This(){
        .allocator = allocator,
        .fileName = fileName,
        .name = logicalName,
        .typeIdNames = std.StringArrayHashMap([]const u8).init(allocator),
        .reflectedTypes = std.StringArrayHashMap(ReflectedTypeInfo).init(allocator),
    };

    var file = try std.fs.cwd().openFile(fileName, .{});
    const fileContents = try file.readToEndAlloc(allocator, 10000000);
    defer allocator.free(fileContents);

    var parser = std.json.Parser.init(allocator, .alloc_always);
    defer parser.deinit();
    var tree = try parser.parse(fileContents);
    var root = tree.root.object;
    defer tree.deinit();

    const typesRef = root.get("types").?.object;
    const entryPoints = root.get("entryPoints").?;
    const inputs = root.get("inputs").?;
    const ssbos = root.get("ssbos").?.array;

    for (typesRef.keys(), typesRef.values()) |k, v| {
        _ = k;
        const reflectedType = self.generateReflectedTypeInfo(v.object);
        std.debug.print("reflected type: {any}", .{reflectedType});
    }

    _ = entryPoints;
    _ = inputs;

    for (ssbos.items) |ssboObject| {
        std.debug.print("\nssbo {s} \n", .{ssboObject.object.get("name").?.string});
        ssboObject.dump();
    }

    return self;
}

fn generateReflectedTypeInfo(self: @This(), typeObject: std.json.ObjectMap) ReflectedTypeInfo {
    std.debug.print("\n>>> NAME {s}\n", .{typeObject.get("name").?.string});
    var info = ReflectedTypeInfo{
        .field = std.ArrayList(ReflectedField).init(self.allocator),
        .name = typeObject.get("name").?.string,
    };

    return info;
}

pub fn deinit(self: *@This()) void {
    _ = self;
}
