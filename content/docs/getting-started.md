---
title: getting started
description: install inso, open a map, and start authoring
order: 10
---

inso opens existing osu! beatmaps and adds Lua scripting, custom shaders, and map-specific assets. Start with a normal `.osu` map, then add the inso files you need.

## install inso

Download the [latest release](https://github.com/isakvik/inso/releases/latest) and extract it somewhere you can write to.

- On Windows, add maps to the `songs/` folder and run `inso.exe`.
- On Linux, install `libasound2` and make sure `libGL` and a supported graphics driver are available. Add maps to `songs/` and run `inso`.

Run inso from its extracted folder. The game looks for `songs/`, `skins/`, and `shaders/` relative to the working directory.

## open a map

Put a mapset directly under `songs/`. inso finds the `.osu` files in that folder and loads the rest of the mapset, including nested assets, when you open it.

Maps and skins outside the normal folders can be opened with the **open external** button below their dropdowns. Press `ctrl+f5` after adding files while inso is running to refresh the map and skin lists.

## map author workflow

Make the map in stable, open it in inso with **open external**, and keep the map folder open in your editor. Relevant changes are watched while the map is open: Lua scripts and shaders reload, while map and asset changes reopen the beatmap.

```text
songs/
  my-map/
    my-map.osu
    my-map.inso
    main.lua
    background.fs.glsl
    textures/
    audio/
```

The `.inso` file connects the map to its Lua entry point, shaders, render targets, and other resources. See the [inso file format](metadata.md), the [shader guide](shader-guide.md), and the [lua guide](lua-guide.md) to start integrating them.
