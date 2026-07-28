#set document(title: "Notes on Computer Graphics: Lecture 14")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 14
  == Scenes

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!
Last time we learned about meshes.

[What is a mesh?]

We learned how to load a mesh from a file.

Specifically, an OBJ file.

We used this knowledge to draw a teapot.

== This time

This time we're going to learn more about scenes.

You've seen them before: in our camera lecture, we used a simple scene node class to represent objects in our scene, including the camera.

But something was missing...

== Real Scenes

Interactive software has more complex scenes...

#figure([
#image("screens/banjo_kazooie.jpg", height: 60%, alt: "a screenshot of Banjo Kazooie, in which Banjo is flying. He is wearing a backpack, and Kazooie is inside of it, flapping.")
#place(top + left, dx: 1%, dy: 1%, game-name("Banjo Kazooie", text-color: black))
])

That's a screenshot of the game Banjo-Kazooie. Banjo is the bear, Kazooie is the bird, and they are two separate scene objects.

== Scene Hierarchy

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
Not only that, but for convenience in animation, one of the objects is subordinate to the other.

Specifically: when Banjo moves, Kazooie moves with him.

However, the reverse is not true: when Kazooie pops out of his backpack, Banjo is not moved.
],
[
#image("screens/banjo_kazooie_relaxing.jpeg", height: 80%, alt: "a screenshot of the credits scene from Banjo Kazooie. Banjo is in a beach chair drinking a beverage. Kazooie is in his backpack, drinking a beverage with a straw. Both are wearing shades.")
#place(bottom+right, dy: -1%, dx: -1%, game-name("Banjo-Kazooie"))
]
)

== Scene objects

This pattern is more common than just for animating characters.

Frequently, 3D levels will be built out of chunks. For example, a building can be a collection of rooms. The rooms can have items in them:

=== Hierarchy:
- Library
  - Foyer
  - Reading room 1
  - Reading room 2
    - Desk
      - Book

== The scene hierarchy

If you have ever used a 3D engine before, you have probably been exposed to this hierarchy, whether you realized it or not.

Unity, for example, assumes that your scene will be in the form of a tree. So does Unreal, so does Godot.

#figure(
image("screens/unreal_scene_graph.png", width: 45%, alt: "screenshot of unreal editor"),
caption: text(20pt)[An example scene graph from Unreal Editor.],
numbering: none,
)

== The scene hierarchy (2)

Is this strictly, absolutely required?

No, we already saw that we could build a simple scene without it.

And furthermore, the GPU doesn't normally know or care about your hierarchy unless you tell it. Typically by the time we do our rendering, we just have a model matrix, a viewProj matrix, and maybe some textures and a vertex buffer.

So we don't _have_ to represent scenes hierarchically.

But we typically _want_ to...

== Consider a race car

Suppose we're making a racing simulator.

We have a car. The car has a chassis and four wheels...

#let wheels = {
  import draw: *;
  rect((-.75, -1), (-.5, -.5))
  rect((.5, -1), (.75, -.5))
  rect((-.75, 1), (-.5, .5))
  rect((.5, 1), (.75, .5))
}

#let chassis = {
  import draw: *;
  rect((-.5, -1), (.5, 1))
}

#let car = {
  wheels
  chassis
}

#figure(
  canvas(length: 3cm, {
    import draw:* ;
    group(
      car
    )

    group({
      translate(x: 2.5)
      rotate(-30deg);
      car
    }) 
  }),
  numbering: none,
  caption: "This is what we want to happen when the car is rotated (left to right)",
  alt: "a simple diagram, showing two groups of rectangles that represent race cars: one body and four wheels each. The one on the left is facing due north. The right figure is rotated such that all the wheels are also rotated correctly, causing the 'car' to point north east. "
)

== Consider a race car (2)

Now consider what happens with no hierarchy at all:

#figure(
  canvas(length: 3cm, {
    import draw:* ;
    group(
      car
    )

    group({
      translate(x: 2.5)
      wheels
      rotate(-30deg);
      chassis 
    }) 
  }),
  numbering: none,
  caption: "This is what happens if we don't use hierarchical grouping. We rotated the chassis, but the wheels weren't attached to it.",
  alt: "a simple diagram, showing two groups of rectangles that represent race cars: one body and four wheels each. The one on the left is facing due north. The right figure has its chassis rotated, but the wheels did not rotate: they are still in their original positions, facing north. The 'car' is no longer connected."
)


