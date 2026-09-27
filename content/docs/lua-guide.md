---
title: Lua guide
description: connect scripts to events, hitobjects, drawables, and map time
order: 60
---

inso loads one Lua entry point per mapset. The script can react to playback, change hitobjects, create drawables, drive shaders, and build effects around the normal osu! map.

## connect a script

Point to a plain Lua filename from the map's `.inso` file:

```text
[General]
LuaEntryPoint: main.lua
```

The entry point must be a filename in the mapset folder. Paths containing `/`, `\`, or `:` are not accepted.

Callbacks are global functions. inso checks for them after loading the file, so a local function with the right name will not become an event handler.

## your first script

This script creates a textured drawable, attaches a small animation, and places it on the overlay:

```lua
function on_init()
    local pulse = Animation.new()
        :scale(0, 1, 1, 1, 1.1, 1.1, Tween.CUBIC_OUT)

    icon = Element.new("yuuma_toutetsu.png")
        :set_shader("oily")
        :set_animation(pulse)

    icon_drawable = Drawable.new(icon, 0, 999999, Layer.OVERLAY)
        :set_pos(256, 192)
        :set_size(96, 96)
end
```

Objects returned by `Drawable.new`, `Element.new`, and `Animation.new` are userdata references, and will be deleted by Lua's garbage collector if the reference goes out of scope (e.g. if a reference is declared as `local`). Keep a reference when the object needs to stay alive. Setters internally return `self`, so you can chain multiple calls, like in the example.

Animation times are normalized from `0` to `1` by default. Use `TimeDomain.MILLISECONDS` or `TimeDomain.MAP_MILLISECONDS` when the animation should follow a duration or an absolute map time.

Tip: to use elements from the current skin as drawables, prepend `skin:` to the element name and omit the file extension, e.g. `skin:hitcircle`

## events and time

The most useful callbacks are:

| callback | when it runs |
| --- | --- |
| `on_init()` | Once after the beatmap and script load, before play |
| `on_update(time_ms)` | Once per rendered frame |
| `on_fixed_update(time_ms)` | On a fixed music-time clock for deterministic simulation |
| `on_beat(beat)` | When playback crosses a beat |
| `on_timing_change(beat, bpm)` | When an uninherited timing point becomes active |
| `on_pause_change(paused)` | When playback pauses or resumes |
| `on_cursor_moved(x, y)` | When the cursor moves, with coordinates in playfield `osupx` space |
| `on_judgement(hitobject, judgement, timing_error_ms)` | When an object receives a judgement |
| `on_map_complete()` | When the last scoring object has been judged |

Use `on_update` for frame-based visual motion. Use `on_fixed_update` if you need simulation that should be reproducible across frame rates. Declaring `on_fixed_update` also moves scheduled callbacks onto the fixed clock.

The complete event list, signatures, and class reference are in the generated [Lua API reference](/docs/lua_api.html). `on_cursor_moved(x, y)` and `get_cursor_pos()` use playfield `osupx` coordinates. Convert screen pixels with `Window.px_to_osupx()` when needed.

## beat-driven visuals

Beatmap helpers expose timing values so effects can follow the current map instead of using a guessed bpm:

```lua
function on_beat(beat)
    if beat % 4 == 0 then
        icon_drawable:set_beat_pulse(true)
    end
end

function on_update(time_ms)
    local pulse = Beatmap.get_beat_proximity()
    icon_drawable:set_color(Color.rgba(255, 255, 255, 180 + pulse * 75))
end
```

`Beatmap.get_beat_proximity()` returns `1` on the beat and eases toward `0` before the next beat. `Beatmap.get_music_time_ms()`, `Beatmap.get_bpm()`, and `Beatmap.get_beat_length_ms()` are useful when the effect needs its own timing.

## scheduling map-time actions

Schedule actions in music time rather than in wall-clock seconds:

```lua
function on_init()
    schedule_at(5000, function()
        Beatmap.set_skin_override("gn")
        
        schedule_after(3000, function()
            Beatmap.clear_skin_override()
        end)
    end)
