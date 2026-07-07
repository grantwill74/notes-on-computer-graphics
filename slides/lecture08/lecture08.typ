#set document(title: "Notes on Computer Graphics: Lecture 8")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 8
  == The math we all forgot

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

/*
+ Trig and linear algebra review:
  - Sin, cos, tan
  - Tau and turns
  - Pythagorean Theorem
  - Using what we know to draw a circle
  - Complex numbers (and quaternions mentioned?)
  - Dot products
  - Required viewing after: the 3blue1Brown video about matrices
+ 3d matrices
  - Basic affine transformations and their matrices
  - But what about translation?
  - Adding a dimension: homogeneous coordinates
  - Combining transformations
  - Projections 
  - Gl-matrix
  - Sending a matrix to the video card
  - Assignment: five perspective correct quads
  - bonus: make them textured using an atlas
*/

== Welcome Back!

