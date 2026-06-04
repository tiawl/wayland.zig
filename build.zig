const std = @import("std");
const build_zig_zon = @import("build.zig.zon");
const toolbox = @import("toolbox");
const VerboseBuilder = toolbox.VerboseBuilder;

fn updateWayland(pkg_builder: *VerboseBuilder) !void {
    const wayland_dep = pkg_builder.verboseDependency("wayland");
    var wayland_builder = VerboseBuilder.initFromDependency(wayland_dep);

    while (try wayland_builder.iterate(&.{"src"})) |entry| {
        switch (entry.kind) {
            .file => {
                if ((std.mem.startsWith(u8, entry.name, "wayland-client") or
                    std.mem.startsWith(u8, entry.name, "wayland-server") or
                    std.mem.startsWith(u8, entry.name, "wayland-util")) and
                    !std.mem.endsWith(u8, entry.name, "private.h") and
                    toolbox.isCHeader(entry.name) or toolbox.isCTemplate(entry.name))
                {
                    try pkg_builder.copy(&.{ "wayland", entry.name }, &wayland_builder, &.{ "src", entry.name });
                }
            },
            else => {},
        }
    }

    _ = try wayland_builder.run(&.{ "wayland-scanner", "server-header", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-server-protocol.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-server-protocol.h" }, &wayland_builder, &.{"wayland-server-protocol.h"});
    _ = try wayland_builder.run(&.{ "wayland-scanner", "client-header", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-client-protocol.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-client-protocol.h" }, &wayland_builder, &.{"wayland-client-protocol.h"});
    _ = try wayland_builder.run(&.{ "wayland-scanner", "private-code", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-client-protocol-code.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-client-protocol-code.h" }, &wayland_builder, &.{"wayland-client-protocol-code.h"});
}

fn updateWaylandProtocols(pkg_builder: *VerboseBuilder) !void {
    const wayland_protocols_dep = pkg_builder.dependency("wayland-protocols");
    var wayland_protocols_builder = VerboseBuilder.initFromDependency(wayland_protocols_dep);

    for ([_]struct {
        name: []const u8,
        xml: []const u8,
    }{
        .{ .name = "xdg-shell", .xml = pkg_builder.resolve(&.{ "stable", "xdg-shell", "xdg-shell.xml" }) },
        .{ .name = "xdg-decoration-unstable-v1", .xml = pkg_builder.resolve(&.{ "unstable", "xdg-decoration", "xdg-decoration-unstable-v1.xml" }) },
        .{ .name = "viewporter", .xml = pkg_builder.resolve(&.{ "stable", "viewporter", "viewporter.xml" }) },
        .{ .name = "relative-pointer-unstable-v1", .xml = pkg_builder.resolve(&.{ "unstable", "relative-pointer", "relative-pointer-unstable-v1.xml" }) },
        .{ .name = "pointer-constraints-unstable-v1", .xml = pkg_builder.resolve(&.{ "unstable", "pointer-constraints", "pointer-constraints-unstable-v1.xml" }) },
        .{ .name = "fractional-scale-v1", .xml = pkg_builder.resolve(&.{ "staging", "fractional-scale", "fractional-scale-v1.xml" }) },
        .{ .name = "xdg-activation-v1", .xml = pkg_builder.resolve(&.{ "staging", "xdg-activation", "xdg-activation-v1.xml" }) },
        .{ .name = "idle-inhibit-unstable-v1", .xml = pkg_builder.resolve(&.{ "unstable", "idle-inhibit", "idle-inhibit-unstable-v1.xml" }) },
    }) |gen| {
        const protocol_h = pkg_builder.fmt("{s}-client-protocol.h", .{gen.name});
        const protocol_code_h = pkg_builder.fmt("{s}-client-protocol-code.h", .{gen.name});
        _ = try wayland_protocols_builder.run(&.{ "wayland-scanner", "client-header", gen.xml, protocol_h }, wayland_protocols_builder.ptrCwd().*);
        try pkg_builder.copy(&.{ "wayland", protocol_h }, &wayland_protocols_builder, &.{protocol_h});
        _ = try wayland_protocols_builder.run(&.{ "wayland-scanner", "private-code", gen.xml, protocol_code_h }, wayland_protocols_builder.ptrCwd().*);
        try pkg_builder.copy(&.{ "wayland", protocol_code_h }, &wayland_protocols_builder, &.{protocol_code_h});
    }
}

fn updateFn(pkg_builder: *VerboseBuilder) !void {
    try pkg_builder.remove(&.{"wayland"});
    try pkg_builder.make(&.{"wayland"});

    try updateWayland(pkg_builder);
    try updateWaylandProtocols(pkg_builder);
}

fn buildFn(pkg_builder: *VerboseBuilder) !void {
    const lib = pkg_builder.addLibrary("wayland");

    while (try pkg_builder.walk(&.{"wayland"})) |*entry| {
        if (toolbox.isCHeader(entry.basename)) pkg_builder.installHeader(lib, &.{ "wayland", entry.path }, &.{entry.path});
    }
    const uri = try std.Uri.parse(build_zig_zon.dependencies.wayland.url);
    const wayland_version = pkg_builder.uriComponent(&uri.query.?)[4..];
    const wayland_version_sem = std.SemanticVersion.parse(wayland_version) catch unreachable;

    pkg_builder.generateConfigHeader(lib, &.{"wayland"}, &.{"wayland-version.h.in"}, .autoconf_at, .{
        .WAYLAND_VERSION = wayland_version,
        .WAYLAND_VERSION_MAJOR = @as(i64, @intCast(wayland_version_sem.major)),
        .WAYLAND_VERSION_MINOR = @as(i64, @intCast(wayland_version_sem.minor)),
        .WAYLAND_VERSION_MICRO = @as(i64, @intCast(wayland_version_sem.patch)),
    });

    pkg_builder.installArtifact(lib);
}

pub fn build(builder: *std.Build) !void {
    var pkg_builder = try VerboseBuilder.init(builder, @tagName(build_zig_zon.name), buildFn, updateFn);

    try pkg_builder.fetch(@TypeOf(build_zig_zon.dependencies), build_zig_zon.dependencies, pkg_builder.ptrCwd());
    try pkg_builder.update();
    try pkg_builder.build();
}
