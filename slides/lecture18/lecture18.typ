#set document(title: "Notes on Computer Graphics: Lecture 18")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 18
  == Advanced Texturing

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time we learned all about cube topologies.

They were surprisingly involved, and we learned two in particular:
- UV-spheres
- Cube-spheres

[How do they differ, and does anyone recall the secret 3rd option?]

We also learned how to texture map them. UV-spheres straightforwardly wrap a texture around them cylindrically.

Cube-spheres _could_ use the same trick, but there's a better way...

== Welcome back! (2)

We saw that there exists a special kind of texture that is designed to be sampled with a vector, as if the texture is on the surface of a cube, and the sample is a vector pointing outward from the center of the cube.

It's called a *cube-map*, and we learned how to load and to use them.

Cube-maps basically remove the need to duplicate vertices of cubes so the top can have different UV coordinates from the sides.

But they can also unlock two very cool techniques:
+ Sky boxes. Very important to 3D games in particular.
+ Environment maps: cool reflections which are cheap to compute.