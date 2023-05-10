<img src="docs/boxyBanner.png">

# Boxy - 2D GPU rendering with a tiling atlas.

`nimble install boxy`

![Github Actions](https://github.com/treeform/boxy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/boxy)

## About

Boxy is an easy to use 2D GPU rendering API built on top of [Pixie](https://github.com/treeform/pixie).

The basic model for using Boxy goes something like this:

* Open a window and prepare an OpenGL context.
* Load image files like .png using Pixie.
* Render any dynamic assets (such as text) into images once using Pixie.
* Add these images to Boxy, where they are put into a tiling atlas texture.
* Draw these images to screen each frame.

## Videos

* [Efficient 2D rendering on GPU](https://www.youtube.com/watch?v=UFbffBIzEDc)
* [GPU Gaussian Blur in Nim using Boxy and Shady](https://youtu.be/oUB0BGsNY5g)

## Basic Example

```nim
import boxy, opengl, windy

let windowSize = ivec2(1280, 800)

let window = newWindow("Windy + Boxy", windowSize)
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("ring1", readImage("examples/data/ring1.png"))
bxy.addImage("ring2", readImage("examples/data/ring2.png"))
bxy.addImage("ring3", readImage("examples/data/ring3.png"))

var frame: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), windowSize.vec2))

  # Draw the rings.
  let center = windowSize.vec2 / 2
  bxy.drawImage("ring1", center, angle = frame.float / 100)
  bxy.drawImage("ring2", center, angle = -frame.float / 190)
  bxy.drawImage("ring3", center, angle = frame.float / 170)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  display()
  pollEvents()
```

## Examples

<img src="docs/spinner.png">

[Spinner](https://github.com/treeform/boxy/blob/master/examples/basic_windy.nim)

<img src="docs/masking.png">

[Masking](https://github.com/treeform/boxy/blob/master/examples/masking.nim)

[Check out more examples here.](https://github.com/treeform/boxy/tree/master/examples)
