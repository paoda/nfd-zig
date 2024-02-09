const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("nfd", .{ .root_source_file = .{ .path = "src/lib.zig" } });

    const lib = createStaticLibrary(b, .{
        .name = "nfd",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.linkLibrary(lib);

    var demo = b.addExecutable(.{
        .name = "nfd-demo",
        .root_source_file = .{ .path = "src/demo.zig" },
        .target = target,
        .optimize = optimize,
    });

    demo.root_module.addImport("nfd", mod);
    b.installArtifact(demo);

    const run_demo_cmd = b.addRunArtifact(demo);
    run_demo_cmd.step.dependOn(b.getInstallStep());

    const run_demo_step = b.step("run", "Run the demo");
    run_demo_step.dependOn(&run_demo_cmd.step);
}

fn createStaticLibrary(b: *std.Build, options: std.Build.StaticLibraryOptions) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(options);

    const cflags = [_][]const u8{"-Wall"};
    lib.addIncludePath(.{ .path = "nativefiledialog/src/include" });
    lib.addCSourceFile(.{ .file = .{ .path = "nativefiledialog/src/nfd_common.c" }, .flags = &cflags });

    switch (options.target.result.os.tag) {
        .macos => lib.addCSourceFile(.{ .file = .{ .path = "nativefiledialog/src/nfd_cocoa.m" }, .flags = &cflags }),
        .windows => lib.addCSourceFile(.{ .file = .{ .path = "nativefiledialog/src/nfd_win.cpp" }, .flags = &cflags }),
        .linux => lib.addCSourceFile(.{ .file = .{ .path = "nativefiledialog/src/nfd_gtk.c" }, .flags = &cflags }),
        else => @panic("unsupported OS "),
    }

    switch (options.target.result.os.tag) {
        .macos => lib.linkFramework("AppKit"),
        .windows => {
            lib.linkSystemLibrary("shell32");
            lib.linkSystemLibrary("ole32");
            lib.linkSystemLibrary("uuid"); // needed by MinGW
        },
        .linux => {
            lib.linkSystemLibrary("atk-1.0");
            lib.linkSystemLibrary("gdk-3");
            lib.linkSystemLibrary("gtk-3");
            lib.linkSystemLibrary("glib-2.0");
            lib.linkSystemLibrary("gobject-2.0");
        },
        else => @panic("unsupported OS"),
    }
    lib.installHeadersDirectory("nativefiledialog/src/include", ".");

    return lib;
}
