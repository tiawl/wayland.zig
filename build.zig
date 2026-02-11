const std = @import("std");
const build_zig_zon = @import("build.zig.zon");
const toolbox = @import("toolbox");
const VerboseBuilder = toolbox.VerboseBuilder;

fn update_wayland(pkg_builder: *VerboseBuilder) !void {
    const wayland_dep = pkg_builder.dependency("wayland");
    var wayland_builder = VerboseBuilder.initFromDependency(wayland_dep);

    while (try wayland_builder.iterate(&.{"src"})) |entry| {
        switch (entry.kind) {
            .file => {
                if ((std.mem.startsWith(u8, entry.name, "wayland-client") or
                    std.mem.startsWith(u8, entry.name, "wayland-server") or
                    std.mem.startsWith(u8, entry.name, "wayland-util")) and
                    !std.mem.endsWith(u8, entry.name, "private.h") and
                    toolbox.isCHeader(entry.name))
                {
                    try pkg_builder.copy(&.{ "wayland", entry.name }, &wayland_builder, &.{ "src", entry.name });
                }
            },
            else => {},
        }
    }

    var wayland_version_h = try wayland_builder.readFile(&.{ "src", "wayland-version.h.in" });

    const uri = try std.Uri.parse(build_zig_zon.dependencies.wayland.url);
    const wayland_version = pkg_builder.uriComponent(&uri.query.?)[4..];

    wayland_version_h = pkg_builder.replace(wayland_version_h, "@WAYLAND_VERSION@", wayland_version);

    var it = std.mem.tokenizeScalar(u8, wayland_version, '.');
    var token = it.next().?;
    wayland_version_h = pkg_builder.replace(wayland_version_h, "@WAYLAND_VERSION_MAJOR@", token);
    token = it.next().?;
    wayland_version_h = pkg_builder.replace(wayland_version_h, "@WAYLAND_VERSION_MINOR@", token);
    token = it.next().?;
    wayland_version_h = pkg_builder.replace(wayland_version_h, "@WAYLAND_VERSION_MICRO@", token);

    try pkg_builder.writeFile(&.{ "wayland", "wayland-version.h" }, wayland_version_h);

    _ = try wayland_builder.run(&.{ "wayland-scanner", "server-header", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-server-protocol.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-server-protocol.h" }, &wayland_builder, &.{"wayland-server-protocol.h"});
    _ = try wayland_builder.run(&.{ "wayland-scanner", "client-header", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-client-protocol.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-client-protocol.h" }, &wayland_builder, &.{"wayland-client-protocol.h"});
    _ = try wayland_builder.run(&.{ "wayland-scanner", "private-code", pkg_builder.resolve(&.{ "protocol", "wayland.xml" }), "wayland-client-protocol-code.h" }, wayland_builder.ptrCwd().*);
    try pkg_builder.copy(&.{ "wayland", "wayland-client-protocol-code.h" }, &wayland_builder, &.{"wayland-client-protocol-code.h"});
}

fn update_protocols(pkg_builder: *VerboseBuilder) !void {
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

    try update_wayland(pkg_builder);
    try update_protocols(pkg_builder);
}

fn buildFn(pkg_builder: *VerboseBuilder) !void {
    const lib = pkg_builder.addLibrary("wayland");

    pkg_builder.installHeaders(lib, &.{"wayland"}, ".", &toolbox.ext.c.header);

    pkg_builder.installArtifact(lib);
}

pub fn build(builder: *std.Build) !void {
    var pkg_builder = try VerboseBuilder.init(builder, build_zig_zon, buildFn, updateFn);

    try pkg_builder.fetch(build_zig_zon);
    try pkg_builder.update();
    try pkg_builder.build();
}
