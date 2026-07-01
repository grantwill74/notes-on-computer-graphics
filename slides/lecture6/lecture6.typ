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

Previously our only attribute was `position`, and it was at `@location(0)`.