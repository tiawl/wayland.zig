const std = @import ("std");
const pkg = .{ .name = "wayland.zig", .version = "1.22.0", .protocols_version = "1.33", };

fn exec (builder: *std.Build, argv: [] const [] const u8) !void
{
  var stdout = std.ArrayList (u8).init (builder.allocator);
  var stderr = std.ArrayList (u8).init (builder.allocator);
  errdefer { stdout.deinit (); stderr.deinit (); }

  std.debug.print ("\x1b[35m[{s}]\x1b[0m\n", .{ try std.mem.join (builder.allocator, " ", argv), });

  var child = std.ChildProcess.init (argv, builder.allocator);

  child.stdin_behavior = .Ignore;
  child.stdout_behavior = .Pipe;
  child.stderr_behavior = .Pipe;

  try child.spawn ();
  try child.collectOutput (&stdout, &stderr, 1000);

  const term = try child.wait ();

  if (stdout.items.len > 0) std.debug.print ("{s}", .{ stdout.items });
  if (stderr.items.len > 0 and !std.meta.eql (term, std.ChildProcess.Term { .Exited = 0 })) std.debug.print ("\x1b[31m{s}\x1b[0m", .{ stderr.items });
  try std.testing.expectEqual (term, std.ChildProcess.Term { .Exited = 0 });
}

fn update (builder: *std.Build) !void
{
  const wayland_path = try builder.build_root.join (builder.allocator, &.{ "wayland", });
  const tmp_path = try std.fs.path.join (builder.allocator, &.{ wayland_path, "tmp", });
  const include_path = try std.fs.path.join (builder.allocator, &.{ wayland_path, "include", });
  const tmp_src_path = try std.fs.path.join (builder.allocator, &.{ tmp_path, "src", });
  const xml_path = try std.fs.path.join (builder.allocator, &.{ tmp_path, "protocol", "wayland.xml", });

  std.fs.deleteTreeAbsolute (wayland_path) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try std.fs.makeDirAbsolute (wayland_path);
  try std.fs.makeDirAbsolute (include_path);

  try exec (builder, &[_][] const u8 { "git", "clone", "https://gitlab.freedesktop.org/wayland/wayland.git", tmp_path, });
  try exec (builder, &[_][] const u8 { "git", "-C", tmp_path, "checkout", pkg.version, });

  var tmp = try std.fs.openDirAbsolute (tmp_src_path, .{ .iterate = true, });
  defer tmp.close ();

  var it = tmp.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "wayland-client") or
      std.mem.startsWith (u8, entry.name, "wayland-server") or
      std.mem.startsWith (u8, entry.name, "wayland-util")) and
      !std.mem.endsWith (u8, entry.name, "private.h") and std.mem.endsWith (u8, entry.name, ".h") and entry.kind == .file)
        try std.fs.copyFileAbsolute (try std.fs.path.join (builder.allocator, &.{ tmp_src_path, entry.name, }),
          try std.fs.path.join (builder.allocator, &.{ include_path, entry.name, }), .{});
  }

  var wayland_version_h = try tmp.readFileAlloc (builder.allocator, "wayland-version.h.in", std.math.maxInt (usize));
  wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator, wayland_version_h, "@WAYLAND_VERSION@", pkg.version);

  var tokit = std.mem.tokenizeScalar (u8, pkg.version, '.');
  const match = [_][] const u8 { "@WAYLAND_VERSION_MAJOR@", "@WAYLAND_VERSION_MINOR@", "@WAYLAND_VERSION_MICRO@", };
  var index: usize = 0;
  while (tokit.next ()) |*token|
  {
    wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator, wayland_version_h, match [index], token.*);
    index += 1;
  }

  var include = try std.fs.openDirAbsolute (include_path, .{});
  defer include.close ();
  try include.writeFile ("wayland-version.h", wayland_version_h);

  try exec (builder, &[_][] const u8 { "wayland-scanner", "server-header", xml_path, try std.fs.path.join (builder.allocator, &.{ include_path, "wayland-server-protocol.h", }), });
  try exec (builder, &[_][] const u8 { "wayland-scanner", "client-header", xml_path, try std.fs.path.join (builder.allocator, &.{ include_path, "wayland-client-protocol.h", }), });
  try exec (builder, &[_][] const u8 { "wayland-scanner", "private-code", xml_path, try std.fs.path.join (builder.allocator, &.{ include_path, "wayland-client-protocol-code.h", }), });

  try std.fs.deleteTreeAbsolute (tmp_path);

  try exec (builder, &[_][] const u8 { "git", "clone", "https://gitlab.freedesktop.org/wayland/wayland-protocols.git", tmp_path, });
  try exec (builder, &[_][] const u8 { "git", "-C", tmp_path, "checkout", pkg.protocols_version, });

  for ([_] struct { name: [] const u8, xml: [] const u8, }
    {
      .{ .name = "xdg-shell", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "stable", "xdg-shell", "xdg-shell.xml", }), },
      .{ .name = "viewporter", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "stable", "viewporter", "viewporter.xml", }), },
      .{ .name = "xdg-decoration", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "unstable", "xdg-decoration", "xdg-decoration-unstable-v1.xml", }), },
      .{ .name = "relative-pointer-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "unstable", "relative-pointer", "relative-pointer-unstable-v1.xml", }), },
      .{ .name = "pointer-constraints-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "unstable", "pointer-constraints", "pointer-constraints-unstable-v1.xml", }), },
      .{ .name = "idle-inhibit-unstable-v1", .xml = try std.fs.path.join (builder.allocator, &.{ tmp_path, "unstable", "idle-inhibit", "idle-inhibit-unstable-v1.xml", }), },
    }) |gen|
  {
    const protocol_h = try std.fmt.allocPrint (builder.allocator, "wayland-{s}-client-protocol.h", .{ gen.name, });
    const protocol_code_h = try std.fmt.allocPrint (builder.allocator, "wayland-{s}-client-protocol-code.h", .{ gen.name, });
    try exec (builder, &[_][] const u8 { "wayland-scanner", "client-header", gen.xml, try std.fs.path.join (builder.allocator, &.{ include_path, protocol_h, }), });
    try exec (builder, &[_][] const u8 { "wayland-scanner", "private-code", gen.xml, try std.fs.path.join (builder.allocator, &.{ include_path, protocol_code_h, }), });
  }

  try std.fs.deleteTreeAbsolute (tmp_path);
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

  std.debug.print ("[wayland headers dir] {s}\n", .{ try builder.build_root.join (builder.allocator, &.{ "wayland", "include" }), });
  lib.installHeadersDirectory (try std.fs.path.join (builder.allocator, &.{ "wayland", "include", }), ".");

  builder.installArtifact (lib);
}
