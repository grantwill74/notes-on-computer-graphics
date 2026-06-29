#import "@preview/cheq:0.4.0": checklist

= Project 1: A simple quad

== The big idea
You've seen how to render a triangle. Now render a rectangle!

How? By drawing two triangles.

If you draw two triangles where they share an edge (meaning, two vertices have the same location between them), you will get a quad (assuming one of the triangles is not degenerate--i.e., a point or a line).

The quad should be two triangles, with the shared edge being the diagonal.

I want you to draw not just any quad, but a rectangle, aligned with the axes of the canvas (not diagonal) that takes up half the canvas in each dimension.

Oh, and make the rectangle yellow, too. (100% green and red, 0% blue). The background should be the same light blue that we used in the slides (70% red, 80% green, 90% blue). For now, the "alpha" should always be 100%.


You must use Typescript or Javascript. You must use WebGPU to render this scene.

== Right

#image("right.png", height: 25%, alt: "A screenshot of the correct triangle, which follows the following set of requirements correctly.")

The rectangle must fill up half the verticle and horizontal range of the canvas. I will let you choose your canvas dimensions as long as they are at least 400 by 400, but I recommend making it non-square so that it is easier to see how the viewport transformation works.

The rectangle must be yellow and the background must be light blue, following the RGB values listed above. There must be no visible gap between the two triangles that make up the rectangle.


== Wrong

#image("wrong.png", height: 25%, alt: "A screenshot of a triangle that did not follow the instructions.")

Notice that this quad and the background are both the wrong color. It's also not an axis aligned rectangle, and there is a visible seam. Finally, its height is slightly too large (more than half of the vertical dimension).

== How to submit

Prepare a .zip archive such that it contains your projects directory. This is the directory that will contain all your projects for this class.

Ensure that it includes all your typescript. 

Do not include the `node_modules` subdirectory. It will make the archive too big and use too much convas storage.

Ensure that the HTML file you want to be graded is named `index.html`.

Ensure that the archive contains the same `package.json` and `tsconfig.json` that you used.

Copy and paste all the code you wrote (the HTML file and any TS files needed for this project) into the submission window. This is required for archival purposes. The code you submit this way must match the code in the archive exactly (although sometimes Canvas messes up the spacing, which is okay). Don't include library code or code written by me, just the code that you are providing for the project.

After submitting by copying the code into the text window, navigate back to your submission on Canvas. Create a new comment, and attach the `.zip` archive.

== Grading

- There is a 4-sided shape visible: 20%
- It is axis-aligned: 20%
- It has the correct color: 10%
- Background has correct color: 10%
- There is no visible seam or other imperfection: 20%
- The dimensions are correct: 20% (10% for horizontal, 10% for vertical)
- Penalties may be assessed, up to and including all points, for not following submission instructions or not being able to pass a code review.

Only Typescript or Javascript solutions will be accepted.

The grader will do the following:
- Extract your .zip archive and ensure that the code matches what you submitted.
- Execute `npm update` to install any dependencies (such as the specific version of typescript you used)
- Execute `npx tsc` to compile all the typescript files into Javascript. It is acceptable for this to fail if you didn't use typescript, but otherwise, errors here will be penalized.
- Serve the directory on a local webserver
- Navigate to your `index.html`.
- Validate that it matches `right.png`.
- Check the code to ensure that nothing funny is going on (you actually implemented the project and aren't just displaying an image instead of rendering it)

Thank you for following this complex submission process. It is required to ensure that we are able to index your work for accreditation while also having making it possible for the grader to duplicate your solution conditions. 

== Checklist
#[
  #show: checklist 

  - [ ] I verified that my image looks identical to `right.png` to the greatest extent of my ability.
  - [ ] I created a new directory for my submission.
  - [ ] I copied over the HTML file and any Typescript files that generate its dependencies (or Javascript files if I didn't use Typescript) from my project director to the submission directory.
  - [ ] I named the HTML file `index.html`
  - [ ] I copied over `package.json` and `tsconfig.json`
  - [ ] I ran `npm update` and `npx tsc` and there were no errors.
  - [ ] I ran a webserver out of my submission directory and verified that it still rendered correctly
  - [ ] I deleted the `node_modules` directory from my submission directory
  - [ ] I copied all the code in my HTML file and any non-library code it depends on into the submission textbox on canvas, and I submitted.
  - [ ] I navigated back to the submission and attached my `.zip` archive to a comment.

  
]

== Alignments
- MO1: Entire grade
- MO3: Entire grade

== AI and teamwork policy
Please see the syllabus for AI and teamwork policy. Remember that you are expected to understand and be able to explain every line of code that you submit.
