const std = @import ("std");
const toolbox = @import ("toolbox");
const pkg = .{ .name = "wayland.zig", .version = .{ .wayland = "1.22.0", .protocols = "1.33", }, };

const Paths = struct
{
  wayland: [] const u8 = undefined,
  tmp: [] const u8 = undefined,
  include: [] const u8 = undefined,
};

fn update_wayland (builder: *std.Build, path: *const Paths) !void
{
  const tmp_src_path = try std.fs.path.join (builder.allocator, &.{ path.tmp, "src", });
  const xml_path = try std.fs.path.join (builder.allocator, &.{ path.tmp, "protocol", "wayland.xml", });

  try toolbox.make (path.wayland);
  try toolbox.make (path.include);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone", "https://gitlab.freedesktop.org/wayland/wayland.git", path.tmp, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "-C", path.tmp, "checkout", pkg.version.wayland, }, });

  var tmp = try std.fs.openDirAbsolute (tmp_src_path, .{ .iterate = true, });
  defer tmp.close ();

  var it = tmp.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "wayland-client") or
      std.mem.startsWith (u8, entry.name, "wayland-server") or
      std.mem.startsWith (u8, entry.name, "wayland-util")) and
      !std.mem.endsWith (u8, entry.name, "private.h") and toolbox.is_header_file (entry.name) and entry.kind == .file)
        try toolbox.copy (try std.fs.path.join (builder.allocator, &.{ tmp_src_path, entry.name, }),
          try std.fs.path.join (builder.allocator, &.{ path.include, entry.name, }));
  }

  var wayland_version_h = try tmp.readFileAlloc (builder.allocator, "wayland-version.h.in", std.math.maxInt (usize));
  wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator, wayland_version_h, "@WAYLAND_VERSION@", pkg.version.wayland);

  var tokit = std.mem.tokenizeScalar (u8, pkg.version.wayland, '.');
  const match = [_][] const u8 { "@WAYLAND_VERSION_MAJOR@", "@WAYLAND_VERSION_MINOR@", "@WAYLAND_VERSION_MICRO@", };
  var index: usize = 0;
  while (tokit.next ()) |*token|
  {
    wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator, wayland_version_h, match [index], token.*);
    index += 1;
  }

  try toolbox.write (path.include, "wayland-version.h", wayland_version_h);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner", "server-header", xml_path, try std.fs.path.join (builder.allocator, &.{ path.include, "wayland-server-protocol.h", }), }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner", "client-header", xml_path, try std.fs.path.join (builder.allocator, &.{ path.include, "wayland-client-protocol.h", }), }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner", "private-code", xml_path, try std.fs.path.join (builder.allocator, &.{ path.include, "wayland-client-protocol-code.h", }), }, });

  try std.fs.deleteTreeAbsolute (path.tmp);
}

fn update_protocols (builder: *std.Build, path: *const Paths) !void
{
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone", "https://gitlab.freedesktop.org/wayland/wayland-protocols.git", path.tmp, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "-C", path.tmp, "checkout", pkg.version.protocols, }, });

  for ([_] struct { name: [] const u8, xml: [] const u8, }
    {
      .{ .name = "xdg-shell", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "stable", "xdg-shell", "xdg-shell.xml", }), },
      .{ .name = "xdg-decoration-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "unstable", "xdg-decoration", "xdg-decoration-unstable-v1.xml", }), },
      .{ .name = "viewporter", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "stable", "viewporter", "viewporter.xml", }), },
      .{ .name = "relative-pointer-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "unstable", "relative-pointer", "relative-pointer-unstable-v1.xml", }), },
      .{ .name = "pointer-constraints-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "unstable", "pointer-constraints", "pointer-constraints-unstable-v1.xml", }), },
      .{ .name = "fractional-scale-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "staging", "fractional-scale", "fractional-scale-v1.xml", }), },
      .{ .name = "xdg-activation-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "staging", "xdg-activation", "xdg-activation-v1.xml", }), },
      .{ .name = "idle-inhibit-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ path.tmp, "unstable", "idle-inhibit", "idle-inhibit-unstable-v1.xml", }), },
    }) |gen|
  {
    const protocol_h = try std.fmt.allocPrint (builder.allocator, "{s}-client-protocol.h", .{ gen.name, });
    const protocol_code_h = try std.fmt.allocPrint (builder.allocator, "{s}-client-protocol-code.h", .{ gen.name, });
    try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner", "client-header", gen.xml, try std.fs.path.join (builder.allocator, &.{ path.include, protocol_h, }), }, });
    try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner", "private-code", gen.xml, try std.fs.path.join (builder.allocator, &.{ path.include, protocol_code_h, }), }, });
  }

  try std.fs.deleteTreeAbsolute (path.tmp);
}

fn update (builder: *std.Build) !void
{
  var path: Paths = .{};
  path.wayland = try builder.build_root.join (builder.allocator, &.{ "wayland", });
  path.tmp = try std.fs.path.join (builder.allocator, &.{ path.wayland, "tmp", });
  path.include = try std.fs.path.join (builder.allocator, &.{ path.wayland, "include", });

  std.fs.deleteTreeAbsolute (path.wayland) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try update_wayland (builder, &path);
  try update_protocols (builder, &path);
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  if (builder.option (bool, "update", "Update binding") orelse false) try update (builder);

  const lib = builder.addStaticLibrary (.{
    .name = "wayland",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  std.debug.print ("[wayland headers dir] {s}\n", .{ try builder.build_root.join (builder.allocator, &.{ "wayland", "include", }), });
  lib.installHeadersDirectory (try std.fs.path.join (builder.allocator, &.{ "wayland", "include", }), ".");

  builder.installArtifact (lib);
}