== Consider a race car (3)

Is it possible to do this _without_ a hierarchy?

Yes. You could move all the wheels independently.

However, this would mean first moving the wheels to the origin, then offsetting them by the correct amount, then rotating around the origin, then translating them to the final position of the car, so that they would be rotated and at the correct offset relative to the chassis.

It's just kind of a lot. Especially given that the hierarchy gives a useful way of designing scenes.

== Designing Scenes

Remember that humans usually design game scenes.

We typically like to paint with a broad brush first, designing higher level areas, before zooming in with details.

This is analogous to the way drawing often works, or music composition, or even top-down software design. Start with big areas, subdivide into smaller details.

It might be worth exploring some scenes: #link("https://noclip.website/", [NoClip Game scene Viewer]) 

#focus-slide("Questions?")

== Coding Scenes

So, how do we achieve this effect?

Here is the basic idea:
- Extend the idea of the scene node. Not only does a scene node have a matrix, it also has a parent and a list of children.
- Each scene node still has a matrix. However, this matrix is not _final_. It represents the scale, rotation, and position of a node *relative to its parent*.
- Then we have an actual final matrix. This matrix is constructed by applying the transformations from the parent (and its parent, and so on). This is the model matrix we send to the video card.

== The basic idea

Suppose we have a simple solar system. Pretend the orbits are circular.

A planet rotates around a star.
A moon rotates around the planet.

These are scene nodes. We want it to work like this:
- When the star is moved, the planet moves with it.
- When the planet is moved, the planet's moon moves with it.

We also want this to apply to rotation.

In fact, we want _every_ transformation that applies to a parent to also apply to its children. But _not vice versa_.

== The basic idea (2)

The question is: how do we accomplish this?

[suggested designs?]

Remember that each item in the scene has two matrices:
+ A local matrix, representing its changes relative to the parent.
+ A final matrix, representing it's model matrix that has incorporated all the changes, which we draw.

== A simple hierarchical scene node

The basic idea is this: our goal is to generate the final marix. That is the matrix we need to send to the video card.

A node's local matrix represents its movement _relative to the parent_.

Therefore, we take the _final matrix of the parent_, and post multiply it by the _local matrix of the node_. 

The result is the final matrix of the node.

Then, we propagate this change forward: the final positions of the node's children are their local matrices times the final matrix of the parent.

== A simple example 

Suppose the sun is at the center of the scene. It's position is 0, 0, 0. It's local and final matrices are both the identity matrix.

Suppose the planet starts at position 100, 0, 0, relative to the sun.

The sun is rotated by a quarter turn around the Z axis. What happens to the planet?

After the sun is rotated, its final matrix is:

#math.equation($mat(
  0, -1, 0, 0;
  1, 0, 0, 0;
  0, 0, 1, 0;
  0, 0, 0, 1;
)$, alt: "a z rotation matrix with tau over four as the amount of rotation. left to right, top to bottom: zero, minus one, zero zero. one zero zero zero. zero zero one zero. zero zero zero one.")

== A simple example (2)

The planet's local matrix is simply a tranlsation. It is offset from the sun:

#math.equation($mat(
  1, 0, 0, 100;
  0, 1, 0, 0,;
  0, 0, 1, 0,;
  0, 0, 0, 1;
)$, alt: "a translation matrix with 100 in the top right element. this means that there are 1s down the diagonal and zeros everywhere else.")

What happens when we apply the planet's local translation to the sun's final translation?

#math.equation($
  mat(0, -1, 0, 0; 1, 0, 0, 0; 0, 0, 1, 0; 0, 0, 0, 1) times mat(1, 0, 0, 100; 0, 1, 0, 0; 0, 0, 1, 0; 0, 0, 0, 1) = mat(0, -1, 0, 0; 1, 0, 0, 100; 0, 0, 1, 0; 0, 0, 0, 1)
$, alt: "multiplying the two matrices above, sun times planet. The result is, left to right, top to bottom, zero, minus one, zero zero. one, zero, zero, one-hundred. zero, zero, one, zero. zero, zero, zero, one.")

== A simple example (3)

What does that mean? First, consider the position:

