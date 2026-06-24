#set document(title: "Notes on Computer Graphics: Lecture 1")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *

#show link: set text(blue)

#show: slide-theme

// #show strong: it => text(fill: rgb("000000"), it)

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

#background-slide(background: image("screens/clair_obscur.jpg", alt: "a screenshot of Clair Obscur: Expedition 33"))[
  #place(top + right, dx: 5%, dy: -5%, text(size: 14pt, fill: white, "Clair Obscure: Expedition 33"))
  
  #place(top, dx: -2%, dy: -5%, shadowed-box()[GPUs are incredibly powerful.
  ])

  #place(horizon + right, dx: 5%, dy: 35%, shadowed-box(width: 40%)[They can produce beautiful 3D scenes like this one dozens or hundreds of times per second]
  )
]

== And guess what?...

...You _aren't even using it_.

All of that power is just sitting there.

You have to explicitly write code for the GPU in order to use it.

No, your compiler will not optimize this for you. Programming for the GPU is very different from programming for the CPU, and it requires the code be architected in a particular way.

So let's stop having this powerful behemoth in your computer sit idle. Let's learn to _harness_ it.

== They can do more

Many of you are interested in making video games. That's okay, that was/is my motivation for learning computer science.

But many of you aren't. Guess what: *this class is still for you.*

GPUs are a powerful, versatile co-processor that is built into every modern phone, tablet, laptop, and desktop.

And it turns out, using the GPU to accelerate general computations is very similar to using it to draw cool scenes.

== GPUs run shaders

A program that runs on the GPU is called a *shader*.

It was called that because, originally, these programs were used to visually shade 3D objects.

We will learn how to use them for that purpose, but they can also just run whatever computation you want on the GPU.

And there are so many useful computations to run...

== Things GPUs are used for

#slide[
- GPUs are what made the LLM revolution possible. The neural networks that power LLMs are glorified lists of matrix multiplications, which your GPU can do extremely quickly. #footnote[note: if you're not a fan of LLMs, don't blame your GPU. It just wanted to draw cool video game scenes.]\
- Physics simulations can be done on the GPU
- GUIs can be rendered on the GPU
- Complicated scientific processing can be done on the GPU
- Many algorithms can be made much faster with a GPU. #link("https://shi-yan.github.io/webgpuunleashed/Compute/radix_sort.html")[Here is an implementation of Radix sort.]
- And, last but not least, they can draw awesome 3D graphics.
]

== I hope you will get a lot out of this class

In this class, you will develop a simple realtime 3D graphics engine. In doing so, you will hopefully learn/gain a lot:
- How to interact with the GPU, including writing shaders. (this carries over to doing other things on the GPU besides graphics)
- Some really cool 3D math. My experience is that I understood the math way better after learning 3D graphics. Students have told me that this class makes it click #footnote[Don't worry, we review the math you're going to need as it comes up. I don't assume you remember very much from linear algebra.]
- An awesome portfolio item: you'll make browser-based 3D apps.
- Last but not least: How your favorite game engines work.

== A secret about me

#box(width: 50%)[
This is my favorite class to teach.

I can't resist talking about ancient 3D technology.

I will try my best not to bore you.
]

#place(top+right, dx: 7%, dy:-14%, image("screens/ut_galleon.jpg", alt: "A video game screenshot", width: 55%, height: 130%))

#place(bottom, dx: 60%, dy:10%, game-name()[Unreal Tournament: Map "Galleon"])


#focus-slide[Questions?]
