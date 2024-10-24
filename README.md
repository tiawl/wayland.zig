# wayland.zig

This is a fork of [hexops/wayland-headers][1] which itself gather various [Wayland][2] headers [GLFW][3] needs.

## Why this forkception ?

The intention under this fork is the same as [hexops][13] had when they opened their repository: gather [Wayland][2] headers and package them to compile [GLFW][3] with [Zig][4].

However this repository has subtle differences for maintainability tasks:
* No shell scripting,
* A cron runs every day to check [Wayland][2] repositories. Then it updates this repository if a new release is available.

## How to use it

The current usage of this repository is centered around [tiawl/glfw.zig][3] compilation. But you could use it for your own projects. Headers are here and there are no planned evolution to modify them. See [tiawl/glfw.zig][3] to see how you can use it. Maybe for your own need, some headers are missing. If it happens, open an issue: this repository is open to potential usage evolution.

## Dependencies

The [Zig][4] part of this package is relying on the latest [Zig][4] release (0.13.0) and will only be updated for the next one (so for the 0.14.0).

Here the repositories' version used by this fork:
* [wayland/wayland](https://github.com/tiawl/wayland.zig/blob/trunk/.references/wayland)
* [wayland/wayland-protocols](https://github.com/tiawl/wayland.zig/blob/trunk/.references/wayland-protocols)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/glfw.zig][5]

This repository is automatically updated when a new release is available from these repositories:
* [wayland/wayland][6]
* [wayland/wayland-protocols][7]
* [tiawl/toolbox][8]
* [tiawl/spaceporn-action-bot][9]
* [tiawl/spaceporn-action-ci][10]
* [tiawl/spaceporn-action-cd-ping][11]
* [tiawl/spaceporn-action-cd-pong][12]

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .references folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

The unprotected parts of this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is not dedicated to the public domain. I can not remove any license restriction their respective owners choosed. If you have any doubt about a file property, open an issue.**

[1]:https://github.com/hexops/wayland-headers
[2]:https://gitlab.freedesktop.org/wayland
[3]:https://github.com/glfw/glfw
[4]:https://github.com/ziglang/zig
[5]:https://github.com/tiawl/glfw.zig
[6]:https://gitlab.freedesktop.org/wayland/wayland
[7]:https://gitlab.freedesktop.org/wayland/wayland-protocols
[8]:https://github.com/tiawl/toolbox
[9]:https://github.com/tiawl/spaceporn-action-bot
[10]:https://github.com/tiawl/spaceporn-action-ci
[11]:https://github.com/tiawl/spaceporn-action-cd-ping
[12]:https://github.com/tiawl/spaceporn-action-cd-pong
[13]:https://github.com/hexops
