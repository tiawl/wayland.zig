const std = @import ("std");
const toolbox = @import ("toolbox");

const Paths = struct
{
  // prefixed attributes
  __tmp: [] const u8 = undefined,
  __wayland: [] const u8 = undefined,

  // mandatory getters
  pub fn getTmp (self: @This ()) [] const u8 { return self.__tmp; }
  pub fn getWayland (self: @This ()) [] const u8 { return self.__wayland; }

  // mandatory init
  pub fn init (builder: *std.Build) !@This ()
  {
    var self = @This () {
      .__wayland = try builder.build_root.join (builder.allocator,
        &.{ "wayland", }),
    };

    self.__tmp = try std.fs.path.join (builder.allocator,
      &.{ self.getWayland (), "tmp", });

    return self;
  }
};

fn update_wayland (builder: *std.Build, path: *const Paths,
  dependencies: *const toolbox.Dependencies) !void
{
  const tmp_src_path =
    try std.fs.path.join (builder.allocator, &.{ path.getTmp (), "src", });
  const xml_path = try std.fs.path.join (builder.allocator,
    &.{ path.getTmp (), "protocol", "wayland.xml", });

  try toolbox.make (path.getWayland ());

  try dependencies.clone (builder, "wayland", path.getTmp ());

  var tmp_dir =
    try std.fs.openDirAbsolute (tmp_src_path, .{ .iterate = true, });
  defer tmp_dir.close ();

  var it = tmp_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "wayland-client") or
      std.mem.startsWith (u8, entry.name, "wayland-server") or
      std.mem.startsWith (u8, entry.name, "wayland-util")) and
      !std.mem.endsWith (u8, entry.name, "private.h") and
      toolbox.isCHeader (entry.name) and entry.kind == .file)
        try toolbox.copy (try std.fs.path.join (builder.allocator,
          &.{ tmp_src_path, entry.name, }), try std.fs.path.join (
            builder.allocator, &.{ path.getWayland (), entry.name, }));
  }

  const wayland_version = try toolbox.version (builder, "wayland");
  var wayland_version_h = try tmp_dir.readFileAlloc (
    builder.allocator, "wayland-version.h.in", std.math.maxInt (usize));
  wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator,
    wayland_version_h, "@WAYLAND_VERSION@", wayland_version);

  var tokit = std.mem.tokenizeScalar (u8, wayland_version, '.');
  const match = [_][] const u8 { "@WAYLAND_VERSION_MAJOR@",
    "@WAYLAND_VERSION_MINOR@", "@WAYLAND_VERSION_MICRO@", };
  var index: usize = 0;
  while (tokit.next ()) |*token|
  {
    wayland_version_h = try std.mem.replaceOwned (u8, builder.allocator,
      wayland_version_h, match [index], token.*);
    index += 1;
  }

  try toolbox.write (path.getWayland (), "wayland-version.h",
    wayland_version_h);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner",
    "server-header", xml_path, try std.fs.path.join (builder.allocator,
      &.{ path.getWayland (), "wayland-server-protocol.h", }), }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner",
    "client-header", xml_path, try std.fs.path.join (builder.allocator,
      &.{ path.getWayland (), "wayland-client-protocol.h", }), }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner",
    "private-code", xml_path, try std.fs.path.join (builder.allocator,
      &.{ path.getWayland (), "wayland-client-protocol-code.h", }), }, });

  try std.fs.deleteTreeAbsolute (path.getTmp ());
}

fn update_protocols (builder: *std.Build, path: *const Paths,
  dependencies: *const toolbox.Dependencies) !void
{
  try dependencies.clone (builder, "wayland-protocols", path.getTmp ());

  for ([_] struct { name: [] const u8, xml: [] const u8, }
    {
      .{ .name = "xdg-shell", .xml = try std.fs.path.join (builder.allocator,
        &.{ path.getTmp (), "stable", "xdg-shell", "xdg-shell.xml", }), },
      .{ .name = "xdg-decoration-unstable-v1", .xml = try std.fs.path.join (
        builder.allocator, &.{ path.getTmp (), "unstable", "xdg-decoration",
          "xdg-decoration-unstable-v1.xml", }), },
      .{ .name = "viewporter", .xml = try std.fs.path.join (builder.allocator,
        &.{ path.getTmp (), "stable", "viewporter", "viewporter.xml", }), },
      .{ .name = "relative-pointer-unstable-v1", .xml = try std.fs.path.join (
        builder.allocator, &.{ path.getTmp (), "unstable", "relative-pointer",
          "relative-pointer-unstable-v1.xml", }), },
      .{ .name = "pointer-constraints-unstable-v1", .xml =
        try std.fs.path.join (builder.allocator, &.{ path.getTmp (), "unstable",
          "pointer-constraints", "pointer-constraints-unstable-v1.xml", }), },
      .{ .name = "fractional-scale-v1", .xml = try std.fs.path.join (
        builder.allocator, &.{ path.getTmp (), "staging", "fractional-scale",
          "fractional-scale-v1.xml", }), },
      .{ .name = "xdg-activation-v1", .xml = try std.fs.path.join (
        builder.allocator, &.{ path.getTmp (), "staging", "xdg-activation",
          "xdg-activation-v1.xml", }), },
      .{ .name = "idle-inhibit-unstable-v1", .xml = try std.fs.path.join (
        builder.allocator, &.{ path.getTmp (), "unstable", "idle-inhibit",
          "idle-inhibit-unstable-v1.xml", }), },
    }) |gen|
  {
    const protocol_h = try std.fmt.allocPrint (
      builder.allocator, "{s}-client-protocol.h", .{ gen.name, });
    const protocol_code_h = try std.fmt.allocPrint (
      builder.allocator, "{s}-client-protocol-code.h", .{ gen.name, });
    try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner",
      "client-header", gen.xml, try std.fs.path.join (builder.allocator,
        &.{ path.getWayland (), protocol_h, }), }, });
    try toolbox.run (builder, .{ .argv = &[_][] const u8 { "wayland-scanner",
      "private-code", gen.xml, try std.fs.path.join (builder.allocator,
        &.{ path.getWayland (), protocol_code_h, }), }, });
  }

  try std.fs.deleteTreeAbsolute (path.getTmp ());
}

fn update (builder: *std.Build,
  dependencies: *const toolbox.Dependencies) !void
{
  const path = try Paths.init (builder);

  std.fs.deleteTreeAbsolute (path.getWayland ()) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try update_wayland (builder, &path, dependencies);
  try update_protocols (builder, &path, dependencies);

  try toolbox.clean (builder, &.{ "wayland", }, &.{});
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const dependencies = try toolbox.Dependencies.init (builder, "wayland.zig",
  &.{ "wayland", },
  .{
     .toolbox = .{
       .name = "tiawl/toolbox",
       .host = toolbox.Repository.Host.github,
     },
   }, .{
     .wayland = .{
       .name = "wayland/wayland",
       .host = toolbox.Repository.Host.gitlab,
     },
     .@"wayland-protocols" = .{
       .name = "wayland/wayland-protocols",
       .host = toolbox.Repository.Host.gitlab,
     },
   });

  if (builder.option (bool, "update", "Update binding") orelse false)
    try update (builder, &dependencies);

  const lib = builder.addStaticLibrary (.{
    .name = "wayland",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  toolbox.addHeader (lib, try builder.build_root.join (builder.allocator,
    &.{ "wayland", }), ".", &.{ ".h", });

  builder.installArtifact (lib);
}