Rotating the sun caused the planet to rotate around it. Previously the planet was at (100, 0, 0). Now it is at (0, 100, 0), a quarter turn rotation.

But what's more, the planet's matrix also includes a rotation by a quarter turn in it.

That means the moon will also rotate a quarter turn and be translated, causing it to follow the planet. Just like the wheels of the car, before.

[whiteboard?]

#focus-slide("Questions?")

== Coding it

Okay, let's code up a scene graph!#footnote[It's a tree, but in the literature this data structure is called a Scene Graph, because nodes can sometimes reference templates that end up being in more than one node. But let's think of them as trees.]

Let's try to think about what we need to write:
- A new node class that has the required two matrices and parent-child hierarchy. (A tree)
- A method that calculates the final matrix from the parent.
- New drawing code that recursively walks the scene.

Let's start with the node class...

== The node class 

#[
  #set text(20pt)
```ts
export class SceneNode {
    finalMatrix: mat4 = mat4.create();
    children: SceneNode[] = [];
    parent: SceneNode | undefined;

    localMatrix: mat4 = mat4.create();
    
    finalBuf: GPUBuffer;
    modelBg: GPUBindGroup;

    mesh: LoadedMesh | undefined;    
    name: string | undefined;
    ...
}
```
]

== The name

The name is just an optional string.

We can use it for debugging, or for inspecting the scene.

We can also use it for identifying a particular node so we can apply a custom transformation to it.

This is done in our sample.

Otherwise, it's not strictly required. That said, most scene graphs seem to have nodes with meaningful names. It makes it easier to display them to the scene creator.


== The node class fields

First, we store two matrices: `finalMatrix` and `localMatrix`.

These are `mat4`s, which means they are accessible to the CPU (they're in main memory).

However, there is also a `GPUBuffer` for the final matrix. And a bind group that refers to that buffer.

The shader will only see the matrix in that buffer, and it will be bound to the group and binding of the model matrix.

This is important: we don't want to do all our transformations for every single vertex. We want to combine them all into one matrix.

== The methods

This scene node is a little simpler than the one we looked at in the camera controls lecture. We don't have yaw, pitch, or roll. We do everything with the matrix.

The methods act directly on this matrix:

#[
  #set text(20pt)
```ts
move(pos: vec3): void {
    mat4.translate(this.localMatrix, this.localMatrix, pos);
}
rotateX(amount: number): void {
    mat4.rotateX(this.localMatrix, this.localMatrix, amount);
}
... // more methods
```
]

== The constructor

The constructor is also similar to before. We create our matrix buffer and a bind group.

More importantly, the constructor also calls a method called `updateData`

#[
  #set text(20pt)
```ts
constructor(
  device: GPUDevice,
  layout: GPUBindGroupLayout, // for the bind group
  name?: string // this is an optional parameter
) {
  this.name = name; // will be undefined if `name?` omitted
  this.finalBuf = ... // create a new buffer to store the matrix
  this.modelBg = ... // create a bind group with the buffer
  this.updateData(device); // compute and copy the final matrix over
}
```
]

== `updateData`

This is where we send the data to the GPU. We compute our final matrix, by using the parent's final matrix and our local matrix.

#[
  #set text(18pt)
  ```ts
  updateData(device: GPUDevice): void {
      // we'll discuss the `??` operator in a second...
      const parentMatrix = this.parent?.finalMatrix ?? mat4.create();
      mat4.mul(this.finalMatrix, parentMatrix, this.localMatrix);
      // copy the data to the GPU
      device.queue.writeBuffer(
        this.finalBuf, 0, new Float32Array(this.finalMatrix));
      
      // update children recursively
      for (let child of this.children) {
          child.updateData(device);
      }
  }

  ```
]

== The `?.` and `??` operators

`??` is called the null-coalescing operator.

It checks the left operand to see if it's either `null` or `undefined`.

If it is, the result of the expression is its right operand.

If not, the left operand is returned.

`this.parent?.finalMatrix ?? mat4.create();`

Will first determine if the parent exists. That's what `?.` is for.

It would be an error to access a field of a null/undefined value. `null.finalMatrix` is not meaningful 

== The `?.` and `??` operators (2)

If the node's parent is `undefined`, then `this.parent?.finalMatrix` will be `undefined`, because the `?.` operator will short-circuit. It won't try to evaluate the rest.

