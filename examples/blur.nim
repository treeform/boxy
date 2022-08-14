import boxy, opengl, windy

let window = newWindow("Boxy Blur", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the image.
bxy.addImage("greece", readImage("examples/data/greece.png"))

var frame: int

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0, 0, 0, 1))

  bxy.pushLayer()

  bxy.saveTransform()
  bxy.translate(window.size.vec2/2)
  bxy.drawImage("greece", center = vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  # Set the blur amount based on time.
  let radius = 50 * (sin(frame.float32/100) + 1)

  # Blurs the current pushed layer.
  bxy.blurEffect(radius)

  bxy.popLayer()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()
