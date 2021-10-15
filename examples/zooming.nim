import boxy, opengl, staticglfw

let windowSize = ivec2(1280, 800)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)
windowHint(CONTEXT_VERSION_MAJOR, 4)
windowHint(CONTEXT_VERSION_MINOR, 1)

let window = createWindow(
  windowSize.x.cint, windowSize.y.cint, "GLFW + Boxy", nil, nil
)

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
  bxy.drawImage("greece", center=vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while windowShouldClose(window) != 1:
  pollEvents()
  display()
