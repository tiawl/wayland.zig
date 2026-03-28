# wayland.zig

This is a fork of [hexops/wayland-headers][1] which itself gather various [Wayland][2] headers [GLFW][3] needs.

## Why this forkception ?

The intention under this fork is the same as [hexops][5] had when they opened their repository: gather [Wayland][2] headers and package them to compile [GLFW][3] with [Zig][4].

However this repository has subtle differences for maintainability tasks:
* No shell scripting,
* A cron runs every day to check [Wayland][2] repositories and other dependencies. Then it updates this repository if a new release is available.

## Dependencies

The [Zig][4] part of this package is relying on the latest [Zig][4] release (0.15.2) and will only be updated for the next one.
It you use a more recent [Zig][4] version, please consider the `zig-nightly` branch and `*-nightly` tags.

For other dependencies see [the build.zig.zon](https://github.com/tiawl/wayland.zig/blob/zig-stable/build.zig.zon)

## `zig build` options

These additional options have mainly been implemented for maintainability tasks but they maybe could be useful for edge usecases:
```
  -Dfetch   Update build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

This repository is not subject to a unique License:

The parts of this repository originated from this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is subject to the License restrictions their respective owners choosed. By design, the public domain code is incompatible with the License notion. In this case, the License prevails. So if you have any doubt about a file property, open an issue.**

[1]:https://github.com/hexops/wayland-headers
[2]:https://gitlab.freedesktop.org/wayland
[3]:https://github.com/glfw/glfw
[4]:https://codeberg.org/ziglang/zig
[5]:https://github.com/hexops
