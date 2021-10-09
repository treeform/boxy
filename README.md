# Boxy - 2D GPU rendering with a tiling atlas.

`nimble install boxy`

![Github Actions](https://github.com/treeform/boxy/workflows/Github%20Actions/badge.svg)

[API reference](https://nimdocs.com/treeform/boxy)

## About

Boxy is an easy to use 2D GPU rendering API built on top of [Pixie](https://github.com/treeform/pixie).

The basic model for using Boxy goes something like this:

* Open a window and prepare an OpenGL context.
* Load image files like .png using Pixie.
* Render any dynamic assets (such as text) into images once using Pixie.
* Add these images to Boxy, where they are put into a tiling atlas texture.
* Draw these images to screen each frame.

## Basic Example

```nim
import boxy, opengl, staticglfw

let windowSize = vec2(1280, 800)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)

let window = createWindow(
  windowSize.x.cint, windowSize.y.cint, "GLFW + Boxy", nil, nil
)

makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

let rhino = readImage("examples/rhino.png")
bxy.addImage("rhino", rhino) # Add this image to Boxy once.

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)
  # Draw the white background.
  bxy.drawRect(rect(vec2(0, 0), windowSize), color(1, 1, 1, 1))
  # Draw the rhino.
  bxy.drawImage("rhino", vec2(100, 100))
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()

while windowShouldClose(window) != 1:
  pollEvents()
  display()
```

[Check out more examples here.](https://github.com/treeform/boxy/tree/master/examples)
