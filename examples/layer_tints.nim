import boxy, opengl, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("greece", readImage("examples/data/greece.png"))

var frame: int

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  bxy.pushLayer()
  bxy.pushLayer()
  bxy.pushLayer()
  bxy.pushLayer()

  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
  bxy.drawImage("greece", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
  bxy.restoreTransform()

  bxy.popLayer(tintColor = color(1, 1, 1, 0.5))
  bxy.popLayer(tintColor = color(1, 1, 1, 0.5))
  bxy.popLayer(tintColor = color(1, 1, 1, 0.5))
  bxy.popLayer(tintColor = color(1, 1, 1, 0.5))

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()
