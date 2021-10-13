import boxy, opengl, staticglfw, random

let windowSize = ivec2(1280, 800)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)

let window = createWindow(windowSize.x, windowSize.y, "GLFW + Boxy", nil, nil)

makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("star1", readImage("examples/data/star1.png"))

var frame: int = 1

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(0, 0, 0, 1))

  bxy.saveTransform()
  bxy.translate(windowSize.vec2 / 2)
  bxy.scale(0.1)

  randomize(2022)
  for i in 0 .. 5000:
    let pos = vec2(gauss(), gauss()) * frame.float32 * 10
    bxy.drawImage("star1",
      center = pos,
      angle = rand(0.0 .. PI)
    )

  bxy.restoreTransform()
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while windowShouldClose(window) != 1:
  pollEvents()
  display()
