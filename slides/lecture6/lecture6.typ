#set document(title: "Notes on Computer Graphics: Lecture 6")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 6
  == Vertex Attributes and Color Blending

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

== Welcome Back!

Last time we learned how to store our vertex positions in a buffer. This is important because it _scales_.

We learned about how color is perceived. 

We learned _why_ we store color in RGB...and why it's not enough to represent every possible color we can perceive.

We learned about _gamma correction_. \ [What is it, and how does it impact us?]

== This time

We're going to understand something very important about the graphics pipeline: interpolation.

We're going to draw a differently-colored triangle that smoothly blends its colors.

We're going to learn how to work with more complex vertex buffers, especially interleaved ones. That means we'll be learning what `stride` means.

We're going to learn an incredibly important concept: what a *vertex attribute* is.

== Adding colors

Previously, we stored our triangle data in an array.

It looked something like this:
```ts
const aSimpleVertexBuffer = new Float32Array([
    -0.75, -0.75, 0,
     0.75, -0.75, 0,
        0,  0.75, 0,
]);
```

Then we loaded it into a buffer using `device.createBuffer`, `.getMappedRange`, and `.set`.

== Buffers are flexible

That was a very simple buffer, but first of all, it's a little wasteful:
If we know that all our z-values will be zero, we can just load them with 0 in the vertex shader.

But more importantly, buffers let you store multiple pieces of information. More than just position.

Frequently there is a lot of data we want to associate with vertices, but there are lots of custom situations. Like being able to eliminate z, or knowing in advance that most of the faces will be facing the same way (like in a Minecraft chunk)

== Attributes

For example, what if we want each vertex to have a color?

Then we need to create a new *attribute* that will store color.

Attributes are pieces of information we want to associate with every vertex in a single draw call (typically one model).

Previously our only attribute was `position`, and it was at `@location(0)`
```wgsl
@vertex fn vs(@location(0) position: vec3f) 
  -> @builtin(position) vec4f { ... }
```

The vertex shader is required to return a 4 element vector at `@builtin(position)`, so we just copied the input position over.

== Attributes (2)

So, if that's how we pull the position attribute, how do we add color?

Answer: add another parameter:
```wgsl
@vertex fn vs(
  @location(0) position: vec3f, 
  @location(1) color: vec3f    
) -> @builtin(position) vec4f { ... }
```

Now, our shader is expecting two piece of information (two "attributes") for every vertex: a position and a color. In this case, both are `vec3f`s, but that isn't required.

But something's missing. What should the vertex shader do with it?

== Interstage variables

Variables with `@location` or `@builtin` tags are called *interstage variables*.

They are called that because they contain information that gets passed between stages of the pipeline.

If the vertex shader does not return a variable, then the fragment shader will not be able to read it. 

Therefore, the vertex shader needs to return both the position and the color. Then the fragment shader can use the color to compute the color of the pixel.

== Structs in WGSL

WGSL doesn't support multiple return values. Instead, we use a `struct`.

#[
#set text(size: 20pt)
```wgsl
struct VertexOutput {
  @builtin(position) pos: vec4f;
  @location(0) color: vec3f;
}; // semicolon optional. Most sources I've seen include it.
```
]

Now we can pass the position and color through the vertex shader:
#[
  #set text(size: 20pt)
```wgsl
@vertex fn vs(@location(0) pos: vec3f, @location(1) color: vec3f) 
-> VertexOutput {
    var vo: VertexOutput;
    vo.pos = vec4f(pos, 1);
    vo.color = color
    return vo;
}
```
]

== `var` in WGSL

This is the first time we've seen `var` in WGSL

WGSL uses `const` for compile-time constants, `let` for readonly variables, and `var` for fully-mutable variables. 

In this case, we want to write into our vertex output before returning it, so we need to use `var`.

This is a common pattern in WGSL vertex shaders: instantiate a `var` for an output struct, and then return it.

== The fragment shader

The fragment shader takes the struct now:

```wgsl
@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    return vec4f(vo.color, 1.0); // convert vec3 to vec4
}
```

Note: `@location`s and `@builtin`s can be attached to struct fields. These are both examples of *io-attributes*. These attributes are only meaningful if the struct is an argument or return value of a shader.

If it isn't, the locations are ignored. 

By the way: this fragment shader has a bug. We'll see why soon.

#focus-slide("Questions?")

