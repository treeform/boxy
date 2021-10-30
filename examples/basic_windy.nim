import boxy, opengl, windy

let windowSize = ivec2(1280, 800)

let window = newWindow("Windy + Boxy", windowSize)
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

let rhino = readImage("examples/data/rhino.png")
bxy.addImage("rhino", rhino)

var i: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)
  # Draw the white background.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(1, 1, 1, 1))
  # Draw the rhino.
  bxy.drawImage("rhino", vec2((i mod windowSize.x).float32, 0))
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc i

while not window.closeRequested:
  pollEvents()
  display()
