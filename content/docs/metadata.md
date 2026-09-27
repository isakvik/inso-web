---
title: inso file format
description: configure map behavior with an .inso file
order: 20
---

An `.inso` file adds inso-specific behavior to an osu! mapset. It is a plain text file with colon-separated values and named entries. A mapset should contain one `.inso` file; if multiple files are present, a later file encountered while walking the mapset replaces the earlier configuration, and the walk order should not be relied on.

```text
inso file format v1

[General]
LuaEntryPoint: main.lua
Backbuffer: 1

[Shaders]
[[background]]
VertexShader: builtin.quad
FragmentShader: background.fs.glsl
BlendMode: Alpha
```

All sections are optional. Filenames and resource names are resolved from the mapset folder. The sections can be used together to build a scripted map, a post-processing chain, or a map that only changes gameplay settings. The `v1` preamble identifies this format for readers; current main does not use it to select parser behavior.

## general

| key | description |
| --- | --- |
| `LuaEntryPoint` | The Lua file to run for the map. Use a single filename such as `main.lua`; path separators and drive-prefix characters are rejected. |
| `BackgroundPipeline` | The shader pipeline used for the map background. |
| `DoubleMouse` | A non-zero value enables the special dual-mouse input mode. |
| `Backbuffer` | A non-zero value enables a full-frame backbuffer that can be sampled by post-processing passes. |
| `FixedUpdateRate` | The Lua fixed-update frequency in Hz. Values at or below zero use the default rate of 120 Hz. |

## force settings

`[ForceSettings]` applies selected user settings for the lifetime of the map. The user's own values are restored when the map closes and forced values are not written to `user.ini`.

| key | description |
| --- | --- |
| `window_mode` | `fullscreen`, `borderless_fullscreen`, or `windowed` |
| `bg_dim` | Background dim amount from `0` to `1` |
| `skin_path` | Skin folder to use. A folder relative to the mapset is accepted. |
| `playfield_border_opacity` | Playfield border opacity from `0` to `1` |
| `cursor_size_multiplier` | Positive cursor size multiplier |
| `snaking_in_sliders_enabled` | Enable or disable slider body snaking during approach |
| `snaking_out_sliders_enabled` | Enable or disable slider body retraction at the end of a slider |
| `hitsound_volume_follows_music` | Enable or disable hitsound volume following the music volume |

Boolean values are written as `1`, `true`, `0`, or `false`.

## shaders

Each `[[name]]` entry declares a pipeline that scripts can use by name. Shader paths are relative to the mapset unless they name a built-in shader.

| key | description |
| --- | --- |
| `VertexShader` | Vertex shader filename or `builtin.quad`, `builtin.slider`, or `builtin.text` |
| `FragmentShader` | Fragment shader filename or `builtin.quad`, `builtin.slider`, `builtin.slider_present`, or `builtin.text` |
| `BlendMode` | `None`, `Alpha`, `Additive`, `Max`, `Premultiplied`, or `PremultipliedOver` |
| `DepthWrite` | Depth writes are disabled by default. Set this to a non-zero value to enable them. |

## buffers

Each named buffer can load a file-backed model or allocate a writable buffer. `Source` takes precedence when both keys are present.

```text
[Buffers]
[[my_model]]
Source: crate.gltf

[[scratch]]
Size: 4096
```

`Size` is measured in bytes. Buffers can then be referenced from Lua and custom shaders.

## render targets

Render targets provide named off-screen textures for custom drawables and post-processing.

| key | values |
| --- | --- |
| `Format` | `rgba8` or `rgba16f`. The default is `rgba8`. |
| `Filter` | `linear` or `nearest`. The default is `linear`. |
| `Size` | `N%` tracks the window size, while `WxH` creates a fixed-size target. |
| `Scale` | Legacy scale value. Prefer `Size: N%` for new maps. |
| `Depth` | Depth is disabled by default. Set this to a non-zero value to enable it. |
| `ClearEveryFrame` | The target is cleared every frame unless the value is `0`. |

The reserved `backbuffer` and `screen` targets are available to post-processing passes when `Backbuffer: 1` is enabled.

## hitobject extra bits

Assign script-readable bit flags to hitobjects by their exact start time:

```text
[HitObjectExtraBits]
1000,0x01
1500,0b1010
2000,4
```

Values can be decimal, hexadecimal, or binary. When multiple hitobjects share a start time, the timestamp lookup selects the first one. Repeated rows for the same timestamp overwrite that selected object's mask. Lua filtering safely supports up to 53 bits because every Lua number literal becomes a floating point number.