end
```

Events scheduled during `on_init` persist and replay when the editor seeks backward. Events scheduled from another callback are one-shot, and you must reload the map with `Ctrl+R` to have them reapply correctly. `schedule_event` is the named-event version, while `schedule_at` and `schedule_after` take functions directly.

## manipulating hitobjects

Query visible objects and use their base position when applying motion. `set_pos` is absolute, so reading `get_base_pos` prevents frame-by-frame offsets from accumulating:

```lua
function on_update(time_ms)
    for _, hitobject in ipairs(Hitobject.get_visible_incl_followpoints()) do
        local index = hitobject:get_index()
        local x, y = hitobject:get_base_pos()
        local angle = time_ms * 0.001 + index * 0.1

        hitobject:set_pos(
            x + math.cos(angle) * 12,
            y + math.sin(angle) * 12
        )
    end
end
```

Use `get_visible_incl_followpoints` when the motion should include objects whose followpoint line is visible before the object enters its own approach window. Hitobjects can also change size, timing windows, visibility, slider behavior, and custom drawables. Check the [Lua API reference](/docs/lua_api.html) for the full 

## reacting to judgements

Judgement callbacks can observe play results, while `validate_judgement` can replace them before they are committed:

```lua
function on_judgement(hitobject, judgement, timing_error_ms)
    if hitobject then
        print(hitobject:get_index(), judgement, timing_error_ms)
    end
end

function validate_judgement(hitobject, judgement, timing_error_ms)
    if hitobject and hitobject:has_any_bits(0x01) then
        return Judgement.IGNORED_HIT, timing_error_ms
    end
end
```

Return nothing from `validate_judgement` to keep the original result. It cannot cancel a judgement with `nil`; use `Judgement.IGNORED_HIT` when an object should not affect normal scoring.

## layers and post passes

Drawables use the built-in render layers. Scripts can declare custom layers positioned relative to one of them:

```lua
function on_init()
    fx_layer = Beatmap.add_layer("map_fx", {
        anchor = Layer.HITOBJECTS,
        above = true
    })

    fx = Element.new("effect.png")
    fx_drawable = Drawable.new(fx, 0, 999999, fx_layer)
end
```

Declare custom layers in `on_init`. `Beatmap.add_layer` returns a handle that can be passed anywhere a layer is accepted, like `Drawable.new`, `Beatmap.capture_layers`, and `Beatmap.add_post_pass`.

Post-processing uses named render targets from the `.inso` file:

```lua
function on_init()
    Beatmap.capture_layers("scene", {
        Layer.BACKGROUND,
        Layer.FOREGROUND,
        Layer.HITOBJECTS,
        Layer.UI,
        Layer.CURSOR
    })

    Beatmap.add_post_pass{
        shader = "crt",
        src = "scene",
        dst = "screen",
        after = Layer.TOP
    }
end
```

See the [Shader integration guide](shader-guide.md) for the matching GLSL interfaces, backbuffer setup, and render-target examples.

## split scripts into files

`load_file` loads another Lua file from the mapset folder and returns its result:

```lua
local random = load_file("rand.lua")

function on_init()
    print(random.next())
end
```

This is useful for keeping reusable helpers out of the entry point. The embedded runtime opens the base, table, string, and math libraries. `io`, `os`, `package`, and `debug` are not available to map scripts.

## runtime notes

- Scripts must be plain source files. Precompiled Lua bytecode is rejected.
- Each protected callback has a 1.000.000 instruction count limiter to stop infinite loops from hanging the game.
- Keep expensive work out of `on_update` when a scheduled event or fixed update is enough.
- Object declarations in events or callbacks other than `on_init` may lead to error spam when moving the playhead backwards.

The [Lua API reference](/docs/lua_api.html) is generated from the engine's registrations and is an exhaustive list of available classes, methods, enums, and callback signatures.
