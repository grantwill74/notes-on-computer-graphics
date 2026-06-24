#set document(title: "Notes on Computer Graphics: Lecture 1")

#import "@preview/touying:0.7.4": *
#import themes.simple: *

#show link: set text(blue)


#show: simple-theme.with(
  aspect-ratio: "16-9",
  title: [Computer Graphics: Lecture 1],
  subtitle: [Welcome to Realtime 3D!],
  header: none,
  config-common(new-section-slide-fn: none, new-subsection-slide-fn: none),
)

#show strong: it => text(fill: rgb("000000"), it)

#title-slide[
  = Computer Graphics: Lecture 1
  == Welcome to Real-time 3D!

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

== Welcome!
You have done some cool things as a computer science major:
- You have learned and implemented a wide range of algorithms...
- Data structures too...
- You have developed user-facing applications (GUIs)

You have learned many languages, and built many projects, to do all sorts of cool things.

However, there is a set of capabilities inside your computer that you have not even _begun_ to unlock. The computer is *way* more powerful than you've been able to take advantage of.

== The computer's superpower

Almost every modern computer (including phones) contains a powerful *co-processor* called a GPU--a graphics processing unit. This GPU might be on a special expansion card, like this RTX 5090 here:

#figure[
#image("screens/5090.png", alt: "a picture of an NVidia RTX 5090 graphics card", width: 50%, height: 45%)
]

== #hide[GPUs are powerful] 

#slide(
  config:
    config-page(
      background: image("screens/clair_obscur.jpg", alt: "a screenshot of Clair Obscur: Expedition 33")
    ),
  
)[
  #place(top, dx: -2%, dy: -5%,  box(width: 40%,
  [#text(size: 24pt, fill: white, weight: "semibold")[The GPU is incredibly powerful, often an order of magnitude more powerful than the CPU.
  
  ]]))

  #place(horizon + right, dx: 5%, dy: 35%, box(width: 30%, [#text(fill: white)[It can produce beautiful 3D scenes like this one dozens or hundreds of times per second]]
  ))

  #place(top + right, dx: 5%, dy: -5%, text(size: 14pt, fill: white, "Clair Obscure: Expedition 33"))
]

#focus-slide[Questions?]
