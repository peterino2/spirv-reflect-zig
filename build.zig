// Copyright (c) peterino2@github.com

const std = @import("std");

// 1. for each vertex/fragment shader file invoke
//  glslc --target-env=vulkan1.2 <input file> -o <input file>.spv
//
// 2. for each generated .spv file i want to invoke
//  spirv-cross --reflect <input file>.spv --output <input file>.json
//
// 3. compile the reflect program, and invoke it on the json file.

pub const SpirvGenerator = struct {
    steps: std.ArrayList(*std.Build.Step),
    exe: *std.Build.Step.Compile,
    b: *std.Build,
    step: *std.Build.Step,
    repoPath: []const u8,
    glslTypes: *std.build.Module,

    pub fn init(
        b: *std.Build,
        opts: struct {
            target: std.zig.CrossTarget,
            optimize: std.builtin.Mode,
            repoPath: []const u8 = ".",
            addInstallStep: bool = true,
        },
    ) @This() {
        var mainPath = b.fmt("{s}/main.zig", .{opts.repoPath});
        var glslTypesPath = b.fmt("{s}/glslTypes.zig", .{opts.repoPath});

        const exe = b.addExecutable(.{
            .name = "spirv-reflect-zig",
            .root_source_file = .{ .path = mainPath },
            .target = opts.target,
            .optimize = opts.optimize,
        });

        var self = @This(){
            .b = b,
            .steps = std.ArrayList(*std.Build.Step).init(b.allocator),
            .exe = exe,
            .step = b.step("spirv", "compiles all glsl files into spirv binaries and generates .zig types"),
            .repoPath = opts.repoPath,
            .glslTypes = b.addModule("glslTypes", .{
                .source_file = .{ .path = glslTypesPath },
            }),
        };

        self.step.dependOn(&exe.step);

        if (opts.addInstallStep) {
            b.installArtifact(exe);
        }

        return self;
    }

    fn compileAndReflectGlsl(
        b: *std.Build,
        options: struct {
            source_file: std.Build.FileSource,
            output_name: []const u8,
            shaderCompilerCommand: []const []const u8, // default this is glslc --target-env=vulkan1.2
            shaderCompilerOutputFlag: []const u8, // in default, this is -o
        },
    ) struct {
        spv_out: std.Build.FileSource,
        json_out: std.Build.FileSource,
        step: *std.Build.Step,
    } {
        const finalSpv = b.fmt("reflectedTypes/{s}.spv", .{options.output_name});
        const finalJson = b.fmt("reflectedTypes/{s}.json", .{options.output_name});

        //const compileStep = b.addSystemCommand(&[_][]const u8{ "glslc", "--target-env=vulkan1.2" });
        for (options.shaderCompilerCommand) |cmd| {
            std.debug.print("\n{s}\n", .{cmd});
        }
        const compileStep = b.addSystemCommand(options.shaderCompilerCommand);
        compileStep.addFileSourceArg(options.source_file);
        compileStep.addArg(options.shaderCompilerOutputFlag);
        const spvOutputFile = compileStep.addOutputFileArg(finalSpv);

        const jsonReflectStep = b.addSystemCommand(&[_][]const u8{"spirv-cross"});
        jsonReflectStep.addFileSourceArg(spvOutputFile);
        jsonReflectStep.addArg("--reflect");
        jsonReflectStep.addArg("--output");
        const outputJson = jsonReflectStep.addOutputFileArg(finalJson);

        var reflect = b.allocator.create(std.Build.Step) catch unreachable;
        reflect.* = std.Build.Step.init(.{ .id = .custom, .name = options.output_name, .owner = b, .makeFn = make });
        reflect.dependOn(&b.addInstallFile(spvOutputFile, finalSpv).step);
        reflect.dependOn(&b.addInstallFile(outputJson, finalJson).step);

        reflect.dependOn(&jsonReflectStep.step);

        return .{
            .json_out = outputJson,
            .spv_out = spvOutputFile,
            .step = reflect,
        };
    }

    fn make(_: *std.Build.Step, _: *std.Progress.Node) !void {
        // just a no-op, not entirely sure how to make a custom step without
    }

    pub fn addShader(
        self: *@This(),
        options: struct {
            sourceFile: std.Build.FileSource,
            shaderName: []const u8,
            shaderCompilerCommand: []const []const u8,
            shaderCompilerOutputFlag: []const u8,
            embedFile: bool = false,
        },
    ) *std.Build.Module {
        var results = compileAndReflectGlsl(self.b, .{
            .source_file = options.sourceFile,
            .output_name = options.shaderName,
            .shaderCompilerCommand = options.shaderCompilerCommand,
            .shaderCompilerOutputFlag = options.shaderCompilerOutputFlag,
        });
        var b = self.b;

        var outputFile = b.fmt("reflectedTypes/{s}.zig", .{options.shaderName});
        const run_cmd = b.addRunArtifact(self.exe);

        run_cmd.addFileSourceArg(results.json_out);
        run_cmd.addArg("-o");
        const outputZigFile = run_cmd.addOutputFileArg(outputFile);

        if (options.embedFile) {
            var spvFile = b.fmt("{s}.spv", .{options.shaderName});
            run_cmd.addArg("-e");
            run_cmd.addArg(spvFile);
        }

        run_cmd.step.dependOn(&self.exe.step);
        self.step.dependOn(&run_cmd.step);
        self.step.dependOn(results.step);
        self.step.dependOn(&b.addInstallFile(outputZigFile, outputFile).step);

        var generatedFileRef = b.allocator.create(std.Build.GeneratedFile) catch unreachable;
        generatedFileRef.* = .{
            .step = self.step,
            .path = b.fmt("zig-out/{s}", .{outputFile}),
        };

        var dependencies = self.b.allocator.alloc(std.build.ModuleDependency, 1) catch unreachable;
        dependencies[0] = .{ .name = "glslTypes", .module = self.glslTypes };

        var module = b.addModule(options.shaderName, .{
            .source_file = .{ .generated = generatedFileRef },
            .dependencies = dependencies,
        });

        return module;
    }

    pub fn shader(
        self: *@This(),
        source: []const u8,
        shaderName: []const u8,
        opts: struct {
            shaderCompilerCommand: []const []const u8 = &.{ "glslc", "--target-env=vulkan1.2" },
            shaderCompilerOutputFlag: []const u8 = "-o",
            embedFile: bool = false,
        },
    ) *std.Build.Module {
        return self.addShader(.{
            .sourceFile = .{ .path = source },
            .shaderName = shaderName,
            .shaderCompilerCommand = opts.shaderCompilerCommand,
            .shaderCompilerOutputFlag = opts.shaderCompilerOutputFlag,
            .embedFile = opts.embedFile,
        });
    }
};

// Example build function.
//
// Run zig build run to run the example
//
// zig build install to generate the CLI tool.

pub fn build(b: *std.Build) void {
    var target = b.standardTargetOptions(.{});
    var optimize = b.standardOptimizeOption(.{});

    // ==== create the spirv compiler and generate both .spv files and .zig files ====
    var spirvCompile = SpirvGenerator.init(b, .{
        .target = target,
        .optimize = optimize,
        .repoPath = "src",
    });

    // This returns a module which contains the reflected.zig file which correct
    // data layout
    var test_vk = spirvCompile.shader("shaders/test_vk.vert", "test_vk", .{ .embedFile = true });
    // ===============================================================================

    // Create your executables as you normally would
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .path = "example.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("test_vk", test_vk);
    b.installArtifact(exe);

    var run_step = b.step("run", "runs my program");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_step.dependOn(&run_cmd.step);
}