Then, the `??` operator will kick in. That `undefined` value will cause `undefined ?? mat4.create()` to result in `mat4.create()`, which is the identity matrix.

All so this will happen: if we don't have a parent, treat the parent's matrix as if it were the identity. This means that we don't need a special case for the root of the sceen.

== The recursive step

Once we determine the parent's matrix (or the identity matrix if there isn't one), we multiply it with the local matrix.

`mat4.mul(this.finalMatrix, parentMatrix, this.localMatrix);`

The result is the `finalMatrix`.

We apply this same logic to the children, recursively:
```ts
for (let child of this.children) {
    child.updateData(device);
}
```


== The hierarchy

But where did children get added to the scene? Let's consider how we can add new children _below_ a node in the hierarchy:

#[
  #set text(20pt)
```ts
addChild(
  device: GPUDevice,
  layout: GPUBindGroupLayout,
  name?: string
): SceneNode
{
    const child = new SceneNode(device, layout, name);
    child.parent = this;
    this.children.push(child);
    return child;
}
```
]

== The hierarchy (2)

After adding the child to the data  structure and setting its parent, we return it so the user can easily modify it.

The children are stored in an array.

This doesn't have to be the case: we could have required names, and used a hashmap to store the children. An array is fine for our purposes, however.

We walk the array of children in two circumstances:
+ When we need to update the matrix of our node and its children.
+ When we need to draw the node and its children.

== Doing everything with a matrix

You might notice that there aren't yaw, pitch, roll, scale, etc.

That's because I decided to do everything with the matrix to demonstrate a matrix camera.

I kind of regretted it: the issue with only having the matrix is that all transformations modify the current state. It's easy to _rotate_ by 90 degrees, but it's hard to _set the rotation to be_ 90 degrees exactly, if that makes sense.

A raw matrix also has issues with stability: over time, the basis vectors will start to drift. For cameras, this will result in weird skewness creeping in the more you rotate.

== Optional meshes

One last thing that deserved a brief mention: the mesh was `LoadedMesh | undefined`

The logic behind this is that a node can be empty.

Why would a node be empty?

Well, it might be a camera. Or it might only exist to group other nodes together...

== Optional meshes (2)
#figure(
  box[
    #image("screens/pilotwings.png", width: 60%, alt: "a screenshot of the nintendo 64 game Pilotwings 64.")
    #place(bottom + right, dx: -1%, dy: -1%, game-name([Pilotwings 64]))
  ],
numbering: none,
caption:
[The group of hang gliders in the screenshot above move together. They could be grouped under an empty node. #link("https://noclip.website/#Pilotwings64/0:4;ShareData=ArtEw=1v4FWp]h^=s0$-i8", "What do you think?")]
)

== Setting up the scene

Building the scene usually starts with the root. We define its name, mesh, and transform it as we wish.

Then we add any children we want:

#[
#set text(20pt)
```ts
this.root = new SceneNode(device, modelColorLayout, "root cube");
this.root.mesh = this.cube;

const right = this.root.addChild(device, modelColorLayout, "right cube");
right.mesh = this.cube;
right.move([7, 0, 0]);
right.scale([.5, .5, .5]);
```
]

Here, we add a right node underneath the root, move it, and scale it.

== Storing the scene

Nodes can be entirely defined by the following:
- Their local matrices
- Their parents/children
- Their mesh

If we refer to meshes by an identifier, we can easily store this structure in a JSON file.

This is actually fairly easy to do, and might be worth exploring for your final project if you'd like the ability to save and load the scene.

== Drawing the scene

We have a new node class, and a way for changes to a parent node to propagate forward to its children. Now, let's draw the results. Pretend we have a `pass` already prepared:

#[
#set text(18pt)
```ts
let stack = [this.root];
while (stack.length > 0) {
    const top = stack.pop()!;
    stack = stack.concat(top.children);
    if (!top.mesh) continue; // don't draw invisible nodes
    pass.setIndexBuffer(top.mesh!.indexBuffer, 'uint32');
    pass.setVertexBuffer(0, top.mesh!.vertexBuffer);
    pass.setBindGroup(0, top.modelBg);
    pass.drawIndexed(top.mesh!.nIndis);
}
```
]

Take a second to try to parse this yourself...

== Drawing the scene (2)

Here's what's going on:

We're doing a depth-first search over our scene. That requires a stack.

