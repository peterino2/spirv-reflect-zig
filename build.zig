const std = @import("std");

// 1. for each vertex/fragment shader file invoke
//  glslc --target-env=vulkan1.2 <input file> -o <input file>.spv
// 2. for each generated .spv file i want to invoke
//  spirv-cross --reflect <input file>.spv --output <input file>.json
//
// 3. compile the reflect program, and invoke it on the json file.

pub fn compileAndReflectGlsl(
    b: *std.Build,
    options: struct {
        source_file: std.Build.FileSource,
        output_name: []const u8,
    },
) std.Build.FileSource {
    const finalSpv = b.fmt("{s}.spv", .{options.output_name});
    const finalJson = b.fmt("{s}.json", .{options.output_name});

    const compileStep = b.addSystemCommand(&[_][]const u8{ "glslc", "--target-env=vulkan1.2" });
    compileStep.addFileSourceArg(options.source_file);
    compileStep.addArg("-o");
    const spvOutputFile = compileStep.addOutputFileArg(finalSpv);

    const jsonReflectStep = b.addSystemCommand(&[_][]const u8{"spirv-cross"});
    jsonReflectStep.addFileSourceArg(spvOutputFile);
    jsonReflectStep.addArg("--reflect");
    jsonReflectStep.addArg("--output");
    const outputJson = jsonReflectStep.addOutputFileArg(finalJson);

    b.getInstallStep().dependOn(&b.addInstallFile(spvOutputFile, finalSpv).step);
    b.getInstallStep().dependOn(&b.addInstallFile(outputJson, finalJson).step);

    return outputJson;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "spirv-reflect-zig",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "runs the test executable");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    _ = compileAndReflectGlsl(b, .{ .source_file = .{ .path = "test_shaders/test_vk.vert" }, .output_name = "test_vk.vert" });
}
