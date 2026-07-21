#set document(title: "Notes on Computer Graphics: Lecture 11")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 13
  == Meshes, Topologies, and Indices

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time, we learned about interactive cameras.

We learned how to move SceneNodes around.

We learned how to invert the camera's model matrix to make a view matrix.

We learned about Tait-Bryan/Euler angles, and the yaw-pitch-roll camera system. We also learned about alternatives.  

We learned how to read keyboard input.

We learned what a keycode is.

== This time

This lecture is all about meshes.

We've been using them the whole time, but we haven't really used them the way they get used in actual 3D engines.

So let's change that! We're going to make a mesh class, learn how to describe faces, and learn how to load meshes from a file.

== What is a mesh?

A mesh is a list of triangles representing an object's boundary surface.

