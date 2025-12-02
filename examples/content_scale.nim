import boxy, opengl, windy

let window = newWindow("Content Scale", size = ivec2(1280, 800))
echo "starting window content scale: ", window.contentScale, " window size: ", window.size

makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("ring1", readImage("examples/data/ring1.png"))
bxy.addImage("ring2", readImage("examples/data/ring2.png"))
bxy.addImage("ring3", readImage("examples/data/ring3.png"))
bxy.addImage("crosshair", readImage("examples/data/crosshair.png"))

var frame: int

proc contentSize*(window: Window): IVec2 =
  ## Returns the size / contentScale of the window in physical pixels.
  (window.size.vec2 / window.contentScale).ivec2

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  echo "content scale: ", window.contentScale, " window size: ", window.size
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Transform to high-dpi scale.
  bxy.saveTransform()
  bxy.scale(window.contentScale)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), window.contentSize.vec2))

  # Draw the rings.
  let center = window.contentSize.vec2 / 2
  bxy.drawImage("ring1", center, angle = frame.float / 100)
  bxy.drawImage("ring2", center, angle = -frame.float / 190)
  bxy.drawImage("ring3", center, angle = frame.float / 170)

  # Draw the stars at the mouse position.
  let mousePos = window.mousePos.vec2 / window.contentScale
  bxy.drawImage("crosshair", mousePos, angle = 0)

  # End this frame, flushing the draw commands.
  bxy.restoreTransform()
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

  # On F4 key, write the atlas to a file.
  if window.buttonPressed[KeyF4]:
    echo "Writing atlas to tmp/atlas.png"
    bxy.readAtlas().writeFile("tmp/atlas.png")

while not window.closeRequested:
  pollEvents()
