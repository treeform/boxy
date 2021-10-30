import boxy, opengl, windy

let windowSize = ivec2(1280, 800)

init()

let window = newWindow("Windy + Boxy", windowSize)
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the image.
bxy.addImage("greece", readImage("examples/data/greece.png"))

# bxy.readAtlas().writeFile("atlas.png")

var frame: int
var scale: float32 = 0.7

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(0, 0, 0, 1))

  bxy.saveTransform()
  bxy.translate(windowSize.vec2/2)
  bxy.scale(scale)
  scale *= 0.999
  bxy.drawImage("greece", center = vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  display()
  pollEvents()
