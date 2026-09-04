#set document(title: "Notes on Computer Graphics: Lecture 19")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 19
  == Terrain Engines

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time we learned all about textures.

Before I summarize that huge lecture, [who can tell me about the texturing techniques we learned about?]

== Texture techniques

- We learned about MIP mapping [what is it?]
- We learned about trilinear filtering [ditto]
- We learned about anisotropic filtering [?]
- We learned about fragment quads and how the GPU selects MIP levels [?]
- Remind me: [what's a helper invokation]?
- We learned about multi-texturing [how does it work?]
- We learned about normal maps [ditto]
- We learned about specular maps, and just in general that we can put lookup tables in textures and call them "something maps"

== This time

Let's actually use our knowledge.
