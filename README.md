# wayland.zig

This is a fork of [hexops/wayland-headers](https://github.com/hexops/wayland-headers) which itself gather various Wayland headers needed to GLFW.

## Why this fork ?

The intention under this fork is the same as hexops had when they opened their repository: gather Wayland headers and package them for Zig.
However this repository has subtle differences for maintainability tasks:
* no shell scripting,
* a cron is triggered every day to check Wayland repositories and to update this repository if a new release is available on one of them.

You can find the repositories' versions used here:
* [wayland/wayland](https://github.com/tiawl/wayland.zig/blob/trunk/.versions/wayland)
* [wayland/wayland-protocols](https://github.com/tiawl/wayland.zig/blob/trunk/.versions/wayland-protocols)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/glfw.zig](https://github.com/tiawl/glfw.zig)

This repository is automatically updated when a new release is available from these repositories:
* [wayland/wayland](https://gitlab.freedesktop.org/wayland/wayland)
* [wayland/wayland-protocols](https://gitlab.freedesktop.org/wayland/wayland-protocols)
* [tiawl/toolbox](https://github.com/tiawl/toolbox)
* [tiawl/spaceporn-dep-action-bot](https://github.com/tiawl/spaceporn-dep-action-bot)
* [tiawl/spaceporn-dep-action-ci](https://github.com/tiawl/spaceporn-dep-action-ci)
* [tiawl/spaceporn-dep-action-cd-ping](https://github.com/tiawl/spaceporn-dep-action-cd-ping)
* [tiawl/spaceporn-dep-action-cd-pong](https://github.com/tiawl/spaceporn-dep-action-cd-pong)

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .versions folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```
