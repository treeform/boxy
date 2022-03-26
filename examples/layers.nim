import boxy, opengl, windy

let windowSize = ivec2(1280, 800)

let window = newWindow("Windy + Boxy", windowSize)
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("mask", readImage("examples/data/mask.png"))
bxy.addImage("greece", readImage("examples/data/greece.png"))

var frame: int

let layer = bxy.newLayer(windowSize)

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(0.1, 0.1, 0.1, 1))


  let c2 = color(1, 1, 1, 0.5)

  layer.with:

    bxy.saveTransform()
    bxy.translate(windowSize.vec2 / 2)
    bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
    bxy.drawImage("mask", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
    bxy.restoreTransform()

    bxy.saveTransform()
    bxy.translate(windowSize.vec2 / 2)
    bxy.scale(0.8 + 0.2 * cos(frame.float32/100))
    bxy.drawImage("mask", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
    bxy.restoreTransform()

  bxy.drawLayer(layer, tintColor = c2)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  display()
  pollEvents()
