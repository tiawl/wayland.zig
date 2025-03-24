const std = @import("std");
const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;

const Paths = struct {
    __tmp: []const u8,
    __wayland: []const u8,

    fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }

    fn getWayland(self: @This()) []const u8 {
        return self.__wayland;
    }

    fn init(toolbox: *Toolbox) !@This() {
        const wayland_path = try toolbox.buildRootJoin(&.{
            "wayland",
        });

        return .{
            .__wayland = wayland_path,
            .__tmp = toolbox.pathJoin(&.{
                wayland_path, "tmp",
            }),
        };
    }
};

fn update_wayland(toolbox: *Toolbox, path: *const Paths) !void {
    const tmp_src_path = toolbox.pathJoin(&.{
        path.getTmp(), "src",
    });
    const xml_path = toolbox.pathJoin(&.{
        path.getTmp(), "protocol", "wayland.xml",
    });

    try toolbox.make(path.getWayland());

    try toolbox.clone(.wayland, path.getTmp());

    var tmp_dir = try std.fs.openDirAbsolute(tmp_src_path, .{
        .iterate = true,
    });
    defer tmp_dir.close();

    var it = tmp_dir.iterate();
    while (try it.next()) |*entry| {
        if ((std.mem.startsWith(u8, entry.name, "wayland-client") or
            std.mem.startsWith(u8, entry.name, "wayland-server") or
            std.mem.startsWith(u8, entry.name, "wayland-util")) and
            !std.mem.endsWith(u8, entry.name, "private.h") and
            toolbox_pkg.isCHeader(entry.name) and entry.kind == .file)
        {
            try toolbox.copy(toolbox.pathJoin(&.{
                tmp_src_path, entry.name,
            }), toolbox.pathJoin(&.{
                path.getWayland(), entry.name,
            }));
        }
    }

    const wayland_version = try toolbox.reference(.wayland);
    var wayland_version_h = try tmp_dir.readFileAlloc(toolbox.getAllocator(), "wayland-version.h.in", std.math.maxInt(usize));
    wayland_version_h = try std.mem.replaceOwned(u8, toolbox.getAllocator(), wayland_version_h, "@WAYLAND_VERSION@", wayland_version);

    var tokit = std.mem.tokenizeScalar(u8, wayland_version, '.');
    const match = [_][]const u8{
        "@WAYLAND_VERSION_MAJOR@", "@WAYLAND_VERSION_MINOR@", "@WAYLAND_VERSION_MICRO@",
    };
    var index: usize = 0;
    while (tokit.next()) |*token| {
        wayland_version_h = try std.mem.replaceOwned(u8, toolbox.getAllocator(), wayland_version_h, match[index], token.*);
        index += 1;
    }

    try toolbox.write(path.getWayland(), "wayland-version.h", wayland_version_h);

    try toolbox.run(.{
        .argv = &[_][]const u8{
            "wayland-scanner", "server-header", xml_path, toolbox.pathJoin(&.{
                path.getWayland(), "wayland-server-protocol.h",
            }),
        },
    });
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "wayland-scanner", "client-header", xml_path, toolbox.pathJoin(&.{
                path.getWayland(), "wayland-client-protocol.h",
            }),
        },
    });
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "wayland-scanner", "private-code", xml_path, toolbox.pathJoin(&.{
                path.getWayland(), "wayland-client-protocol-code.h",
            }),
        },
    });

    try std.fs.deleteTreeAbsolute(path.getTmp());
}

fn update_protocols(toolbox: *Toolbox, path: *const Paths) !void {
    try toolbox.clone(.@"wayland-protocols", path.getTmp());

    for ([_]struct {
        name: []const u8,
        xml: []const u8,
    }{
        .{
            .name = "xdg-shell",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "stable", "xdg-shell", "xdg-shell.xml",
            }),
        },
        .{
            .name = "xdg-decoration-unstable-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "unstable", "xdg-decoration", "xdg-decoration-unstable-v1.xml",
            }),
        },
        .{
            .name = "viewporter",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "stable", "viewporter", "viewporter.xml",
            }),
        },
        .{
            .name = "relative-pointer-unstable-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "unstable", "relative-pointer", "relative-pointer-unstable-v1.xml",
            }),
        },
        .{
            .name = "pointer-constraints-unstable-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "unstable", "pointer-constraints", "pointer-constraints-unstable-v1.xml",
            }),
        },
        .{
            .name = "fractional-scale-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "staging", "fractional-scale", "fractional-scale-v1.xml",
            }),
        },
        .{
            .name = "xdg-activation-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "staging", "xdg-activation", "xdg-activation-v1.xml",
            }),
        },
        .{
            .name = "idle-inhibit-unstable-v1",
            .xml = toolbox.pathJoin(&.{
                path.getTmp(), "unstable", "idle-inhibit", "idle-inhibit-unstable-v1.xml",
            }),
        },
    }) |gen| {
        const protocol_h = toolbox.fmt("{s}-client-protocol.h", .{
            gen.name,
        });
        const protocol_code_h = toolbox.fmt("{s}-client-protocol-code.h", .{
            gen.name,
        });
        try toolbox.run(.{
            .argv = &[_][]const u8{
                "wayland-scanner", "client-header", gen.xml, toolbox.pathJoin(&.{
                    path.getWayland(), protocol_h,
                }),
            },
        });
        try toolbox.run(.{
            .argv = &[_][]const u8{
                "wayland-scanner", "private-code", gen.xml, toolbox.pathJoin(&.{
                    path.getWayland(), protocol_code_h,
                }),
            },
        });
    }

    try std.fs.deleteTreeAbsolute(path.getTmp());
}

fn update(toolbox: *Toolbox) !void {
    const path = try Paths.init(toolbox);

    std.fs.deleteTreeAbsolute(path.getWayland()) catch |err| {
        switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    };

    try update_wayland(toolbox, &path);
    try update_protocols(toolbox, &path);

    try toolbox.clean(&.{
        "wayland",
    }, &.{});
}

const FromZon = toolbox_pkg.Repositories(.{
    .toolbox,
});

const DuringExec = toolbox_pkg.Repositories(.{
    .wayland, .@"wayland-protocols",
});

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    var toolbox = try Toolbox.init(FromZon, DuringExec, builder, optimize, .wayland_zig, "0x879377398f3e6626", &.{
        "wayland",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = .github,
            .ref = .tag,
        },
    }, .{
        .wayland = .{
            .name = "wayland/wayland",
            .domain = "freedesktop.org",
            .host = .gitlab,
            .ref = .tag,
        },
        .@"wayland-protocols" = .{
            .name = "wayland/wayland-protocols",
            .domain = "freedesktop.org",
            .host = .gitlab,
            .ref = .tag,
        },
    });
    defer toolbox.deinit();

    if (toolbox.getUpdate()) try update(&toolbox);

    const lib = builder.addStaticLibrary(.{
        .name = "wayland",
        .root_source_file = builder.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    toolbox.addHeader(lib, try builder.build_root.join(builder.allocator, &.{
        "wayland",
    }), ".", &.{
        ".h",
    });

    builder.installArtifact(lib);
}
