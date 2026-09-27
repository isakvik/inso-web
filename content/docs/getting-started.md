---
title: Getting started
description: how to install, run and map
order: 10
---

inso is a client with support for osu! beatmaps, but also adds Lua scripting and custom shaders as part of the asset pipeline.

## install inso

Download the [latest release](https://github.com/isakvik/inso/releases/latest) and extract it to its own folder.

- On Windows, add maps to the `songs/` folder and run `inso.exe`.
- On Linux, install `libasound2` and make sure `libGL` and a supported graphics driver are available. Add maps to `songs/` and run `inso`.

Run inso from its extracted folder. The game looks for `songs/`, `skins/`, and `shaders/` relative to the working directory. Songs and skins are discovered in these folders on startup and can be browsed in their dropdowns, but you can also refresh the lists at any time with `Ctrl+F5`.

Maps and skins outside the normal folders can be opened with the **open external** button below their dropdowns.

## map author workflow

Create a map in osu!stable, and open it in inso with **open external**. Any changes saved to the map or relevant assets while it's open in edit mode will be applied automatically, such as reloading Lua scripts, shaders or image/sound resources. File changes are not processed while the game is in play mode.

```text
songs/
  my-map/
    my-map.osu
    my-map.inso
    main.lua
    background.fs.glsl
    background.jpg
    normal-hitnormal.wav
```

The `.inso` file connects the map to its Lua entry point, shaders, render targets, and other resources. See the [.inso file format](inso-file-format.md), the [shader guide](shader-guide.md), and the [lua guide](lua-guide.md) for how to start integrating these.

Tip: when a map is open in osu!, you can copy (`Ctrl+C`) a circle in the osu! editor and paste it (`Ctrl+V`) in inso to jump to that object's time. Conversely, you can copy the playhead in inso as  with `Ctrl+Shift+C`, and in the osu!stable editor, click the playhead timer in the bottom left and paste the timestamp into the window. 

Also, you can copy the current ms time of the playhead in inso with `Ctrl+C`, which is useful for scripts and `.inso` metadata fields that use ms timing.
