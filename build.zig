const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = if (b.release_mode == .any) true else false,
        .single_threaded = true,
    });

    const exe = b.addExecutable(.{
        .name = "zacian",
        .root_module = exe_mod,
    });

    const build_stubs = b.option(bool, "stubs", "Build all assembly stubs") orelse false;
    if (build_stubs) {
        var stubs_dir = try std.fs.cwd().openDir("src/stubs", .{ .iterate = true, .access_sub_paths = false });
        defer stubs_dir.close();
        var stubs_dir_walker = try stubs_dir.walk(b.allocator);
        defer stubs_dir_walker.deinit();

        while (try stubs_dir_walker.next()) |dir_item| {
            if (dir_item.kind != .file) continue;

            const stub_file_path = b.pathJoin(&.{ "src/stubs/", dir_item.basename });

            const asm_mod = b.createModule(.{
                .target = target,
                .optimize = optimize,
            });
            asm_mod.addAssemblyFile(b.path(stub_file_path));

            const asm_obj_output_filename = b.fmt("{s}.o", .{dir_item.basename});
            const asm_obj = b.addObject(.{
                .name = asm_obj_output_filename,
                .root_module = asm_mod,
            });

            const asm_objcopy = b.addObjCopy(asm_obj.getEmittedBin(), .{
                .format = .bin,
                .only_section = ".text",
            });

            const stub_output_filename = b.fmt("{s}.bin", .{dir_item.basename});
            const objcopy_path = asm_objcopy.getOutput();
            const asm_objcopy_file = b.addInstallBinFile(objcopy_path, stub_output_filename);
            b.default_step.dependOn(&asm_objcopy_file.step);
        }
        return;
    }

    const lmap_dep = b.dependency("lmap", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("lmap", lmap_dep.module("lmap"));

    b.installArtifact(exe);
}
