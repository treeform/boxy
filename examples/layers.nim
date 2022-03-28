import boxy, opengl, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
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
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0.1, 0.1, 0.1, 1))

  let c2 = color(1, 1, 1, 0.5)

  bxy.pushLayer()

  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
  bxy.drawImage("mask", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
  bxy.restoreTransform()

  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(0.8 + 0.2 * cos(frame.float32/100))
  bxy.drawImage("mask", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
  bxy.restoreTransform()

  bxy.popLayer(tintColor = c2)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

window.onResize = proc() =
  display()

while not window.closeRequested:
  display()
  pollEvents()
