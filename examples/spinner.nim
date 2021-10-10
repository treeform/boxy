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

let bxy = newBoxy(maxTiles=16)

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("ring1", readImage("examples/data/ring1.png"))
bxy.addImage("ring2", readImage("examples/data/ring2.png"))
bxy.addImage("ring3", readImage("examples/data/ring3.png"))

# If you wish to see what the atlas looks like:
# bxy.readAtlas().writeFile("atlas.png")

var frame: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawImage("bg", rect=rect(vec2(0, 0), windowSize))

  # Draw the rings.
  bxy.drawImage("ring1", center=windowSize/2, angle = frame.float / 100)
  bxy.drawImage("ring2", center=windowSize/2, angle = -frame.float / 190)
  bxy.drawImage("ring3", center=windowSize/2, angle = frame.float / 170)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while windowShouldClose(window) != 1:
  pollEvents()
  display()
