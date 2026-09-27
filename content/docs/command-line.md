---
title: command reference
description: available inso flags and edit mode keys
order: 40
---

The game accepts a small set of startup flags. Unknown flags are ignored, and there is no separate help flag.

## inso

| flag | effect |
| --- | --- |
| `--tournament [path]` | Starts the tournament client. An optional map or song folder path can be loaded at startup. |
| `--gen-lua-docs` | Regenerates `docs/lua_api.html` and exits. Run it from the inso folder so the output is written to the expected location. |
| `--disable-raw-input` | Disables raw input for the process. This can help when debugging with tools that do not handle raw input correctly. |

## edit mode keys

| key | action |
| --- | --- |
| `escape` / `space` | Pause or resume playback |
| `left` / `right` | Scrub backward or forward by one grid step |
| `ctrl+left` / `ctrl+right` | Jump to the previous or next bookmark |
| `ctrl+o` | Open a beatmap file |
| `ctrl+c` | Copy the playhead time in milliseconds |
| `ctrl+shift+c` | Copy the playhead as an osu-style `mm:ss:mmm` timestamp |
| `ctrl+v` | Jump to the `mm:ss:mmm` timestamp in the clipboard |
| `f5` | Enter play mode from the current playhead |
| `shift+f5` | Enter play mode from the first hitobject's preempt window |
| `r` | Soft reload the current beatmap |
| `shift+r` | Reload the beatmap and its assets |
| `z` | Jump to the first hitobject, or to the map start if already there |
| `home` | Reset playback rate to 1x |
| `pageup` / `pagedown` | Speed up or slow down playback |
| mouse scroll | Scrub along the beat grid |

The broadcaster used for synchronized play is documented in [tournament mode](lan-tournament.md).