We store the root in the stack. Then, in a loop, we pop the top element of the stack and draw it.

Remember, to draw it, we set the vertex and index buffers of the mesh, set the bind group so the model matrix points to the final matrix of the node, and then we draw everything.

The postfix`!` operator is like the `?.` operator but it means "I promise this exists" instead of meaning "test if this exists". It removes `|undefined`.

== Drawing the scene (3)

Every time we process a node, we also add its children to the stack.

This is what causes us to walk the scene hierarchy recursively.

This is a simple way of drawing everything: start with the root and work your way down.

However, I don't want you to think this is the only way to handle scenes. Or even the _best_ way...

== Alternatives to recursive drawing

We don't have to draw recursively. In fact, it might be worth refactoring this later when we get to lighting.

The reason is that not everything in the scene is going to be a mesh. There might be lights stored in a node. Collision boxes, cameras, all kinds of things.

These all have different rules. We'll see later how lights work. Basically, a light is attached as a bind group to all the nodes that can see it.

This means the light won't show up if we draw a root node that has a light as a child: the light won't have been processed yet.

== Alternatives to recursive drawing (2)

To fix this issue, game engines will typically *flatten* the scene.

That means, they walk all the nodes, but they save all the different kinds of nodes into different data structures.

For example, solid meshes go into a drawing queue.

Lights might go into a spacial data structure of just lights.

== Handling lights and transparency

We typically only have enough room in a shader to handle a small, fixed number of lights. Therefore, we might have to sort them by how bright they are, which depends on their distance.

Not to mention: transparent meshes have special rules. 

We usually can't draw transparent meshes as soon as we see them. They have to be drawn in a particular order, often in their own render pass.

So we can't just draw nodes as soon as we see them, except in the very simple scenario where everything is a solid, unlit object like we see above.

== Alternatives to recursive drawing (3)

Therefore, a more complex rendering system would be split into a *frontend* and *backend* renderer.

The frontend is responsible for walking the scene tree and building a list of things to draw, lights, transparent objects, etc.

Then, it hands that set of structures off to the backend renderer which draws them as quickly as possible.

These stages can be interleaved, so that the backend can start rendering (or at least, encoding the pass) as soon as solid nodes are visited, reducing the latency.

#focus-slide("Questions?")


== The Sample

`Sample11` has an example. It contains a scene hierarchy that draws a bunch of boxes.

One child box is scaled every frame. Notice how its children gets scaled.

All the boxes are rotated, and the child boxes are rotated additionally.

When the root node moves, notice that every box moves with it...

== The root node

Scenes can be forests or trees. 

If a scene is a tree, then it has a root node.

This is useful, because anything we do to the root node will end up happening to the entire scene.

[Can anyone think of an example of when this would be useful?]

== Mirrored tracks

Consider this game:

#figure(
  [
    #image("screens/mario_kart_64.jpg", height: 60%, alt: "screenshot of mario kart 64")
    #place(bottom + right, dx: -1%, dy: -1%, game-name([Mario Kart 64]))
  ]
)

This game had _mirrored tracks_.

== Mirrored tracks 

A mirrored track is a track that is reflected about one axis.

If we reflect the track about the Y axis, all the right turns will be left turns, which will make it feel novel.

However, the track will still be completable. A reversed track might not be (e.g., if there's a giant ramp going one way). 

This is a really simple trick that can add a lot of value.


== Homework and Project

Hopefully, it's starting to come together how we can use these low-level graphics APIs to build a 3D engine.

There are many more topics to cover, but in my experience, understanding hierarchical scenes is key to things "clicking".

Be sure to read #link("https://shi-yan.github.io/webgpuunleashed/Basics/understanding_normals.html", "this chapter") of WebGPU unleashed so that you understand normal vectors and matrices. It will be important next time when we cover lighting.

== Thanks for listening!

You're ready for the next project now!

#figure(
  box[
    #image("screens/diddy_kong_racing.png", height: 60%, alt: "a scene from the game Diddy Kong Racing, showing a dinosaur wandering around a cave with lava-filled craters, pterodactyls flying around, and some balloon sprite objects.")
    #place(bottom + right, dx: -1%, dy: -1%, game-name([Diddy Kong Racing]))
  ]
)

(it won't look like this)


#focus-slide("Questions?")