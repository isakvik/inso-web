---
title: Command reference
description: available inso flags and edit mode keys
order: 40
---

The game accepts a small set of startup flags. Unknown flags are ignored, and there is no separate help flag.

## inso

| flag | effect |
| --- | --- |
| `--tournament <path>` | Open in tournament mode with the map or song folder at `<path>`. The path is required. |
| `--gen-lua-docs` | Regenerates `docs/lua_api.html` and exits. Run it from the inso folder so the output is written to the expected location. |
| `--disable-raw-input` | Disables raw input for the process. NVIDIA Nsight fails when raw input is enabled. |

## edit mode keys

| key | action |
| --- | --- |
| `escape` / `space` | Pause or resume playback |
| `left` / `right` | Scrub backward or forward by one grid step (1/4 beat at the current timing point) |
| `ctrl+left` / `ctrl+right` | Jump to the previous or next bookmark |
| `ctrl+o` | Open a beatmap |
| `ctrl+c` | Copy the playhead time in milliseconds |
| `ctrl+shift+c` | Copy the playhead as an osu-style `mm:ss:mmm` timestamp |
| `ctrl+v` | Jump to the `mm:ss:mmm` timestamp in the clipboard |
| `f5` | Enter play mode from the current playhead |
| `shift+f5` | Enter play mode from the first hitobject's preempt window |
| `r` | Soft reload the current beatmap |
| `shift+r` | Reload the beatmap and its assets |
| `z` | Jump to the first hitobject, or to the map start if already there |
| `home` | Reset playback rate to 1x |
| `pageup` / `pagedown` | Speed up or slow down playback in 1.5x steps |
| mouse scroll | Scrub along the beat grid; scroll up moves backward |

The broadcaster used for synchronized play is documented in [Tournament mode](lan-tournament.md).
