<img src="docs/banner.png">

# Boxy - 2D GPU rendering with a tiling atlas.

`nimble install boxy`

![Github Actions](https://github.com/treeform/boxy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/boxy)

## About

Boxy is a powerful 2D graphics library for Nim that allows developers to easily create stunning visuals using the GPU. Built on top of the [Pixie](https://github.com/treeform/pixie) image library and OpenGL. Boxy provides a simple, yet powerful API for rendering 2D graphics.

Using Boxy is straightforward. First, you can open a window using [Windy](https://github.com/treeform/windy) and prepare an OpenGL context. Then, you can load image files using [Pixie](https://github.com/treeform/pixie) or render any dynamic assets, such as text. These images can then be added to Boxy, where they are placed into the tiling atlas texture. You can draw these images to the screen each frame to create a smooth, seamless visual experience. At any point an image may be removed or added to the boxy tiling atlas. You can also use layers to mask, shadow or blending or apply shadow or blur effects.

### Dynamic Texture Atlas

One of the coolest features of Boxy is its use of a dynamic [texture atlas](https://en.wikipedia.org/wiki/Texture_atlas), which helps to optimize graphics rendering by breaking images into small tiles that can be efficiently stored in texture memory. This helps to eliminate texture memory fragmentation and can improve rendering speed by not drawing transparent tiles or drawing solid color tiles without texture memory overhead. This is particularly useful for UI elements that have borders but a solid color in the middle, as well as sprites with liberal use transparency.

See our youtube video on the topic: https://www.youtube.com/watch?v=UFbffBIzEDc

### Powerful Layers

Another great features of Boxy is its support for layers, which allow developers to create complex graphics and visual effects with ease. Layers in Boxy can be used for a variety of purposes, including masking, shadowing, and blending.

Boxy supports a wide range of blending modes, similar to those found in image editing software like Photoshop. These modes include Darken, Multiply, ColorBurn, Lighten, Screen, ColorDodge, Overlay, SoftLight, HardLight, Difference, Exclusion, Hue, Saturation, Color, and Luminosity. These modes allow developers to create a wide range of visual effects, including shadows, glows, and color tints.

In addition to blending modes, Boxy also supports several additional masking modes, such as Subtract and Exclude. These modes allow developers to create masks that can be used to reveal or hide certain parts of a layer. This is particularly useful for creating complex UI elements or for creating special effects in games.

Boxy also includes support for filters, which can be applied to layers to create even more advanced visual effects. Filters available in Boxy include Drop Shadow, Inner Shadow, and Blur. These filters can be used to create glowing effects, border around complex elements, and more.

### And More

Boxy together with [Windy](https://github.com/treeform/windy) and [Pixie](https://github.com/treeform/pixie) is similar to other 2D graphics libraries such as SDL (Simple DirectMedia Layer) and PyGame in that it provides a set of tools for creating and rendering 2D graphics. If you have experience with either of these libraries, you will likely find it easy to use Boxy as well. However, Boxy takes advantage of the GPU to accelerate rendering, which can result in faster and smoother visuals. If you need sound or networking support take a look at our [Slappy](https://github.com/treeform/slappy) and [Netty](https://github.com/treeform/netty) libraries.

Boxy is a cross-platform 2D graphics library, which means that it is designed to run on a variety of different operating systems. Specifically, it runs on Windows, macOS, and Linux, making it a great choice for developers who need to create applications that can be deployed on a wide range of platforms. There is some even proof of concept work done to get Boxy run on iOS and Android, and even the browser though WASM but currently its not supported.

Overall, Boxy is a powerful, easy-to-use 2D graphics library that is ideal for developers looking to create stunning visuals using the GPU. With its texture atlas optimization, advanced layers effects, and simple API, it is a great choice for anyone looking to create beautiful, efficient graphic applications or games in Nim.

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
