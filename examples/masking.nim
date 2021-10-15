import boxy, opengl, staticglfw

let windowSize = ivec2(1280, 800)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)
windowHint(CONTEXT_VERSION_MAJOR, 4)
windowHint(CONTEXT_VERSION_MINOR, 1)

let window = createWindow(windowSize.x, windowSize.y, "GLFW + Boxy", nil, nil)

makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("mask", readImage("examples/data/mask.png"))
bxy.addImage("greece", readImage("examples/data/greece.png"))

var frame: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(0, 0, 0, 1))

  # Draw the mask.
  bxy.beginMask()
  bxy.drawImage("mask", center=windowSize.vec2 / 2, angle = 0)
  bxy.endMask()

  # Use the mask.
  bxy.saveTransform()
  bxy.translate(windowSize.vec2 / 2)
  bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
  bxy.drawImage("greece", center=vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  bxy.popMask()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while windowShouldClose(window) != 1:
  pollEvents()
  display()
