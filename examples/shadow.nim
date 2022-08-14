import boxy, opengl, windy

let window = newWindow("Boxy Shadow", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the image.
bxy.addImage("mask", readImage("examples/data/mask.png"))

var frame: int

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))

  bxy.pushLayer()

  bxy.saveTransform()
  bxy.translate(window.size.vec2/2)
  bxy.drawImage(
    "mask",
    center = vec2(0, 0),
    angle = 0,
    tint = color(1, 1, 1, 1)
  )
  bxy.restoreTransform()

  # Set the shadow blur amount based on time.
  let radius = 50 * (sin(frame.float32/100) + 1)

  # Shadow follows the mouse.
  let mouse = ivec2(window.mousePos.x, window.mousePos.y).vec2

  bxy.dropShadowLayer(
    color(0, 0, 0, 1),
    (mouse - window.size.vec2/2) / 10,
    radius,
    10
  )

  bxy.popLayer()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()
