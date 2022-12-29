<img src="docs/banner.png">

# Boxy - 2D GPU rendering with a tiling atlas.

`nimble install boxy`

![Github Actions](https://github.com/treeform/boxy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/boxy)

## About Boxy

Welcome, dear reader, to the fantastical realm of Boxy! If you've stumbled upon this page, chances are you're seeking a way to bring your 2D graphics projects to life in the delightful programming language of Nim. Perhaps you're even dreaming of creating the next great 2D game. Well, fear not – Boxy is here to help you realize those dreams and more!

With Boxy, you'll be able to easily create stunning visuals using the power of Nim and OpenGL, the industry-standard graphics API. All you need to do is open a window, load your images, and let Boxy take care of the rest. Plus, with its simple and intuitive API, you'll be up and running in no time, even if you're new to Nim.

But Boxy isn't just about drawing pretty pictures frame after frame – it's also about making them fast. By rendering dynamic assets (such as text) into images once using Pixie and then adding them to Boxy, you can take advantage of Boxy's tiling atlas texture to draw your images to the screen each frame with lightning-fast speed.

Ah, the Boxy tiling atlas! This is where all the magic happens. You see, the tiling atlas is what makes Boxy so fast and efficient. It's like a giant canvas where you can add and remove images with ease, without worrying about fragmentation or wasting texture space.

But how does it work, you might ask? Well, it's actually quite simple. When you add an image to the tiling atlas, it's automatically converted into a set of 32x32 tiles. This might sound like a lot of work, but don't worry – Boxy takes care of everything for you in the background.

And here's the really cool part: Boxy is smart enough to skip over any transparent tiles, so they won't be drawn on screen. Plus, solid colors are optimized! This means that you can use all sorts images with big single color or transparent swatches without worrying about performance. Huge UI rectangles or sprites with liberal transparent padding are drawn even faster!

See our youtube video on the topic: https://www.youtube.com/watch?v=UFbffBIzEDc

But that's not all – Boxy also has some advanced features that you can use to really spice up your graphics. For example, you can push and pop layers to create all sorts of interesting effects, like parallax scrolling or pop-up menus. You can also apply different blending modes to layers, or even mask them with other layers. And if that's not enough, you can even blur and shadow with layers, or save parts of them back as images for later use.

Boxy runs on Windows, Mac, and Linux, so you can use it no matter what kind of computer you have. And with its easy-to-use API, you'll be up and running in no time.

But what exactly is Boxy, you might ask? Well, think of it being similar to the drawing part of the SDL and PyGame libraries. It's got all the power and flexibility you need to create beautiful graphics, with none of the complexity. Just load your images, add them to the tiling atlas, and watch the magic happen!

So go ahead and give the Boxy a try – I guarantee you'll be amazed at what you can create!

Boxy uses:
* [Windy](https://github.com/treeform/windy) windowing and OS interactions for Windows, macOS and Linux.
* [Pixie](https://github.com/treeform/pixie) 2d vector, text and image graphics.
* [Chroma](https://github.com/treeform/chroma) everything to do with colors.
* [VMath](https://github.com/treeform/vmath) vector math.

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
