---
title: Shader guide
description: register pipelines, draw custom effects, and build post-processing
order: 50
---

Custom shaders are map resources. Declare a pipeline in the `.inso` file, then select it from Lua or attach it to a post-processing pass.

## the integration loop

Declare a named shader pipeline in the [inso metadata](inso-file-format.md#shaders) and add your shaders by filename to it. Any `Element`, `Drawable`, or post pass can then refer to that pipeline by name (string key).

Shader files and map assets are watched while a map is open in editor or waiting mode, so any edit is picked up and reloaded automatically. Any errors found during shader compile will be printed as a notification in-game, but will continue running with the last working version of that shader.

## a first quad shader

The built-in quad vertex shader already creates a quad, applies transforms, and passes texture coordinates to the fragment shader. Start by registering a fragment shader with `builtin.quad`:

```text
[General]
LuaEntryPoint: main.lua

[Shaders]
[[wave]]
VertexShader: builtin.quad
FragmentShader: wave.fs.glsl
BlendMode: Alpha
```

Example fragment shader that tints a map texture with a moving wave:

```glsl
#version 460
#ifdef BINDLESS
#extension GL_ARB_bindless_texture : require

layout(binding = 4, std430) readonly buffer textureHandles {
    sampler2DArray textures[];
};
#else
uniform sampler2DArray textures[16];
#endif

layout(std140, binding = 3) uniform globalData {
    mat3 t;
    mat3 playfieldTransform;
    float time;
    float circleSizeOsupx;
    vec2 cursorPos;
    vec2 resolution;
};

in vec3 uv;
in vec4 color;
flat in uint texIndex;

out vec4 frag_color;

void main() {
    vec4 base = texture(textures[texIndex], uv) * color;
    float wave = 0.5 + 0.5 * sin(uv.y * 40.0 + time * 0.004);
    frag_color = base * vec4(0.8 + wave * 0.2, 0.9, 1.0, 1.0);
}
```

The bindless and non-bindless branches are both required. inso tries the bindless variant when the graphics driver supports it and falls back to the array of sampler uniforms otherwise. Some integrated GPUs disable bindless up front, so the non-bindless branch should remain valid even when the shader was authored on a discrete GPU.

You can then set up a Drawable Lua-side and apply the shader to it:

```lua
function on_init()
    local image = Element.new("background.png")
        :set_shader("wave")

    Drawable.new(image, 0, 999999, Layer.BACKGROUND)
        :set_fullscreen(true)
end
```

`Element.new()` without a texture creates a white quad. Use a mapset texture name when the shader should process an image. `set_fullscreen` makes the drawable track the render target size.

## engine-provided inputs

The global uniform block is bound at `3`. The most useful values for ordinary effects are music time, cursor position, and the current window resolution:

```glsl
layout(std140, binding = 3) uniform globalData {
    mat3 t;
    mat3 playfieldTransform;
    float time;
    float circleSizeOsupx;
    vec2 cursorPos;
    vec2 resolution;
};
```

| value | meaning |
| --- | --- |
| `time` | Current music time in milliseconds |
| `cursorPos` | Cursor position in window pixel coordinates, in the same space as `resolution` |
| `resolution` | Window size in pixels |
| `playfieldTransform` | The current playfield transform matrix |

## parameters from lua

`Shader.set_param` writes one of 64 shared float slots. `Shader.set_vec4` writes one of 16 shared vector slots. The buffer is shared by every shader, so reserve indices for each effect instead of letting unrelated effects overwrite each other.

```glsl
layout(std140, binding = 7) uniform UserParams {
    vec4 params[16];
};

#define INTENSITY params[0].x

void main() {
    vec4 base = texture(textures[texIndex], uv) * color;
    frag_color = vec4(base.rgb * INTENSITY, base.a);
}
```

```lua
function on_init()
    Shader.set_param(0, 0.75)
    Shader.set_vec4(1, 1.0, 0.4, 0.2, 1.0)
end
```

Float index `13` is stored in `params[3].y`, for example. Use `index / 4` for the vector and `index % 4` for its component when mapping individual float slots.

## post-processing

Post passes are fullscreen draws that sample a render target and write to another one. Capture the layers you want, declare the intermediate targets, then set up the dependency graph from `on_init`.

```text
[General]
LuaEntryPoint: main.lua
Backbuffer: 1

[Shaders]
[[blur]]
VertexShader: builtin.quad
FragmentShader: blur.fs.glsl
BlendMode: None

[[present]]
VertexShader: builtin.quad
FragmentShader: present.fs.glsl
BlendMode: None

[RenderTargets]
[[blurred]]
Size: 50%
```

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
        shader = "blur",
        src = "scene",
        dst = "blurred",
        after = Layer.TOP
    }

    Beatmap.add_post_pass{
        shader = "present",
        src = "blurred",
        dst = "screen",
        after = Layer.TOP
    }
end
```

A post shader reads the source slots through the block at binding `14`:

```glsl
layout(std140, binding = 14) uniform PostParams {
    uvec4 srcSlots;
};
```

`srcSlots.x` is the first source, `srcSlots.y` is the second, and so on. A pass can receive up to four sources. `backbuffer` is the full-frame capture and requires `Backbuffer: 1`; `screen` is the real window destination.

Post passes should normally run after `Layer.TOP`. The platform layer is reserved for overlays that must stay above the post-processed image.

## custom mesh shaders

Mesh shaders use a model buffer instead of the quad batch. Declare the model and a depth-enabled target in the map file:

```text
[Shaders]
[[mesh]]
VertexShader: mesh.vs.glsl
FragmentShader: mesh.fs.glsl
DepthWrite: 1

[Buffers]
[[my_model]]
Source: crate.gltf

[RenderTargets]
[[mesh_scene]]
Depth: 1
```

Attach the buffer and target to an element, then composite the target back into the normal 2d layers:

```lua
function on_init()
    local model = Element.new()
        :set_shader("mesh")
        :set_mesh("my_model")
        :set_render_target("mesh_scene")

    Drawable.new(model, 0, 999999, Layer.FOREGROUND)

    local composite = Element.new()
        :set_tex("mesh_scene")

    Drawable.new(composite, 0, 999999, Layer.OVERLAY)
        :set_fullscreen(true)
end
```

2d quads use a flat depth plane, so a 3d mesh should render into its own depth-cleared target instead of competing with the normal playfield depth buffer. Mesh vertices must match the packed buffer layout used by the loader: eight scalar values per vertex in `position.xyz`, `normal.xyz`, `uv.xy` order.

## validate before sharing

Custom shaders that compile on one GPU can still fail elsewhere. Run the bundled validator against the map directory:

```text
build/validate_shaders songs
```

The validator checks the declared shader pairs with and without bindless textures. Before shipping a map:

- Keep uniform values in ordinary variables, not `const` initializers.
- Do not call `textureSize`, `imageSize`, or similar query functions on bindless samplers. Pass sizes explicitly.
- Only enable vendor extensions that the shader actually uses.
- Test on at least one AMD or Intel integrated GPU when possible.

The [Lua integration guide](lua-guide.md) covers the scripting side of shader parameters and post passes. The [Lua API reference](/docs/lua_api.html) contains the complete generated signatures.
